// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../utils/Governable.sol";
import "../interfaces/utils/IRegistry.sol";
import "../interfaces/risk/IRiskManager.sol";
import "../interfaces/products/ISolaceCoverProductV2.sol";

/**
 * @title SolaceCoverProductV2
 * @author solace.fi
 * @notice A Solace insurance product that allows users to insure all of their DeFi positions against smart contract risk through a single policy.
 *
 * Policies can be **purchased** via [`activatePolicy()`](#activatepolicy). Policies are represented as ERC721s, which once minted, cannot then be transferred or burned. Users can change the cover limit of their policy through [`updateCoverLimit()`](#updatecoverlimit).
 *
 * The policy will remain active until i.) the user cancels their policy or ii.) the user's account runs out of funds. The policy will be billed like a subscription, every epoch a fee will be charged from the user's account.
 *
 * Users can **deposit funds** into their account via [`deposit()`](#deposit). Currently the contract only accepts deposits in **FRAX**. Note that both [`activatePolicy()`](#activatepolicy) and [`deposit()`](#deposit) enables a user to perform these actions (activate a policy, make a deposit) on behalf of another user.
 *
 * Users can **cancel** their policy via [`deactivatePolicy()`](#deactivatepolicy). This will start a cooldown timer. Users can **withdraw funds** from their account via [`withdraw()`](#withdraw).
 *
 * Before the cooldown timer starts or passes, the user cannot withdraw their entire account balance. A minimum required account balance (to cover one epoch's fee) will be left in the user's account. After the cooldown has passed, a user will be able to withdraw their entire account balance.
 *
 * Users can enter a **referral code** with [`activatePolicy()`](#activatePolicy) or [`updateCoverLimit()`](#updatecoverlimit). A valid referral code will earn reward points to both the referrer and the referee. When the user's account is charged, reward points will be deducted before deposited funds.
 * Each account can only enter a valid referral code once, however there are no restrictions on how many times a referral code can be used for new accounts.
 */
