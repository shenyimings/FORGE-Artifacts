// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./interface/IYieldModule.sol";
import "./interface/ISmartFarmooor.sol";
import "../common/library/Modifier.sol";
import "../common/Rescuable.sol";
import "../common/RoleManagement.sol";

/**
 * @author  HedgeFarm Team
 * @title   Smart Farmooor Strategy
 * @dev     The Smart Farmooor is composable and integrable into other Yielding strategy
 * @notice  Upgradability is needed because the Smart Farmooor is built on top of protocols that have Upgradable Smart contracts
 */
contract SmartFarmooor is ISmartFarmooor, UUPSUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, ERC20Upgradeable, Rescuable, Modifier, RoleManagement {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev Constant used by the keeper bot
    bytes32 public constant HARVEST_PROFIT = keccak256(bytes("HARVEST_PROFIT"));
    /// @dev Constant used for percentage calculation
    uint16 public constant MAX_BPS = 10000;
    /// @dev Constant for the max value of uint256
    uint256 public constant UINT_MAX = type(uint256).max;

    /// @notice The address receiving the performance fee
    address public feeManager;
    /// @notice The asset used by the Smart Farmooor
    address public baseToken;
    /// @notice The minimum profit needed to harvest
    uint256 public minHarvestThreshold;
    /// @notice The number of active modules
    uint256 public numberOfModules;
    /// @notice The snapshot of the base token balance before panicking
    uint256 public balanceSnapshot;
    /// @notice The current performance fee.
    uint16 public performanceFee;
    /// @notice The maximum total balance cap for the strategy.
    uint256 public cap;
    /// @notice The minimum amount that can be deposited in the strategy.
    uint256 public minAmount;
    /// @notice The address of the contract containing automation rules
    address public automationRules;

    /// @notice The list of active modules
    mapping(uint => YieldModuleDetails) public yieldOptions;


    event Deposit(address indexed user, uint amount);
    event Withdraw(address indexed user, uint shares, uint amount);
    event Harvest(uint netProfit);
    event AllocationChange();

    /**
     * @notice  Make sure Modules are empty before certain Admin operations
     */
    modifier onlyIfEmptyModule() {
        require(getModulesBalance() <= minHarvestThreshold, "SmartFarmooor: module not empty");
        _;
    }


    /** proxy **/

    /**
     * @notice  Initializes
     * @dev     Should always be called on deployment
     * @param   _name  Name of the Strategy
     * @param   _symbol  Symbol of the Strategy
     * @param   _feeManager  Address of the Fee Manager
     * @param   _baseToken  Asset of the Strategy
     * @param   _minHarvestThreshold  Minimum amount of baseToken needed to harvest
     * @param   _performanceFee  Performance fee on profits, capped at 20%
     * @param   _cap  Strategy max Deposit cap
     * @param   _manager  Strategy manager role
     * @param   _admin  Strategy Admin role
     * @param   _minAmount  Strategy min deposit amount
     * @param   _privateAccess list of addresses that will have private access to the protocol
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        address _feeManager,
        address _baseToken,
        uint256 _minHarvestThreshold,
        uint16 _performanceFee,
        uint256 _cap,
        address _manager,
        address _admin,
        uint256 _minAmount,
        address[] memory _privateAccess
    ) public initializer {
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __ERC20_init(_name, _symbol);

        _setupRole(MANAGER_ROLE, _manager);
        _setupRole(PANICOOOR_ROLE, _manager);
        _setupRole(MANAGER_ROLE, _admin);
        _setupRole(PANICOOOR_ROLE, _admin);

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);

        _setFeeManager(_feeManager);
        _setBaseToken(_baseToken);
        _setMinHarvestThreshold(_minHarvestThreshold);
        _setPerformanceFee(_performanceFee);
        _setCap(_cap);
        _setMinAmount(_minAmount);

        _setPrivateRoles(_privateAccess);
    }

    /**
     * @notice  Makes sure only the owner can upgrade, called from upgradeTo(..)
     * @param   newImplementation Contract address of newImplementation
     */
    function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    /**
     * @notice  Get current implementation contract
     * @return  address  Returns current implement contract
     */
    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    /** admin **/

    /**
     * @notice  Add a new Module to the list
     * @dev     Only when current modules are empty
     * @param   _module  New Module to be added
     */
    function addModule(IYieldModule _module) external onlyRole(DEFAULT_ADMIN_ROLE) onlyNotZeroAddress(address(_module)) onlyIfEmptyModule whenPaused {
        require(_module.baseToken() == baseToken, "SmartFarmooor: not compatible module");
        if (IERC20Upgradeable(baseToken).allowance(address(this), address(_module)) == 0)
            IERC20Upgradeable(baseToken).safeApprove(address(_module), UINT_MAX);
        yieldOptions[numberOfModules] = YieldModuleDetails(_module, 0);
        numberOfModules += 1;
    }

    /**
     * @notice  Remove a Module from the list
     * @dev     Module should be in the list
     * @param   _moduleId  Mapping index of the Module to be removed
     */
    function removeModule(uint _moduleId) external onlyRole(MANAGER_ROLE) whenPaused onlyIfEmptyModule {
        require(address(yieldOptions[_moduleId].module) != address(0), "SmartFarmooor : module does not exist");
        IERC20Upgradeable(baseToken).safeApprove(address(yieldOptions[_moduleId].module), 0);
        for (uint i = _moduleId; i <= numberOfModules; i += 1) {
            yieldOptions[i] = yieldOptions[i + 1];
        }
        numberOfModules -= 1;
    }

    /**
     * @notice  Set new allocation to all the Modules
     * @dev     Total allocation should be 100%, should be set after a addModule
     * @param   _allocation  List of the new allocations
     */
    function setModuleAllocation(uint[] memory _allocation) external onlyRole(MANAGER_ROLE) whenPaused onlyIfEmptyModule {
        require(_allocation.length == numberOfModules, "SmartFarmooor: Allocation list size issue");
        uint totalAllocation = 0;
        for (uint i = 0; i < numberOfModules; i += 1) {
            require(_allocation[i] >= 100, "SmartFarmooor: Min allocation too low");
            yieldOptions[i].allocation = _allocation[i];
            totalAllocation += yieldOptions[i].allocation;
        }

        require(totalAllocation == MAX_BPS, "SmartFarmooor: total allocation is wrong");
        emit AllocationChange();
    }

    /**
     * @notice  Removes funds from Modules, stores them on this contract
     * @dev     Pauses the Strategy to avoid Deposit / Withdraw in case of emergency
     */
    function panic() external payable onlyRole(PANICOOOR_ROLE) {
        _pause();
        balanceSnapshot = getModulesBalance();
        uint executionFee = getExecutionFee(totalSupply());
        require(msg.value >= executionFee, "SmartFarmooor: msg.value to small for withdraw execution");
        //100% of shares => shareFraction = decimals()
        _withdraw(10 ** decimals(), address(this));
    }

    /**
     * @notice  Pushes funds into Modules
     * @dev     Unpauses the contracts
     */
    function finishPanic() external onlyRole(MANAGER_ROLE) whenPaused {
        uint256 localBalance = IERC20Upgradeable(baseToken).balanceOf(address(this));
        // Tolerance of 0.1%
        require(localBalance >= balanceSnapshot * (MAX_BPS - 10) / MAX_BPS, "SmartFarmooor: funds still pending");
        _allocationIsCorrect();
        balanceSnapshot = 0;
        _deposit(localBalance);
        _unpause();
    }

    /**
     * @notice  Set a new Fee Manager
     * @param   newFeeManager  Address of the new Fee Manager
     */
    function setFeeManager(address newFeeManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setFeeManager(newFeeManager);
    }

    /**
     * @notice  Set a new Minimum harvest threshold
     * @dev     Should be set according to TVL and gas costs, should prevent Keepers to harvest too often
     * @param   newMinHarvestThreshold  New minimum harvest threshold
     */
    function setMinHarvestThreshold(uint256 newMinHarvestThreshold) external onlyRole(MANAGER_ROLE) {
        _setMinHarvestThreshold(newMinHarvestThreshold);
    }

    /**
     * @notice  Set the new Performance fee
     * @dev     Maximum 20%
     * @param   newPerformanceFee  New performance fee amount
     */
    function setPerformanceFee(uint16 newPerformanceFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setPerformanceFee(newPerformanceFee);
    }

    /**
    * @notice  Set the new Cap
    * @param   newCap  New cap amount for Deposits
    */
    function setCap(uint256 newCap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setCap(newCap);
    }

    /**
    * @notice  Set the new min amount
    * @param   newMinAmount  New min amount for Deposits
    */
    function setMinAmount(uint256 newMinAmount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMinAmount(newMinAmount);
    }

    /**
    * @notice  Set the new automation rules contract
    * @param   newAutomationRules  Address of the new automation rules contract
    */
    function setAutomationRules(address newAutomationRules) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setAutomationRules(newAutomationRules);
    }

    /**
     * @notice  Pause the Strategy
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice  Unpause the Strategy
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
    * @notice  Rescue a stuck ERC20 token
    */
    function rescueToken(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != baseToken, "SmartFarmooor: can't pull out base tokens");
        _rescueToken(token);
    }

    /**
    * @notice  Rescue native tokens
    */
    function rescueNative() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _rescueNative();
    }

    /** public **/

    /**
     * @notice  Returns the current price per share
     * @return  uint  The current price per share
     */
    function pricePerShare() public returns (uint) {
        return totalSupply() == 0 ? 10 ** decimals() : getModulesBalance() * 10 ** decimals() / totalSupply();
    }

    /**
     * @notice  Returns the last updated price per share
     * @return  uint  The last updated price per share
     */
    function lastUpdatedPricePerShare() external view returns (uint) {
        return totalSupply() == 0 ? 10 ** decimals() : getLastUpdatedModulesBalance() * 10 ** decimals() / totalSupply();
    }

    /**
     * @notice  Deposit Base token to the Strategy and get an IOU in exchange
     * @dev     Amount in base token decimals, this contract should be approved as spender before calling Deposit
     * @param   _amount  Amount of base token to transfer to the Strategy
     */
    function deposit(uint256 _amount) external nonReentrant whenNotPaused onlyRoleOrOpen(PRIVATE_ACCESS_ROLE) {
        require(_amount >= minAmount, "SmartFarmooor: amount too small");
        require(_amount + getModulesBalance() <= cap, "SmartFarmooor: Cap reached");

        if (totalSupply() > 0)
            _harvest();

        IERC20Upgradeable(baseToken).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 shares = _getUsersShare(_amount);

        _deposit(_amount);
        _mint(msg.sender, shares);

        emit Deposit(msg.sender, _amount);
    }

    /**
     * @notice  Withdraw from the Strategy, get Base token in exchange of IOU
     * @dev     Shares are in Strategy Decimals
     * @param   _shares  Amount of shares to be burned in exchange for Base token
     * @return  uint256  Base token amount that is transferred directly to caller
     * @return  uint256  Base token amount that is transferred asynchronously to caller
     */
    function withdraw(uint256 _shares) external payable whenNotPaused nonReentrant onlyRoleOrOpen(PRIVATE_ACCESS_ROLE) returns (uint256, uint256) {
        require(_shares > 0, "SmartFarmooor: withdraw can't be 0");
        require(_shares <= balanceOf(msg.sender), "SmartFarmooor: not enough shares");
        uint256 userFraction = (_shares * 10 ** decimals()) / totalSupply();
        uint executionFee = getExecutionFee(userFraction);
        require(msg.value >= executionFee, "SmartFarmooor: msg.value to small for withdraw execution");

        _burn(msg.sender, _shares);
        (uint totalInstantWithdrawn, uint totalPendingAsyncWithdraw) = _withdraw(userFraction, msg.sender);

        emit Withdraw(msg.sender, _shares, totalInstantWithdrawn + totalPendingAsyncWithdraw);
        return (totalInstantWithdrawn, totalPendingAsyncWithdraw);
    }

    /**
     * @notice  Harvest the Strategy : collect profit and compound them by depositing back into Modules
     * @dev     Compounds Base token, increases LP holdings on Modules
     * @return  uint256  Profits harvested
     */
    function harvest() external whenNotPaused nonReentrant returns (uint256) {
        return _harvest();
    }

    /**
     * @notice  Get the withdrawal execution fee for a given amount
     * @dev     Currently necessary for Modules that implement asynchronous protocols. Fee is in AVAX
     * @param   _shares  Amount of shares wished to be withdrawn
     * @return  uint256  Returns the execution fee, in AVAX
     */
    function getExecutionFee(uint _shares) public view returns (uint256) {
        uint256 i = 0;
        uint256 totalAsyncExecutionFee = 0;
        for (; i < numberOfModules; i += 1) {
            uint sharesForThatModule = _shares * 10 ** decimals() / totalSupply();
            totalAsyncExecutionFee += yieldOptions[i].module.getExecutionFee(sharesForThatModule);
        }
        return totalAsyncExecutionFee;
    }

    /** helper **/

    /**
     * @notice  Get current balance across all Modules
     * @dev     Amount is in Base token
     * @return  uint256  Returns total amount in Base token
     */
    function getModulesBalance() public returns (uint256) {
        uint256 totalModuleBalance = 0;
        for (uint256 i = 0; i < numberOfModules; i += 1) {
            totalModuleBalance += yieldOptions[i].module.getBalance();
        }
        return totalModuleBalance;
    }

    /**
     * @notice  Get last updated balance across all Modules
     * @dev     Amount is in Base token
     * @return  uint256  Returns total amount in Base token
     */
    function getLastUpdatedModulesBalance() public view returns (uint256) {
        uint256 totalModuleBalance = 0;
        for (uint256 i = 0; i < numberOfModules; i += 1) {
            totalModuleBalance += yieldOptions[i].module.getLastUpdatedBalance();
        }
        return totalModuleBalance;
    }

    /**
     * @notice  Get users share in proportion to the amount they provide
     * @param   _amount  Amount of base token
     * @return  uint256  Amount of shares
     */
    function _getUsersShare(uint256 _amount) private returns (uint256) {
        if (totalSupply() == 0) {
            return _amount;
        } else {
            uint256 userShare = (_amount * totalSupply()) / getModulesBalance();
            require(userShare > 0, "SmartFarmooor: userShare = 0");
            return userShare;
        }
    }

    /**
     * @notice  Pushes the funds across all the modules according to the allocation
     * @dev     Amount is in base token
     * @param   _amount  Amount to be deposited
     */
    function _deposit(uint _amount) private {
        uint amountForThatModule = 0;
        uint depositedAmount = 0;
        for (uint256 i = 0; i < numberOfModules; i += 1) {
            // At the last iteration deposit all that remains to avoid having a dust
            if (i == numberOfModules - 1) {
                amountForThatModule = _amount - depositedAmount;
            } else {
                amountForThatModule = yieldOptions[i].allocation * _amount / MAX_BPS;
            }
            // Check that the deposited amount is bigger than zero when depositing a tiny amount
            if (amountForThatModule > 0) {
                yieldOptions[i].module.deposit(amountForThatModule);
                depositedAmount += amountForThatModule;
            }
        }
    }

    /**
     * @notice  Pulls the funds from the all the modules according to users share fraction
     * @dev     Receivers needs to be specified in case of Async withdrawal
     * @param   _shareFraction  Amount of Users Shares to be withdrawn
     * @param   _receiver  Address of the receiver for the Base token
     * @return  uint  Instant amount withdrawn
     * @return  uint  Async amount withdrawn
     */
    function _withdraw(uint _shareFraction, address _receiver) private returns (uint, uint) {
        uint totalInstantWithdrawn = 0;
        uint totalPendingAsyncWithdraw = 0;

        for (uint i = 0; i < numberOfModules; i += 1) {
            uint fee = yieldOptions[i].module.getExecutionFee(_shareFraction);
            (uint instantWithdrawn, uint pendingAsyncWithdraw) = yieldOptions[i].module.withdraw{value : fee}(_shareFraction, _receiver);
            totalPendingAsyncWithdraw += pendingAsyncWithdraw;
            totalInstantWithdrawn += instantWithdrawn;
        }

        return (totalInstantWithdrawn, totalPendingAsyncWithdraw);
    }

    /**
     * @notice  Collects the profits from all the Modules and compounds them
     * @return  uint  Profits harvested
     */
    function _harvest() private returns (uint){
        uint256 profit = 0;
        for (uint256 i = 0; i < numberOfModules; i += 1) {
            profit += yieldOptions[i].module.harvest(address(this));
        }
        uint fee = profit * performanceFee / MAX_BPS;
        uint netProfit = profit - fee;
        if (fee != 0) {
            IERC20Upgradeable(baseToken).safeTransfer(feeManager, fee);
        }

        netProfit = IERC20(baseToken).balanceOf(address(this));

        if (netProfit > 0) {
            _deposit(netProfit);
        }

        emit Harvest(netProfit);
        return netProfit;
    }

    /**
     * @notice  Set a new Fee Manager implementation
     * @param   newFeeManager  Address of the new Manager
     */
    function _setFeeManager(address newFeeManager) private {
        require(
            newFeeManager != address(0),
            "SmartFarmooor: cannot be the zero address"
        );
        feeManager = newFeeManager;
    }

    /**
    * @notice  Set a new Cap implementation
    * @param   newCap  Amount of the new Cap
    */
    function _setCap(uint256 newCap) private {
        cap = newCap;
    }

    /**
    * @notice  Set a new min amount implementation
    * @param   newMinAmount  Min amount to deposit
    */
    function _setMinAmount(uint256 newMinAmount) private {
        minAmount = newMinAmount;
    }

    /**
     * @notice  Sets Base token asset
     * @param   newBaseToken  Address of the Base token contract
     */
    function _setBaseToken(address newBaseToken) private {
        require(
            newBaseToken != address(0),
            "SmartFarmooor: cannot be the zero address"
        );
        baseToken = newBaseToken;
    }

    /**
     * @notice  Set new Minimum harvest threshold implementation
     * @param   newMinHarvestThreshold  New minimum harvest threshold
     */
    function _setMinHarvestThreshold(uint256 newMinHarvestThreshold) private {
        require(baseToken != address(0), "SmartFarmooor: baseToken not initialized");
        minHarvestThreshold = newMinHarvestThreshold;
    }

    /**
     * @notice  Set new Performance fee implementation
     * @param   newPerformanceFee  New Performance fee
     */
    function _setPerformanceFee(uint16 newPerformanceFee) private {
        require(
            newPerformanceFee <= 2000,
            "SmartFarmooor: performanceFee fee must be less than 20%"
        );
        performanceFee = newPerformanceFee;
    }

    /**
    * @notice  Set the new automation rules contract
    * @param   newAutomationRules  Address of the new automation rules contract
    */
    function _setAutomationRules(address newAutomationRules) private {
        require(
            newAutomationRules != address(0),
            "SmartFarmooor: cannot be the zero address"
        );
        automationRules = newAutomationRules;
    }

    function _allocationIsCorrect() private {
        uint totalAllocation = 0;
        for (uint i = 0; i < numberOfModules; i += 1) {
            require(yieldOptions[i].allocation >= 100, "SmartFarmooor: Min allocation too low");
            totalAllocation += yieldOptions[i].allocation;
        }
        require(totalAllocation == MAX_BPS, "SmartFarmooor: total allocation is wrong");
    }

    /** keeper **/

    /**
     * @notice  Keeper check interface. If Harvesting is possible, returns true
     * @dev     Harvesting threshold sould not be too low
     * @param   checkData  Harvesting check
     * @return  upkeepNeeded  Not used - Chainlink compliant
     * @return  performData  Not used - Chainlink compliant
     */
    function checkUpkeep(bytes calldata checkData) external pure returns (bool upkeepNeeded, bytes memory performData) {
        if (keccak256(checkData) == HARVEST_PROFIT) {
            return (true, checkData);
        }
        return (false, "");
    }

    /**
     * @notice  Perform the Keeper operation
     * @dev     Profit must be bigger than minimum harvest threshold
     * @param   performData  Harvesting operation
     */
    function performUpkeep(bytes calldata performData) external {
        if (keccak256(performData) == HARVEST_PROFIT) {
            uint profit = _harvest();
            require(profit * MAX_BPS / (MAX_BPS - performanceFee) > minHarvestThreshold, "SmartFarmooor: not enough to harvest");
            return;
        }
        revert("Unknown task");
    }

    /** fallback **/

    receive() external payable {}
}
