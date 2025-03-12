// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../utils/SolaceSigner.sol";
import "../interfaces/utils/IRegistry.sol";
import "../interfaces/risk/IRiskManager.sol";
import "../interfaces/payment/ICoverPaymentManager.sol";
import "../interfaces/products/ISolaceCoverProductV3.sol";

/**
 * @title SolaceCoverProductV3
 * @author solace.fi
 * @notice A Solace insurance product that allows users to insure all of their DeFi positions against smart contract risk through a single policy.
 */
contract SolaceCoverProductV3 is
    ISolaceCoverProductV3,
    SolaceSigner,
    ERC721,
    ReentrancyGuard
{
    /***************************************
    STATE VARIABLES
    ***************************************/

    /// @notice Registry contract.
    address public registry;

    /// @notice RiskManager contract.
    address public riskManager;

    /// @notice CoverPaymentManager contract.
    address public paymentManager;

    /// @notice Cannot buy new policies while paused. (Default is False)
    bool public paused;

    /// @notice The base token uri url for policies.
    string public baseURI;

    /// @notice The total policy count.
    uint256 public totalSupply;

    /// @notice The maximum rate charged per second per 1e-18 (wei) of cover limit.
    /// @dev Default to charge 10% of cover limit annually = 1/315360000.
    uint256 public maxRateNum;

    /// @notice The maximum rate denomination value.
    /// @dev  Max premium rate of 10% of cover limit per annum.
    uint256 public maxRateDenom;

    /// @notice Maximum epoch duration over which premiums are charged (Default is one week).
    uint256 public chargeCycle;

    /// @notice The latest premium charged timestamp.
    uint256 public latestChargedTime;

    /// @notice policyholder => policyID.
    mapping(address => uint256) public policyOf;

    /// @notice policyID => coverLimit.
    mapping(uint256 => uint256) public coverLimitOf;

    /***************************************
    MODIFIERS
    ***************************************/

    modifier whileUnpaused() {
        require(!paused, "contract paused");
        _;
    }

    modifier onlyCollector() {
        require(
            msg.sender == IRegistry(registry).get("premiumCollector") ||
            msg.sender == governance(), "not premium collector"
        );
        _;
    }

    /**
     * @notice Constructs `Solace Cover Product`.
     * @param _governance The address of the governor.
     * @param _registry The [`Registry`](./Registry) contract address.
     */
    constructor(address _governance, address _registry) ERC721("Solace Portfolio Insurance", "SPI") SolaceSigner(_governance) {
        // set registry
        _setRegistry(_registry);

        // set defaults
        maxRateNum = 1;
        maxRateDenom = 315360000;
        chargeCycle = _getChargePeriodValue(ChargePeriod.WEEKLY);
        baseURI = string(abi.encodePacked("https://stats.solace.fi/policy/?chainID=", Strings.toString(block.chainid), "&policyID="));
    }

    /***************************************
    POLICY FUNCTIONS
    ***************************************/

    /**
     * @notice Purchases policies for the user.
     * @param _user The policy owner.
     * @param _coverLimit The maximum value to cover in **USD**.
     */
    function purchase(address _user, uint256 _coverLimit) external override nonReentrant whileUnpaused {
        _purchase(_user, _coverLimit);
    }

    /**
     * @notice Purchases policy for the user.
     * @param _user The policy owner.
     * @param _coverLimit The maximum value to cover in **USD**.
     * @param _token The token to deposit.
     * @param _amount Amount of token to deposit.
     * @return policyID The ID of the newly minted policy.
     */
    function purchaseWithStable(
        address _user,
        uint256 _coverLimit,
        address _token,
        uint256 _amount
    ) external override nonReentrant whileUnpaused returns (uint256 policyID) {
        return _purchaseWithStable(msg.sender, _user, _coverLimit, _token, _amount);
    }

    /**
     * @notice Purchases policy for the user.
     * @param _user The policy owner.
     * @param _coverLimit The maximum value to cover in **USD**.
     * @param _token The token to deposit.
     * @param _amount Amount of token to deposit.
     * @param _price The `SOLACE` price in wei(usd).
     * @param _priceDeadline The `SOLACE` price in wei(usd).
     * @param _signature The `SOLACE` price signature.
     * @return policyID The ID of the newly minted policy.
     */
    function purchaseWithNonStable(
        address _user,
        uint256 _coverLimit,
        address _token,
        uint256 _amount,
        uint256 _price,
        uint256 _priceDeadline,
        bytes calldata _signature
    ) external override nonReentrant whileUnpaused returns (uint256 policyID) {
        return _purchaseWithNonStable(msg.sender, _user, _coverLimit, _token, _amount, _price, _priceDeadline, _signature);
    }

    /**
     * @notice Cancels the policy.
     * @param _premium The premium amount to verify.
     * @param _deadline The deadline for the signature.
     * @param _signature The premium data signature.
     */
    function cancel(uint256 _premium, uint256 _deadline, bytes calldata _signature) external override {
        require(policyStatus(policyOf[msg.sender]), "invalid policy");
        require(verifyPremium(_premium, msg.sender, _deadline, _signature), "invalid premium data");

        uint256 scpBalance = ICoverPaymentManager(paymentManager).getSCPBalance(msg.sender);
        uint256 chargeAmount = scpBalance < _premium ? scpBalance : _premium;
        if (chargeAmount > 0) {
            address[] memory accounts = new address[](1);
            uint256[] memory premiums = new uint256[](1);
            accounts[0] = msg.sender;
            premiums[0] = chargeAmount;
            ICoverPaymentManager(paymentManager).chargePremiums(accounts, premiums);
        }

        uint256 policyID = policyOf[msg.sender];
        uint256 coverLimit = coverLimitOf[policyID];
        _updateActiveCoverLimit(coverLimit, 0);
        coverLimitOf[policyID] = 0;
        emit PolicyCanceled(policyID);
    }

    /**
     * @notice Terminates the policies if users don't have enough balance to pay coverage.
     * @param _policyholders The owners of the policies to terminate.
     */
    function cancelPolicies(address[] calldata _policyholders) external override onlyCollector {
        uint256 count = _policyholders.length;
        address policyholder;
        uint256 policyID;
        uint256 coverLimit;

        for (uint256 i = 0; i < count; i++) {
            policyholder = _policyholders[i];
            policyID = policyOf[policyholder];

            if (policyStatus(policyID)) {
                coverLimit = coverLimitOf[policyID];
                _updateActiveCoverLimit(coverLimit, 0);
                coverLimitOf[policyID] = 0;
                emit PolicyCanceled(policyID);
            }
        }
    }

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice The maximum amount of cover that can be sold in **USD** to 18 decimals places.
     * @return cover The max amount of cover.
     */
    function maxCover() public view override returns (uint256 cover) {
        return IRiskManager(riskManager).maxCoverPerStrategy(address(this));
    }

    /**
     * @notice Returns the active cover limit in **USD** to 18 decimal places. In other words, the total cover that has been sold at the current time.
     * @return amount The active cover limit.
     */
    function activeCoverLimit() public view override returns (uint256 amount) {
        return IRiskManager(riskManager).activeCoverLimitPerStrategy(address(this));
    }

    /**
     * @notice Determine the available remaining capacity for new cover.
     * @return capacity The amount of available remaining capacity for new cover.
     */
    function availableCoverCapacity() public view override returns (uint256 capacity) {
        capacity = maxCover() - activeCoverLimit();
    }

    /**
     * @notice Returns true if the policy is active, false if inactive
     * @param _policyID The policy ID.
     * @return status True if policy is active. False otherwise.
     */
    function policyStatus(uint256 _policyID) public view override returns (bool status) {
        return coverLimitOf[_policyID] > 0 ? true : false;
    }

    /**
     * @notice Calculate minimum required account balance for a given cover limit. Equals the maximum chargeable fee for one epoch.
     * @param _coverLimit The maximum value to cover in **USD**.
     */
    function minRequiredAccountBalance(uint256 _coverLimit) public view override returns (uint256 mrab) {
        mrab = (maxRateNum * chargeCycle * _coverLimit) / maxRateDenom;
    }

    /**
     * @notice Calculates the minimum amount of Solace Credit Points required by this contract for the account to hold.
     * @param _policyholder The account to query.
     * @return amount The amount of SCP the account must hold.
     */
    function minScpRequired(address _policyholder) external view override returns (uint256 amount) {
        if (policyStatus(policyOf[_policyholder])) {
            return minRequiredAccountBalance(coverLimitOf[policyOf[_policyholder]]);
        }
        return 0;
    }

    /**
     * @notice Returns the Uniform Resource Identifier (URI) for `policyID`.
     * @param policyID The policy ID.
     */
    function tokenURI(uint256 policyID) public view virtual override returns (string memory uri) {
        require(_exists(policyID), "invalid policy");
        return string(abi.encodePacked(baseURI, Strings.toString(policyID)));
    }

    /***************************************
    GOVERNANCE FUNCTIONS
    ***************************************/

    /**
     * @notice Sets the [`Registry`](./Registry) contract address.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param _registry The address of `Registry` contract.
     */
    function setRegistry(address _registry) external override onlyGovernance {
        _setRegistry(_registry);
    }

    /**
     * @notice Pauses or unpauses policies.
     * Deactivating policies are unaffected by pause.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param _paused True to pause, false to unpause.
     */
    function setPaused(bool _paused) external override onlyGovernance {
        paused = _paused;
        emit PauseSet(_paused);
    }

    /**
     * @notice set _maxRate.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param _maxRateNum The maximum rate charged per second per 1e-18 (wei) of cover limit.
     * The default is to charge 10% of cover limit annually = 1/315360000.
     * @param _maxRateDenom The maximum rate denomination value. The default value is max premium rate of 10% of cover limit per annum.
     */
    function setMaxRate(uint256 _maxRateNum, uint256 _maxRateDenom) external override onlyGovernance {
        maxRateNum = _maxRateNum;
        maxRateDenom = _maxRateDenom;
        emit MaxRateSet(_maxRateNum, _maxRateDenom);
    }

    /**
     * @notice Sets maximum epoch duration over which premiums are charged.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param _chargeCycle The premium charge period(Weekly, Monthly, Annually, Daily, Hourly) in seconds to set. The default is weekly(604800).
     */
    function setChargeCycle(ChargePeriod _chargeCycle) external override onlyGovernance {
        chargeCycle = _getChargePeriodValue(_chargeCycle);
        emit ChargeCycleSet(chargeCycle);
    }

    /**
     * @notice Sets the base URI for computing `tokenURI`.
     * @param _baseURI The new base URI.
     */
    function setBaseURI(string memory _baseURI) external override onlyGovernance {
        baseURI = _baseURI;
        emit BaseURISet(_baseURI);
    }

    /***************************************
    PREMIUM COLLECTOR FUNCTIONS
    ***************************************/

    /**
     * @notice Sets the latest premium charged time.
     * @param _timestamp The timestamp value when the premiums are charged.
     */
    function setChargedTime(uint256 _timestamp) external override whileUnpaused onlyCollector {
        // solhint-disable-next-line not-rely-on-time
        require(_timestamp > 0 && _timestamp <= block.timestamp, "invalid charged timestamp");
        latestChargedTime = _timestamp;
        emit LatestChargedTimeSet(_timestamp);
    }

    /***************************************
    INTERNAL FUNCTIONS
    ***************************************/

    /**
     * @notice Returns true if there is sufficient capacity to update a policy's cover limit, false if not.
     * @param _currentCoverLimit The current cover limit, 0 if policy has not previously been activated.
     * @param _newCoverLimit  The new cover limit requested.
     * @return acceptable True there is sufficient capacity for the requested new cover limit, false otherwise.
     */
    function _checkCapacity(uint256 _currentCoverLimit, uint256 _newCoverLimit) internal view returns (bool acceptable) {
        // return true if user is lowering cover limit
        if (_newCoverLimit <= _currentCoverLimit) return true;

        // check capacity
        uint256 diff = _newCoverLimit - _currentCoverLimit;
        if (diff < availableCoverCapacity()) return true;

        // no available capacity
        return false;
    }

    /**
     * @notice Purchases policy for user.
     * @param _user The account to purchase policy.
     * @param _coverLimit The maximum value to cover in **USD**.
     * @return policyID The ID of the newly minted policy.
     */
    function _purchase(address _user, uint256 _coverLimit) internal returns (uint256 policyID) {
        policyID = policyOf[_user];

        // mint policy if doesn't exist
        bool mint = policyID == 0;
        if (mint) {
            policyID = ++totalSupply;
            policyOf[_user] = policyID;
            _mint(_user, policyID);
            emit PolicyCreated(policyID);
        }

        // only update cover limit if initial mint or called by policyholder
        if(mint || msg.sender == _user) {
            uint256 currentCoverLimit = coverLimitOf[policyID];
            if(_coverLimit != currentCoverLimit) {
                require(_checkCapacity(currentCoverLimit, _coverLimit), "insufficient capacity");
                // update cover amount
                _updateActiveCoverLimit(currentCoverLimit, _coverLimit);
                coverLimitOf[policyID] = _coverLimit;
            }
            require(ICoverPaymentManager(paymentManager).getSCPBalance(_user) >= minRequiredAccountBalance(_coverLimit), "insufficient scp balance");
            emit PolicyUpdated(policyID);
        }

        return policyID;
    }

    /**
     * @notice Purchases policy for user.
     * @param _purchaser The account that purchases the policy.
     * @param _user The account to purchase policy for.
     * @param _coverLimit The maximum value to cover in **USD**.
     * @param _token The token to deposit.
     * @param _amount Amount of token to deposit.
     * @return policyID The ID of the newly minted policy.
     */
    function _purchaseWithStable(address _purchaser, address _user, uint256 _coverLimit, address _token, uint256 _amount) internal returns (uint256 policyID) {
        ICoverPaymentManager(paymentManager).depositStableFrom(_token, _purchaser, _user, _amount);
        return _purchase(_user, _coverLimit);
    }

    /**
     * @notice Purchases policy for user.
     * @param _purchaser The account that purchases the policy.
     * @param _user The account to purchase policy.
     * @param _coverLimit The maximum value to cover in **USD**.
     * @param _token The token to deposit.
     * @param _amount Amount of token to deposit.
     * @param _price The `SOLACE` price in wei(usd).
     * @param _priceDeadline The `SOLACE` price in wei(usd).
     * @param _signature The `SOLACE` price signature.
     * @return policyID The ID of the newly minted policy.
     */
    function _purchaseWithNonStable(
        address _purchaser,
        address _user,
        uint256 _coverLimit,
        address _token,
        uint256 _amount,
        uint256 _price,
        uint256 _priceDeadline,
        bytes calldata _signature
    ) internal returns (uint256 policyID) {
        ICoverPaymentManager(paymentManager).depositNonStableFrom(_token, _purchaser, _user, _amount, _price, _priceDeadline, _signature);
        return _purchase(_user, _coverLimit);
    }

    /**
     * @notice Updates the Risk Manager on the current total cover limit purchased by policyholders.
     * @param _currentCoverLimit The current policyholder cover limit (0 if activating policy).
     * @param _newCoverLimit The new policyholder cover limit.
     */
    function _updateActiveCoverLimit(uint256 _currentCoverLimit, uint256 _newCoverLimit) internal {
        IRiskManager(riskManager).updateActiveCoverLimitForStrategy(address(this), _currentCoverLimit, _newCoverLimit);
    }

    /**
     * @notice Override _beforeTokenTransfer hook from ERC721 standard to ensure policies are non-transferable, and only one can be minted per user.
     * @dev This hook is called on mint, transfer and burn.
     * @param from sending address.
     * @param to receiving address.
     * @param tokenId tokenId.
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        require(from == address(0), "only minting permitted");
    }

    /**
     * @notice Sets registry and related contract addresses.
     * @param _registry The registry address to set.
     */
    function _setRegistry(address _registry) internal {
        // set registry
        require(_registry != address(0x0), "zero address registry");
        registry = _registry;

        // set risk manager
        (, address riskManagerAddr) = IRegistry(_registry).tryGet("riskManager");
        require(riskManagerAddr != address(0x0), "zero address riskmanager");
        riskManager = riskManagerAddr;

        // set cover payment manager
        (, address paymentManagerAddr) = IRegistry(_registry).tryGet("coverPaymentManager");
        require(paymentManagerAddr != address(0x0), "zero address payment manager");
        paymentManager = paymentManagerAddr;
        emit RegistrySet(_registry);
    }

    function _getChargePeriodValue(ChargePeriod period) private pure returns (uint256 value) {
        if (period == ChargePeriod.WEEKLY) {
            return 604800;
        } else if (period == ChargePeriod.MONTHLY) {
            return 2629746;
        } else if (period == ChargePeriod.ANNUALLY) {
            return 31556952;
        } else if (period == ChargePeriod.DAILY) {
            return 86400;
        } else {
            // hourly
            return 3600;
        }
    }
}