contract SolaceCoverProductV2 is
    ISolaceCoverProductV2,
    ERC721,
    EIP712,
    ReentrancyGuard,
    Governable
{
    using SafeERC20 for IERC20;
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;

    /***************************************
    STATE VARIABLES
    ***************************************/

    /// @notice Registry contract.
    IRegistry internal _registry;

    /// @notice Cannot buy new policies while paused. (Default is False)
    bool internal _paused;

    /// @notice Referral typehash.
    /// solhint-disable-next-line var-name-mixedcase
    bytes32 private constant _REFERRAL_TYPEHASH = keccak256("SolaceReferral(uint256 version)");

    string public baseURI;

    /// @notice Asset name to pay coverage.
    string public asset;

    /***************************************
    BOOK-KEEPING VARIABLES
    ***************************************/

    /// @notice The total policy count.
    uint256 internal _totalPolicyCount;

    /**
     * @notice The maximum rate charged per second per 1e-18 (wei) of coverLimit.
     * @dev Default to charge 10% of cover limit annually = 1/315360000.
     */
    uint256 internal _maxRateNum;
    uint256 internal _maxRateDenom;

    /// @notice Maximum epoch duration over which premiums are charged (Default is one week).
    uint256 internal _chargeCycle;

    /**
     * @notice The cooldown period (Default is one week)
     * Cooldown timer is started by the user calling deactivatePolicy().
     * Before the cooldown has started or has passed, withdrawing funds will leave a minimim required account balance in the user's account. Only after the cooldown has passed, is a user able to withdraw their entire account balance.
     */
    uint256 internal _cooldownPeriod;

    /**
     * @notice The reward points earned (to both the referee and referrer) for a valid referral code. (Default is 50 FRAX).
     */
    uint256 internal _referralReward;

    /**
     * @notice The threshold premium amount that an account needs to have paid, for the account to be able to apply a referral code. (Default is 100 FRAX).
     */
    uint256 internal _referralThreshold;

    /**
     * @notice If true, referral rewards are active. If false, referral rewards are switched off (Default is true).
     */
    bool internal _isReferralOn;

    /**
     * @notice policyholder => cooldown start timestamp
     * @dev will be 0 if cooldown has not started, or has been reset
     */
    mapping(address => uint256) internal _cooldownStart;

    /// @notice policyholder => policyID.
    mapping(address => uint256) internal _policyOf;

    /// @notice policyID => coverLimit
    mapping(uint256 => uint256) internal _coverLimitOf;

    /// @notice policyholder => premiumPaid
    mapping(address => uint256) internal _premiumPaidOf;

    /**
     * @notice This is a mapping that no-one likes but seems necessary to circumvent a couple of edge cases. This mapping is intended to mirror the _coverLimitOf mapping, except for the period between i.) cooldown starting when deactivatePolicy() called and ii.) cooldown has passed and user calls withdraw()
     * @dev Edge case 1: User deactivates policy -> User can withdraw all funds immediately after, circumventing the intended cooldown mechanic. This occurs because when deactivatePolicy() called, _coverLimitOf[user] is set to 0, which also sets their minRequiredAccountBalance (coverLimit * chargeCycle * maxRate) to 0.
     * @dev Edge case 2: A user should not be able to deactivate their policy just prior to the fee charge tranasction, and then avoid the insurance fee for the current epoch.
     * @dev will be 0 if cooldown has not started, or has been reset
     */
    mapping(uint256 => uint256) internal _preDeactivateCoverLimitOf;

    /**
     * @notice policyholder => reward points.
     * Users earn reward points for using a valid referral code (as a referee), and having other users successfully use their referral code (as a referrer)
     * Reward points can be manually set by the Cover Promotion Admin
     * Reward points act as a credit, when an account is charged, they are deducted from before deposited funds
     */
    mapping(address => uint256) internal _rewardPointsOf;

    /**
     * @notice policyID => true if referral code has been used, false if not
     * A referral code can only be used once for each policy. There is no way to reset to false.
     */
    mapping(uint256 => bool) internal _isReferralCodeUsed;

    /// @notice policyholder => account balance (in USD, to 18 decimals places)
    mapping(address => uint256) private _accountBalanceOf;

    /// @notice The policy chain info.
    mapping(uint256 => uint256[]) private _policyChainInfo;

    /// @notice Supported chains to cover positions.
    EnumerableSet.UintSet internal chains;

    /***************************************
    MODIFIERS
    ***************************************/

    modifier whileUnpaused() {
        require(!_paused, "contract paused");
        _;
    }

    /**
     * @notice Constructs `Solace Cover Product`.
     * @param governance_ The address of the governor.
     * @param registry_ The [`Registry`](./Registry) contract address.
     * @param asset_ The asset name to pay coverage.
     * @param domain_ The user readable name of the EIP712 signing domain.
     * @param version_ The current major version of the signing domain.
     */
    constructor(
        address governance_,
        address registry_,
        string memory asset_,
        string memory domain_,
        string memory version_
    )
        ERC721("Solace Cover Policy", "SCP")
        Governable(governance_)
        EIP712(domain_, version_)
    {
        require(registry_ != address(0x0), "zero address registry");
        _registry = IRegistry(registry_);
        require(_registry.get("riskManager") != address(0x0), "zero address riskmanager");
        require(_registry.get(asset_) != address(0x0), "zero address asset");

        // Set default values
        _maxRateNum = 1;
        _maxRateDenom = 315360000; // Max premium rate of 10% of cover limit per annum
        _chargeCycle = 604800; // One-week charge cycle
        _cooldownPeriod = 604800; // One-week cooldown period
        _referralReward = 50e18; // 50 FRAX
        _referralThreshold = 100e18; // 100 FRAX
        _isReferralOn = true; // Referral rewards active
        asset = asset_;
        baseURI = string(abi.encodePacked("https://stats.solace.fi/policy/?chainID=", Strings.toString(block.chainid), "&policyID="));
    }

    /***************************************
    POLICYHOLDER FUNCTIONS
    ***************************************/

    /**
     * @notice Activates policy for `policyholder_`
     * @param policyholder_ The address of the intended policyholder.
     * @param coverLimit_ The maximum value to cover in **USD**.
     * @param amount_ The deposit amount in **USD** to fund the policyholder's account.
     * @param referralCode_ The referral code.
     * @param chains_ The chain ids.
     * @return policyID The ID of the newly minted policy.
     */
    function activatePolicy(
        address policyholder_,
        uint256 coverLimit_,
        uint256 amount_,
        bytes calldata referralCode_,
        uint256[] calldata chains_
    ) external override nonReentrant whileUnpaused returns (uint256 policyID) {
        require(policyholder_ != address(0x0), "zero address policyholder");
        require(coverLimit_ > 0, "zero cover value");
        require(_validateChains(chains_), "invalid chain");

        policyID = policyOf(policyholder_);
        require(!policyStatus(policyID), "policy already activated");
        require(_canPurchaseNewCover(0, coverLimit_), "insufficient capacity for new cover");
        require(IERC20(_getAsset()).balanceOf(msg.sender) >= amount_, "insufficient caller balance for deposit");
        require(amount_ + accountBalanceOf(policyholder_) > _minRequiredAccountBalance(coverLimit_), "insufficient deposit for minimum required account balance");

        // Exit cooldown
        _exitCooldown(policyholder_);

        // deposit funds
        _deposit(msg.sender, policyholder_, amount_);

        // mint policy if doesn't currently exist
        if (policyID == 0) {
            policyID = ++_totalPolicyCount;
            _policyOf[policyholder_] = policyID;
            _mint(policyholder_, policyID);
        }

        _processReferralCode(policyholder_, referralCode_);

        // update cover amount
        _updateActiveCoverLimit(0, coverLimit_);
        _coverLimitOf[policyID] = coverLimit_;
        _preDeactivateCoverLimitOf[policyID] = coverLimit_;
        _setPolicyChainInfo(policyID, chains_);
        emit PolicyCreated(policyID);
        return policyID;
    }

    /**
     * @notice Updates the cover limit of a user's policy.
     * @notice This will reset the cooldown.
     * @param newCoverLimit_ The new maximum value to cover in **USD**.
     * @param referralCode_ The referral code.
     */
    function updateCoverLimit(
        uint256 newCoverLimit_,
        bytes calldata referralCode_
    ) external override nonReentrant whileUnpaused {
        require(newCoverLimit_ > 0, "zero cover value");
        uint256 policyID = _policyOf[msg.sender];
        require(_exists(policyID), "invalid policy");
        uint256 currentCoverLimit = coverLimitOf(policyID);
        require(
            _canPurchaseNewCover(currentCoverLimit, newCoverLimit_),
            "insufficient capacity for new cover"
        );
        require(
            _accountBalanceOf[msg.sender] > _minRequiredAccountBalance(newCoverLimit_),
            "insufficient deposit for minimum required account balance"
        );

        _processReferralCode(msg.sender, referralCode_);

        _exitCooldown(msg.sender); // Reset cooldown
        _coverLimitOf[policyID] = newCoverLimit_;
        _preDeactivateCoverLimitOf[policyID] = newCoverLimit_;
        _updateActiveCoverLimit(currentCoverLimit, newCoverLimit_);
        emit PolicyUpdated(policyID);
    }

    /**
     * @notice Updates policy chain info.
     * @param policyChains The requested policy chains to update.
     */
    function updatePolicyChainInfo(uint256[] memory policyChains) external override nonReentrant whileUnpaused {
        uint256 policyID = policyOf(msg.sender);
        require(_exists(policyID), "invalid policy");
        require(policyStatus(policyID), "inactive policy");
        _setPolicyChainInfo(policyID, policyChains);
        emit PolicyUpdated(policyID);
    }

    /**
     * @notice Deposits funds into the `policyholder` account.
     * @param policyholder The policyholder.
     * @param amount The amount to deposit in **USD**.
     */
    function deposit(
        address policyholder,
        uint256 amount
    ) external override nonReentrant whileUnpaused {
        require(policyholder != address(0x0), "zero address policyholder");
        _deposit(msg.sender, policyholder, amount);
    }

    /**
     * @notice Withdraw funds from user's account.
     *
     * @notice If cooldown has passed, the user will withdraw their entire account balance.
     *
     * @notice If cooldown has not started, or has not passed, the user will not be able to withdraw their entire account. A minimum required account balance (one epoch's fee) will be left in the user's account.
     */
    function withdraw() external override nonReentrant whileUnpaused {
        require(_accountBalanceOf[msg.sender] > 0, "no account balance to withdraw");
        if ( _hasCooldownPassed(msg.sender) ) {
          _withdraw(msg.sender, _accountBalanceOf[msg.sender]);
          _preDeactivateCoverLimitOf[_policyOf[msg.sender]] = 0;
        } else {
          uint256 preDeactivateCoverLimit = _preDeactivateCoverLimitOf[_policyOf[msg.sender]];
          _withdraw(msg.sender, _accountBalanceOf[msg.sender] - _minRequiredAccountBalance(preDeactivateCoverLimit));
        }
    }

    /**
     * @notice Deactivate a user's policy.
     *
     * This will set a user's cover limit to 0, and begin the cooldown timer. Read comments for [`cooldownPeriod()`](#cooldownperiod) for more information on the cooldown mechanic.
     */
    function deactivatePolicy() external override nonReentrant {
        require(policyStatus(_policyOf[msg.sender]), "invalid policy");
        _deactivatePolicy(msg.sender);
    }

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Returns the policyholder's account account balance in **USD**.
     * @param policyholder The policyholder address.
     * @return balance The policyholder's account balance in **USD**.
     */
    function accountBalanceOf(address policyholder) public view override returns (uint256 balance) {
        return _accountBalanceOf[policyholder];
    }

    /**
     * @notice The maximum amount of cover that can be sold in **USD** to 18 decimals places.
     * @return cover The max amount of cover.
     */
    function maxCover() public view override returns (uint256 cover) {
        return IRiskManager(_registry.get("riskManager")).maxCoverPerStrategy(address(this));
    }

    /**
     * @notice Returns the active cover limit in **USD** to 18 decimal places. In other words, the total cover that has been sold at the current time.
     * @return amount The active cover limit.
     */
    function activeCoverLimit() public view override returns (uint256 amount) {
        return IRiskManager(_registry.get("riskManager")).activeCoverLimitPerStrategy(address(this));
    }

    /**
     * @notice Determine the available remaining capacity for new cover.
     * @return availableCoverCapacity_ The amount of available remaining capacity for new cover.
     */
    function availableCoverCapacity() public view override returns (uint256 availableCoverCapacity_) {
        availableCoverCapacity_ = maxCover() - activeCoverLimit();
    }

    /**
     * @notice Get the reward points that a policyholder has in **USD** to 18 decimal places.
     * @param policyholder_ The policyholder address.
     * @return rewardPoints_ The reward points for the policyholder.
     */
    function rewardPointsOf(address policyholder_) public view override returns (uint256 rewardPoints_) {
        return _rewardPointsOf[policyholder_];
    }

    /**
     * @notice Get the total premium that a policyholder has in **USD** to 18 decimal places (does not include premium paid through reward points)
     * @param policyholder_ The policyholder address.
     * @return premiumsPaid_ The total premium paid for the policyholder.
     */
    function premiumsPaidOf(address policyholder_) public view override returns (uint256 premiumsPaid_) {
        return _premiumPaidOf[policyholder_];
    }

    /**
     * @notice Gets the policyholder's policy ID.
     * @param policyholder_ The address of the policyholder.
     * @return policyID The policy ID.
     */
    function policyOf(address policyholder_) public view override returns (uint256 policyID) {
        return _policyOf[policyholder_];
    }

    /**
     * @notice Returns true if the policy is active, false if inactive
     * @param policyID_ The policy ID.
     * @return status True if policy is active. False otherwise.
     */
    function policyStatus(uint256 policyID_) public view override returns (bool status) {
        return coverLimitOf(policyID_) > 0 ? true : false;
    }

    /**
     * @notice Returns [`Registry`](./Registry) contract address.
     * @return registry_ The `Registry` address.
     */
    function registry() external view override returns (address registry_) {
        return address(_registry);
    }

    /**
     * @notice Returns [`RiskManager`](./RiskManager) contract address.
     * @return riskManager_ The `RiskManager` address.
     */
    function riskManager() external view override returns (address riskManager_) {
        return address(_registry.get("riskManager"));
    }

    /**
     * @notice Returns true if the product is paused, false if not.
     * @return status True if product is paused.
     */
    function paused() external view override returns (bool status) {
        return _paused;
    }

    /**
     * @notice Gets the policy count (amount of policies that have been purchased, includes inactive policies).
     * @return count The policy count.
     */
    function policyCount() public view override returns (uint256 count) {
        return _totalPolicyCount;
    }

    /**
     * @notice Gets the max rate.
     * @return maxRateNum_ the max rate numerator.
     * @return maxRateDenom_ the max rate denominator.
     */
    function maxRate() public view override returns (uint256 maxRateNum_, uint256 maxRateDenom_) {
        return (_maxRateNum, _maxRateDenom);
    }

    /**
     * @notice Gets the charge cycle duration.
     * @return chargeCycle_ the charge cycle duration in seconds.
     */
    function chargeCycle() public view override returns (uint256 chargeCycle_) {
        return _chargeCycle;
    }

    /**
     * @notice Gets cover limit for a given policy ID.
     * @param policyID_ The policy ID.
     * @return amount The cover limit for given policy ID.
     */
    function coverLimitOf(uint256 policyID_) public view override returns (uint256 amount) {
        return _coverLimitOf[policyID_];
    }

    /**
     * @notice Gets the cooldown period.
     *
     * Cooldown timer is started by the user calling deactivatePolicy().
     * Before the cooldown has started or has passed, withdrawing funds will leave a minimim required account balance in the user's account.
     * Only after the cooldown has passed, is a user able to withdraw their entire account balance.
     * @return cooldownPeriod_ The cooldown period in seconds.
     */
    function cooldownPeriod() external view override returns (uint256 cooldownPeriod_) {
        return _cooldownPeriod;
    }

    /**
     * @notice The Unix timestamp that a policyholder's cooldown started. If cooldown has not started or has been reset, will return 0.
     * @param policyholder_ The policyholder address
     * @return cooldownStart_ The cooldown period start expressed as Unix timestamp
     */
    function cooldownStart(address policyholder_) external view override returns (uint256 cooldownStart_) {
        return _cooldownStart[policyholder_];
    }

    /**
     * @notice Gets the current reward amount in USD for a valid referral code.
     * @return referralReward_ The referral reward
     */
    function referralReward() external view override returns (uint256 referralReward_) {
        return _referralReward;
    }

    /**
     * @notice Gets the threshold premium amount in USD that an account needs to have paid, for the account to be able to apply a referral code
     * @return referralThreshold_ The referral threshold
     */
    function referralThreshold() external view override returns (uint256 referralThreshold_) {
        return _referralThreshold;
    }

    /**
     * @notice Returns true if referral rewards are active, false if not.
     * @return isReferralOn_ True if referral rewards are active, false if not.
     */
    function isReferralOn() external view override returns (bool isReferralOn_) {
        return _isReferralOn;
    }

    /**
     * @notice True if a policyholder has previously used a valid referral code, false if not
     *
     * A policyholder can only use a referral code once. A policyholder is then ineligible to receive further rewards from additional referral codes.
     * @return isReferralCodeUsed_ True if the policyholder has previously used a valid referral code, false if not
     */
    function isReferralCodeUsed(address policyholder) external view override returns (bool isReferralCodeUsed_) {
        return _isReferralCodeUsed[_policyOf[policyholder]];
    }

    /**
     * @notice Returns true if valid referral code, false otherwise.
     * @param referralCode The referral code.
     */
    function isReferralCodeValid(bytes calldata referralCode) external view override returns (bool) {
        (address referrer,) = ECDSA.tryRecover(_getEIP712Hash(), referralCode);
        if(referrer == address(0)) return false;
        return true;
    }

    /**
     * @notice Get referrer from referral code, returns 0 address if invalid referral code.
     * @param referralCode The referral code.
     * @return referrer The referrer address, returns 0 address if invalid referral code.
     */
    function getReferrerFromReferralCode(bytes calldata referralCode) external view override returns (address referrer) {
        (referrer,) = ECDSA.tryRecover(_getEIP712Hash(), referralCode);
    }

    /**
     * @notice Calculate minimum required account balance for a given cover limit. Equals the maximum chargeable fee for one epoch.
     * @param coverLimit Cover limit.
     */
    function minRequiredAccountBalance(uint256 coverLimit) external view override returns (uint256 minRequiredAccountBalance_) {
        return _minRequiredAccountBalance(coverLimit);
    }

    /**
     * @notice Returns the Uniform Resource Identifier (URI) for `policyID`.
     * @param policyID The policy ID.
     */
    function tokenURI(uint256 policyID) public view virtual override returns (string memory tokenURI_) {
        require(_exists(policyID), "invalid policy");
        string memory baseURI_ = baseURI;
        return string(abi.encodePacked( baseURI_, Strings.toString(policyID) ));
    }

    /**
     * @notice Returns true if given chain id supported.
     * @return status True if chain is supported otherwise false.
    */
    function isSupportedChain(uint256 chainId) public view override returns (bool status) {
       return chains.contains(chainId);
    }

    /**
     * @notice Returns the number of chains.
     * @return count The number of chains.
     */
     function numSupportedChains() public override view returns (uint256 count) {
        return chains.length();
    }

    /**
     * @notice Returns the chain at the given index.
     * @param chainIndex The index to query.
     * @return chainId The address of the chain.
     */
    function getChain(uint256 chainIndex) external override view returns (uint256 chainId) {
        return chains.at(chainIndex);
    }

    /**
     * @notice Returns the policy chain info.
     * @param policyID The policy id to get chain info.
     * @return policyChains The list of policy chain values.
    */
    function getPolicyChainInfo(uint256 policyID) external override view returns (uint256[] memory policyChains) {
        return _policyChainInfo[policyID];
    }

    /***************************************
    GOVERNANCE FUNCTIONS
    ***************************************/

    /**
     * @notice Sets the [`Registry`](./Registry) contract address.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param registry_ The address of `Registry` contract.
     */
    function setRegistry(address registry_) external override onlyGovernance {
        require(registry_ != address(0x0), "zero address registry");
        _registry = IRegistry(registry_);

        require(_registry.get("riskManager") != address(0x0), "zero address riskmanager");
        require(_registry.get(asset) != address(0x0), "zero address asset");
        emit RegistrySet(registry_);
    }

    /**
     * @notice Pauses or unpauses policies.
     * Deactivating policies are unaffected by pause.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param paused_ True to pause, false to unpause.
     */
    function setPaused(bool paused_) external override onlyGovernance {
        _paused = paused_;
        emit PauseSet(paused_);
    }

    /**
     * @notice Sets the cooldown period. Read comments for [`cooldownPeriod()`](#cooldownperiod) for more information on the cooldown mechanic.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param cooldownPeriod_ Cooldown period in seconds.
     */
    function setCooldownPeriod(uint256 cooldownPeriod_) external override onlyGovernance {
        _cooldownPeriod = cooldownPeriod_;
        emit CooldownPeriodSet(cooldownPeriod_);
    }

    /**
     * @notice set _maxRate.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param maxRateNum_ Desired maxRateNum.
     * @param maxRateDenom_ Desired maxRateDenom.
     */
    function setMaxRate(uint256 maxRateNum_, uint256 maxRateDenom_) external override onlyGovernance {
        _maxRateNum = maxRateNum_;
        _maxRateDenom = maxRateDenom_;
        emit MaxRateSet(maxRateNum_, maxRateDenom_);
    }

    /**
     * @notice set _chargeCycle.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param chargeCycle_ Desired chargeCycle.
     */
    function setChargeCycle(uint256 chargeCycle_) external override onlyGovernance {
        _chargeCycle = chargeCycle_;
        emit ChargeCycleSet(chargeCycle_);
    }

    /**
     * @notice set _referralReward
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param referralReward_ Desired referralReward.
    */
    function setReferralReward(uint256 referralReward_) external override onlyGovernance {
        _referralReward = referralReward_;
        emit ReferralRewardSet(referralReward_);
    }

    /**
     * @notice set _referralThreshhold
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param referralThreshhold_ Desired referralThreshhold.
     */
    function setReferralThreshold(uint256 referralThreshhold_) external override onlyGovernance {
        _referralThreshold = referralThreshhold_;
        emit ReferralThresholdSet(referralThreshhold_);
    }

    /**
     * @notice set _isReferralOn
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param isReferralOn_ True if referral rewards active, false if not.
    */
    function setIsReferralOn(bool isReferralOn_) external override onlyGovernance {
        _isReferralOn = isReferralOn_;
        emit IsReferralOnSet(isReferralOn_);
    }

    /**
     * @notice Sets the base URI for computing `tokenURI`.
     * @param baseURI_ The new base URI.
     */
    function setBaseURI(string memory baseURI_) external override onlyGovernance {
        baseURI = baseURI_;
        emit BaseURISet(baseURI_);
    }

    /**
     * @notice Adds supported chains to cover positions.
     * @param supportedChains The supported array of chains.
    */
    function addSupportedChains(uint256[] memory supportedChains) external override onlyGovernance {
        for (uint256 i = 0; i < supportedChains.length; i++) {
            chains.add(supportedChains[i]);
            emit SupportedChainSet(supportedChains[i]);
        }
    }

    /**
     * @notice Removes chain from the supported chain list.
     * @param chainId The chain id to remove.
    */
    function removeSupportedChain(uint256 chainId) external override onlyGovernance {
        chains.remove(chainId);
        emit SupportedChainRemoved(chainId);
    }

    /**
     * @notice Sets the asset name.
     * @param assetName The asset name to set.
    */
    function setAsset(string memory assetName) external override onlyGovernance {
        asset = assetName;
        emit AssetSet(assetName);
    }

    /***************************************
    COVER PROMOTION ADMIN FUNCTIONS
    ***************************************/

    /**
     * @notice Set reward points for a selected address. Can only be called by the **Cover Promotion Admin** role.
     * @param policyholder_ The address of the policyholder to set reward points for.
     * @param rewardPoints_ Desired amount of reward points.
     */
    function setRewardPoints(address policyholder_, uint256 rewardPoints_) external override {
        require(msg.sender == _registry.get("coverPromotionAdmin"), "not cover promotion admin");
        _rewardPointsOf[policyholder_] = rewardPoints_;
        emit RewardPointsSet(policyholder_, rewardPoints_);
    }

    /***************************************
    PREMIUM COLLECTOR FUNCTIONS
    ***************************************/

    /**
     * @notice Charge premiums for each policy holder. Can only be called by the **Premium Collector** role.
     *
     * @dev Cheaper to load variables directly from calldata, rather than adding an additional operation of copying to memory.
     * @param holders Array of addresses of the policyholders to charge.
     * @param premiums Array of premium amounts (in **USD** to 18 decimal places) to charge each policyholder.
     */
    function chargePremiums(
        address[] calldata holders,
        uint256[] calldata premiums
    ) external override whileUnpaused {
        uint256 count = holders.length;
        require(msg.sender == _registry.get("premiumCollector"), "not premium collector");
        require(count == premiums.length, "length mismatch");
        require(count <= policyCount(), "policy count exceeded");
        uint256 amountToPayPremiumPool = 0;

        for (uint256 i = 0; i < count; i++) {
            // Skip computation if the user has withdrawn entire account balance
            // We use _preDeactivateCoverLimitOf mapping here to circumvent the following edge case: A user should not be able to deactivate their policy just prior to the chargePremiums() tranasction, and then avoid the premium for the current epoch.
            // There is another edge case introduced here however: the premium collector can charge a deactivated account more than once. We are trusting that the premium collector does not do this.

            uint256 preDeactivateCoverLimit = _preDeactivateCoverLimitOf[_policyOf[holders[i]]];
            if ( preDeactivateCoverLimit == 0) continue;

            uint256 premium = premiums[i];
            if (premiums[i] > _minRequiredAccountBalance(preDeactivateCoverLimit)) {
                premium = _minRequiredAccountBalance(preDeactivateCoverLimit);
            }

            // If premiums paid >= referralThreshold, then reward points count
            if (_premiumPaidOf[holders[i]] >= _referralThreshold) {
                // If policyholder's account can pay for premium charged in full
                if (_accountBalanceOf[holders[i]] + _rewardPointsOf[holders[i]] >= premium) {

                    // If reward points can pay for premium charged in full
                    if (_rewardPointsOf[holders[i]] >= premium) {
                        _rewardPointsOf[holders[i]] -= premium;
                    } else {
                        uint256 amountDeductedFromSoteriaAccount = premium - _rewardPointsOf[holders[i]];
                        amountToPayPremiumPool += amountDeductedFromSoteriaAccount;
                        _premiumPaidOf[holders[i]] += amountDeductedFromSoteriaAccount;
                        _accountBalanceOf[holders[i]] -= amountDeductedFromSoteriaAccount;
                        _rewardPointsOf[holders[i]] = 0;
                    }
                    emit PremiumCharged(holders[i], premium);
                } else {
                    uint256 partialPremium = _accountBalanceOf[holders[i]] + _rewardPointsOf[holders[i]];
                    amountToPayPremiumPool += _accountBalanceOf[holders[i]];
                    _premiumPaidOf[holders[i]] += _accountBalanceOf[holders[i]];
                    _accountBalanceOf[holders[i]] = 0;
                    _rewardPointsOf[holders[i]] = 0;
                    _deactivatePolicy(holders[i]);
                    emit PremiumPartiallyCharged(
                        holders[i],
                        premium,
                        partialPremium
                    );
                }
            // Else if premiums paid < referralThreshold, reward don't count
            } else {
                // If policyholder's account can pay for premium charged in full
                if (_accountBalanceOf[holders[i]] >= premium) {
                        amountToPayPremiumPool += premium;
                        _premiumPaidOf[holders[i]] += premium;
                        _accountBalanceOf[holders[i]] -= premium;
                        emit PremiumCharged(holders[i], premium);
                } else {
                    uint256 partialPremium = _accountBalanceOf[holders[i]];
                    amountToPayPremiumPool += partialPremium;
                    _premiumPaidOf[holders[i]] += partialPremium;
                    _accountBalanceOf[holders[i]] = 0;
                    _deactivatePolicy(holders[i]);
                    emit PremiumPartiallyCharged(
                        holders[i],
                        premium,
                        partialPremium
                    );
                }
            }
        }

        // single FRAX transfer to the premium pool
        SafeERC20.safeTransfer(_getAsset(), _registry.get("premiumPool"), amountToPayPremiumPool);
    }

    /***************************************
    INTERNAL FUNCTIONS
    ***************************************/

    /**
     * @notice Returns true if there is sufficient capacity to update a policy's cover limit, false if not.
     * @param existingTotalCover_ The current cover limit, 0 if policy has not previously been activated.
     * @param newTotalCover_  The new cover limit requested.
     * @return acceptable True there is sufficient capacity for the requested new cover limit, false otherwise.
     */
    function _canPurchaseNewCover(
        uint256 existingTotalCover_,
        uint256 newTotalCover_
    ) internal view returns (bool acceptable) {
        if (newTotalCover_ <= existingTotalCover_) return true; // Return if user is lowering cover limit
        uint256 changeInTotalCover = newTotalCover_ - existingTotalCover_; // This will revert if newTotalCover_ < existingTotalCover_
        if (changeInTotalCover < availableCoverCapacity()) return true;
        else return false;
    }

    /**
     * @notice Deposits funds into the policyholder's account balance.
     * @param from The address which is funding the deposit.
     * @param policyholder The policyholder address.
     * @param amount The deposit amount in **USD** to 18 decimal places.
     */
    function _deposit(
        address from,
        address policyholder,
        uint256 amount
    ) internal whileUnpaused {
        SafeERC20.safeTransferFrom(_getAsset(), from, address(this), amount);
        _accountBalanceOf[policyholder] += amount;
        emit DepositMade(from, policyholder, amount);
    }

    /**
     * @notice Withdraw funds from policyholder's account to the policyholder.
     * @param policyholder The policyholder address.
     * @param amount The amount to withdraw in **USD** to 18 decimal places.
     */
    function _withdraw(
        address policyholder,
        uint256 amount
    ) internal whileUnpaused {
        SafeERC20.safeTransfer(_getAsset(), policyholder, amount);
        _accountBalanceOf[policyholder] -= amount;
        emit WithdrawMade(policyholder, amount);
    }

    /**
     * @notice Deactivate the policy.
     * @param policyholder The policyholder address.
     */
    function _deactivatePolicy(address policyholder) internal {
        _startCooldown(policyholder);
        uint256 policyID = _policyOf[policyholder];
        _updateActiveCoverLimit(_coverLimitOf[policyID], 0);
        _coverLimitOf[policyID] = 0;
        delete _policyChainInfo[policyID];
        emit PolicyDeactivated(policyID);
    }

    /**
     * @notice Updates the Risk Manager on the current total cover limit purchased by policyholders.
     * @param currentCoverLimit The current policyholder cover limit (0 if activating policy).
     * @param newCoverLimit The new policyholder cover limit.
     */
    function _updateActiveCoverLimit(
        uint256 currentCoverLimit,
        uint256 newCoverLimit
    ) internal {
        IRiskManager(_registry.get("riskManager"))
            .updateActiveCoverLimitForStrategy(
                address(this),
                currentCoverLimit,
                newCoverLimit
            );
    }

    /**
     * @notice Calculate minimum required account balance for a given cover limit. Equals the maximum chargeable fee for one epoch.
     * @param coverLimit Cover limit.
     */
    function _minRequiredAccountBalance(uint256 coverLimit) internal view returns (uint256 minRequiredAccountBalance) {
        minRequiredAccountBalance = (_maxRateNum * _chargeCycle * coverLimit) / _maxRateDenom;
    }

    /**
     * @notice Override _beforeTokenTransfer hook from ERC721 standard to ensure policies are non-transferable, and only one can be minted per user.
     * @dev This hook is called on mint, transfer and burn.
     * @param from sending address.
     * @param to receiving address.
     * @param tokenId tokenId.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        require(from == address(0), "only minting permitted");
    }

    /**
     * @notice Starts the cooldown period for the policyholder.
     * @param policyholder Policyholder address.
     */
    function _startCooldown(address policyholder) internal {
        _cooldownStart[policyholder] = block.timestamp;
        emit CooldownStarted(policyholder, _cooldownStart[policyholder]);
    }

    /**
     * @notice Exits the cooldown period for a policyholder.
     * @param policyholder Policyholder address.
     */
    function _exitCooldown(address policyholder) internal {
        _cooldownStart[policyholder] = 0;
        emit CooldownStopped(policyholder);
    }

    /**
     * @notice Return true if cooldown has passed for a policyholder, false if cooldown has not started or has not passed.
     * @param policyholder Policyholder address.
     * @return True if cooldown has passed, false if cooldown has not started or has not passed.
     */
    function _hasCooldownPassed(address policyholder) internal view returns (bool) {
        if (_cooldownStart[policyholder] == 0) {
            return false;
        } else {
            return block.timestamp >= _cooldownStart[policyholder] + _cooldownPeriod;
        }
    }

    /**
     * @notice Internal function to process a referral code
     * @param policyholder_ Policyholder address.
     * @param referralCode_ Referral code.
     */
    function _processReferralCode(
        address policyholder_,
        bytes calldata referralCode_
    ) internal {
        // Skip processing referral code, if referral campaign switched off or empty referral code argument
        if ( !_isReferralOn || _isEmptyReferralCode(referralCode_) ) return;

        address referrer = ECDSA.recover(_getEIP712Hash(), referralCode_);
        require(referrer != policyholder_, "cannot refer to self");
        require(policyStatus(_policyOf[referrer]), "referrer must be active policy holder");
        require (!_isReferralCodeUsed[_policyOf[policyholder_]], "cannot use referral code again");

        _isReferralCodeUsed[_policyOf[policyholder_]] = true;
        _rewardPointsOf[policyholder_] += _referralReward;
        _rewardPointsOf[referrer] += _referralReward;

        emit ReferralRewardsEarned(policyholder_, _referralReward);
        emit ReferralRewardsEarned(referrer, _referralReward);
    }

    /**
     * @notice Internal helper function to determine if referralCode_ is an empty bytes value
     * @param referralCode_ Referral code.
     * @return True if empty referral code, false if not.
     */
    function _isEmptyReferralCode(bytes calldata referralCode_) internal pure returns (bool) {
        return (keccak256(abi.encodePacked(referralCode_)) == keccak256(abi.encodePacked("")));
    }

    /**
     * @notice Internal helper function to get EIP712-compliant hash for referral code verification.
     */
    function _getEIP712Hash() internal view returns (bytes32) {
        bytes32 digest =
            ECDSA.toTypedDataHash(
                _domainSeparatorV4(),
                keccak256(
                    abi.encode(
                        _REFERRAL_TYPEHASH,
                        2
                    )
                )
            );
        return digest;
    }

    /**
     * @notice Returns the underlying principal asset for `Solace Cover Product`.
     * @return asset The underlying asset.
    */
    function _getAsset() internal view returns (IERC20) {
        return IERC20(_registry.get(asset));
    }

    /**
     * @notice Checks if the given chain info is valid or not.
     * @param requestedChains The chain id array to check.
     * @return status True if the given chain array is valid.
    */
    function _validateChains(uint256[] memory requestedChains) internal view returns (bool) {
        require(requestedChains.length > 0, "zero length");
        require(requestedChains.length <= numSupportedChains(), "invalid length");
        for (uint256 i = 0; i < requestedChains.length; i++) {
            if (!chains.contains(requestedChains[i])) return false;
        }
        return true;
    }

    /**
     * @notice Sets chain info for the policy.
     * @param policyID The policy id to add chain info.
     * @param policyChains The array of chain id to add.
    */
    function _setPolicyChainInfo(uint256 policyID, uint256[] memory policyChains) internal {
        _policyChainInfo[policyID] = policyChains;
    }

}
