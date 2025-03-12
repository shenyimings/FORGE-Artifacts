// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

// extends
import "./interfaces/IController.sol";
import "./shared/SpoolOwnable.sol";
import "./shared/Constants.sol";

// libraries
import "./external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./libraries/Hash.sol";

// other imports
import "./interfaces/ISpool.sol";
import "./interfaces/IRiskProviderRegistry.sol";
import "./interfaces/IBaseStrategy.sol";
import "./interfaces/IVault.sol";
import "./vault/VaultNonUpgradableProxy.sol";

/**
 * @notice Implementation of the {IController} interface.
 *
 * @dev
 * This implementation joins the various contracts of the Spool
 * system together to allow the creation of new vaults in the system
 * as well as allow the Spool to validate that its incoming requests
 * are indeed from a vault in the system.
 *
 * The contract can be thought of as the central point of contract
 * for assessing the validity of data in the system (i.e. supported strategy, vault etc.).
 */
contract Controller is IController, SpoolOwnable, BaseConstants {
    using SafeERC20 for IERC20;

    /* ========== CONSTANTS ========== */

    /// @notice Maximum vault creator fee - 20%
    uint256 public constant MAX_VAULT_CREATOR_FEE = 20_00;

    /// @notice Maximum vault creator fee if the creator is the Spool DAO - 60%
    uint256 public constant MAX_DAO_VAULT_CREATOR_FEE = 60_00;

    /// @notice Maximum number of vault strategies
    uint256 public constant MAX_VAULT_STRATEGIES = 18;

    /// @notice Minimum vault risk tolerance
    int8 public constant MIN_RISK_TOLERANCE = -10;

    /// @notice Maximum vault risk tolerance
    int8 public constant MAX_RISK_TOLERANCE = 10;

    /* ========== STATE VARIABLES ========== */

    /// @notice The central Spool contract
    ISpool public immutable spool;
    
    /// @notice The risk provider registry
    IRiskProviderRegistry public immutable riskRegistry;

    /// @notice vault implementation address
    address public immutable vaultImplementation;

    /// @notice The list of strategies supported by the system
    address[] public override strategies;

    /// @notice Hash of strategies list
    bytes32 public strategiesHash;

    /// @notice The total vaults created in the system
    uint256 public totalVaults;
    
    /// @notice Recipient address of emergency withdrawn funds
    address public emergencyRecipient;

    /// @notice Whether the specified token is supported as an underlying token for a vault
    mapping(IERC20 => bool) public override supportedUnderlying;

    /// @notice Whether the particular vault address is valid
    mapping(address => bool) public override validVault;

    /// @notice Whether the particular strategy address is valid
    mapping(address => bool) public override validStrategy;

    /// @notice Whether the address is the emergency withdrawer
    mapping(address => bool) public isEmergencyWithdrawer;

    /**
     * @notice Sets the contract initial values.
     *
     * @dev It performms certain pre-conditional validations to ensure the contract
     * has been initialized properly, such as that both addresses are valid.
     *
     * Ownership of the contract beyond deployment should be transferred to
     * the Spool DAO to avoid centralization of control.
     * 
     * @param _spoolOwnable the spool owner contract that owns this contract
     * @param _riskRegistry the risk provider registry contract
     * @param _spool the spool contract
     * @param _vaultImplementation vault implementation contract address
     */
    constructor(
        ISpoolOwner _spoolOwnable,
        IRiskProviderRegistry _riskRegistry,
        ISpool _spool,
        address _vaultImplementation
    ) 
        SpoolOwnable(_spoolOwnable)
    {
        require(
            _riskRegistry != IRiskProviderRegistry(address(0)) &&
            _spool != ISpool(address(0)) &&
            _vaultImplementation != address(0),
            "Controller::constructor: Risk Provider, Spool or Vault Implementation addresses cannot be 0"
        );

        riskRegistry = _riskRegistry;
        spool = _spool;
        vaultImplementation = _vaultImplementation;

        _updateStrategiesHash(strategies);
    }

    /* ========== VIEWS ========== */

    /**
     * @notice Returns all strategy contract addresses.
     *
     * @return array of strategy addresses
     */
    function getAllStrategies()
        external
        view
        override
        returns (address[] memory)
    {
        return strategies;
    }

    /**
     * @notice Returns the amount of strategies registered
     *
     * @return strategies count
     */
    function getStrategiesCount() external override view returns(uint8) {
        return uint8(strategies.length);
    }

    /**
     * @notice hash strategies list, verify hash matches to storage hash.
     *
     * @dev
     *
     * Requirements:
     *
     * - hash of input matches hash in storage
     *
     * @param _strategies list of strategies to check
     */
    function verifyStrategies(address[] calldata _strategies) external override view {
        require(Hash.sameStrategies(_strategies, strategiesHash), "Controller::verifyStrategies: Incorrect strategies");
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Allows the creation of a new vault.
     *
     * @dev
     * The vault creator is immediately set as the allocation provider as well as
     * reward token setter. These traits are all transferrable and should be transferred
     * to another person beyond creation.
     *
     * Emits a {VaultCreated} event indicating the address of the vault. Parameters cannot
     * be emitted due to reaching the stack limit and should instead be fetched from the
     * vault directly.
     *
     * Requirements:
     *
     * - the underlying currency must be supported by the system
     * - the strategies and proportions must be equal in length
     * - the sum of the strategy proportions must be 100%
     * - the strategies must all be supported by the system
     * - the strategies must be unique
     * - the underlying asset of the strategies must match the desired one
     * - the fee of the vault owner must not exceed 20% in basis points,
     *   or 60% if creator is the Spool DAO
     * - the risk provider must exist in the risk provider registry
     * - the risk tolerance of the vault must be within the [-10, 10] range
     *
     * @param details details of the vault to be created (see VaultDetails)
     *
     * @return vault address of the newly created vault 
     */
    function createVault(
        VaultDetails calldata details
    ) external returns (address vault) {
        require(
            details.creator != address(0),
            "Controller::createVault: Missing vault creator"
        );
        require(
            supportedUnderlying[IERC20(details.underlying)],
            "Controller::createVault: Unsupported currency"
        );
        require(
            details.strategies.length > 0 && details.strategies.length <= MAX_VAULT_STRATEGIES,
            "Controller::createVault: Invalid number of strategies"
        );
        require(
            details.strategies.length == details.proportions.length,
            "Controller::createVault: Improper setup"
        );

        uint256 total;
        for (uint256 i = 0; i < details.strategies.length; i++) {
            // check if all strategies are unique
            for (uint256 j = i+1; j < details.strategies.length; j++) {
                require(details.strategies[i] != details.strategies[j], "Controller::createVault: Strategies not unique");
            }

            require(
                validStrategy[details.strategies[i]],
                "Controller::createVault: Unsupported strategy"
            );
            IBaseStrategy strategy = IBaseStrategy(details.strategies[i]);

            require(
                strategy.underlying() == IERC20(details.underlying),
                "Controller::createVault: Incorrect currency for strategy"
            );

            total += details.proportions[i];
        }

        require(
            total == FULL_PERCENT,
            "Controller::createVault: Improper allocations"
        );

        require(
            details.vaultFee <= MAX_VAULT_CREATOR_FEE ||
            // Spool DAO can set higher vault owner fee
            (details.vaultFee <= MAX_DAO_VAULT_CREATOR_FEE && isSpoolOwner()),
            "Controller::createVault: High owner fee"
        );

        require(
            riskRegistry.isProvider(details.riskProvider),
            "Controller::createVault: Invalid risk provider"
        );

        require(
            details.riskTolerance >= MIN_RISK_TOLERANCE &&
            details.riskTolerance <= MAX_RISK_TOLERANCE,
            "Controller::createVault: Incorrect Risk Tolerance"
        );

        vault = _createVault(details);

        validVault[vault] = true;
        totalVaults++;

        emit VaultCreated(vault);
    }

    /**
     * @notice Allows the creation of a new vault.
     *
     * @dev
     * Creates an instance of the Vault proxy contract and returns the address to the Controller.
     *
     * @param vaultDetails details of the vault to be created (see VaultDetails)
     * @return vault Address of newly created vault 
     */
    function _createVault(
        VaultDetails calldata vaultDetails
    ) private returns (address vault) {
        vault = address(
            new VaultNonUpgradableProxy(
                vaultImplementation,
                _getVaultImmutables(vaultDetails)
            )
        );

        IVault(vault).initialize(_getVaultInitializable(vaultDetails));
    }

    /**
     * @notice Return new vault immutable values
     *
     * @param vaultDetails details of the vault to be created
     */
    function _getVaultImmutables(VaultDetails calldata vaultDetails) private pure returns (VaultImmutables memory) {
        return VaultImmutables(
            IERC20(vaultDetails.underlying),
            vaultDetails.riskProvider,
            vaultDetails.riskTolerance
        );
    }

    /**
     * @notice Return new vault initializable values
     *
     * @param vaultDetails details of the vault to be created
     */
    function _getVaultInitializable(VaultDetails calldata vaultDetails) private pure returns (VaultInitializable memory) {
        return VaultInitializable(
            vaultDetails.name,
            vaultDetails.creator,
            vaultDetails.vaultFee,
            vaultDetails.strategies,
            vaultDetails.proportions
        );
    }

    /**
     * @notice Allows a user to claim their reward drip rewards across multiple vaults
     * in a single transaction.
     *
     * @dev
     * Requirements:
     *
     * - the caller must have rewards in all the vaults specified
     * - the vaults must be valid vaults in the Spool system
     *
     * @param vaults vaults for which to claim rewards for
     */
    function getRewards(IVault[] calldata vaults) external {
        for (uint256 i = 0; i < vaults.length; i++) {
            require(
                validVault[address(vaults[i])],
                "Controller::getRewards: Invalid vault specified"
            );
            vaults[i].getActiveRewards(msg.sender);
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /**
     * @notice transfer vault underlying tokens to the Spool contact, from a user.
     *
     * @dev
     * Users of multiple vaults can choose to set allowance for the underlying token to this contract only, and then 
     * interact with any vault without having to set allowance to each vault induvidually.
     *
     * Requirements:
     *
     * - the caller must be a vault
     * - user (transferFrom address) must have given enough allowance to this contract 
     * - user (transferFrom address) must have enough tokens to transfer
     *
     * @param transferFrom address to transfer the tokens from (user address from vault)
     * @param amount amount of underlying tokens to transfer to the Spool
     */
    function transferToSpool(address transferFrom, uint256 amount) external override onlyVault {
        IVault(msg.sender).underlying().safeTransferFrom(transferFrom, address(spool), amount);
    }

    /**
     * @notice Allows a new strategy to be added to the Spool system.
     *
     * @dev
     * Emits a {StrategyAdded} event indicating the newly added strategy
     * and whether it is multi-collateral.
     *
     * Requirements:
     *
     * - the caller must be the contract owner (Spool DAO)
     * - the strategy must not have already been added
     * 
     * @param strategy the strategy to add to the system
     */
    function addStrategy(
        address strategy,
        address[] memory allStrategies
    )
        external
        onlyOwner
        validStrategiesOrEmpty(allStrategies)
    {
        require(
            !validStrategy[strategy],
            "Controller::addStrategy: Strategy already registered"
        );

        validStrategy[strategy] = true;

        IERC20 underlying = IBaseStrategy(strategy).underlying();
        supportedUnderlying[underlying] = true;

        spool.addStrategy(strategy);

        strategies.push(strategy);

        // update strategies hash
        // update can happen using stored strategies or provided ones
        if (allStrategies.length == 0) {
            _updateStrategiesHash(strategies);
        } else {
            allStrategies = _addStrategy(allStrategies, strategy);
            _updateStrategiesHash(allStrategies);
        }

        emit StrategyAdded(strategy);
    }

    function _addStrategy(address[] memory currentStrategies, address strategy) private pure returns(address[] memory) {
        address[] memory newStrategies = new address[](currentStrategies.length + 1);
        for(uint256 i = 0; i < currentStrategies.length; i++) {
            newStrategies[i] = currentStrategies[i];
        }

        newStrategies[newStrategies.length - 1] = strategy;

        return newStrategies;
    }

    /**
     * @notice Allows an existing strategy to be removed from the Spool system,
     * withdrawing and liquidating any actively deployed funds in the strategy.
     *
     * @dev
     * Withdrawn funds are sent to the `emergencyRecipient` address. If the address is 0
     * Funds will be sent to the caller of this function. 
     *
     * Emits a {StrategyRemoved} event indicating the removed strategy.
     *
     * Requirements:
     *
     * - the caller must be the emergency withdrawer
     * - the strategy must already exist in the contract
     * - the provided strategies array must be vaild or empty
     *
     * @param strategy the strategy to remove from the system
     * @param skipDisable flag to skip execution of strategy specific disable (e.g cleanup tasks) function.
     * @param data strategy specific data required to withdraw the funds from the strategy 
     * @param allStrategies current valid strategies or empty array
     */
    function removeStrategyAndWithdraw(
        address strategy,
        bool skipDisable,
        uint256[] calldata data,
        address[] calldata allStrategies
    )
        external
        onlyEmergencyWithdrawer
    {
        _removeStrategy(strategy, skipDisable, allStrategies);
        _emergencyWithdraw(strategy, data);
    }

    /**
     * @notice Allows an existing strategy to be removed from the Spool system.
     *
     * @dev
     *
     * Emits a {StrategyRemoved} event indicating the removed strategy.
     *
     * Requirements:
     *
     * - the caller must be the emergency withdrawer
     * - the strategy must already exist in the contract
     * - the provided strategies array must be vaild or empty
     *
     * @param strategy the strategy to remove from the system
     * @param skipDisable flag to skip execution of strategy specific disable (e.g cleanup tasks) function.
     * @param allStrategies current valid strategies or empty array
     */
    function removeStrategy(
        address strategy,
        bool skipDisable,
        address[] calldata allStrategies
    )
        external
        onlyEmergencyWithdrawer
    {
        _removeStrategy(strategy, skipDisable, allStrategies);
    }

    /**
     * @notice Withdraws and liquidates any actively deployed funds from already removed strategy.
     *
     * @dev
     * Withdrawn funds are sent to the `emergencyRecipient` address. If the address is 0
     * Funds will be sent to the caller of this function. 
     *
     * Requirements:
     *
     * - the caller must be the emergency withdrawer
     * - the strategy must already be removed
     *
     * @param strategy the strategy to remove from the system
     * @param data strategy specific data required to withdraw the funds from the strategy 
     */
    function emergencyWithdraw(
        address strategy,
        uint256[] calldata data
    ) 
        external
        onlyEmergencyWithdrawer
    {
        require(
            !validStrategy[strategy],
            "VaultRegistry::removeStrategy: Strategy should not be valid"
        );

        _emergencyWithdraw(strategy, data);
    }

    /**
     * @notice Allows an existing strategy to be removed from the Spool system.
     *
     * @dev
     *
     * Emits a {StrategyRemoved} event indicating the removed strategy.
     *
     * Requirements:
     *
     * - the strategy must already exist in the contract
     * - the provided strategies array must be vaild or empty
     *
     * @param strategy the strategy to remove from the system
     * @param skipDisable flag to skip execution of strategy specific disable (e.g cleanup tasks) function.
     * @param allStrategies current valid strategies or empty array
     */
    function _removeStrategy(
        address strategy,
        bool skipDisable,
        address[] calldata allStrategies
    )
        private
        validStrategiesOrEmpty(allStrategies)
    {
        require(
            validStrategy[strategy],
            "Controller::removeStrategy: Strategy is not registered"
        );

        spool.disableStrategy(strategy, skipDisable);

        validStrategy[strategy] = false;

        // update strategies storage array and hash
        // update can happen using strategies from storage or from calldata
        if (allStrategies.length == 0) {
            _removeStrategyStorage(strategy);
        } else {
            _removeStrategyCalldata(allStrategies, strategy);
        }

        emit StrategyRemoved(strategy);
    }

    /**
     * @notice Remove strategy from storage array and update the strategies hash
     *
     * @param strategy strategy address to remove
     */
    function _removeStrategyStorage(address strategy) private {
        uint256 lastEntry = strategies.length - 1;
        for (uint256 i = 0; i < lastEntry; i++) {
            if (strategies[i] == strategy) {
                strategies[i] = strategies[lastEntry];
                break;
            }
        }

        strategies.pop();

        _updateStrategiesHash(strategies);
    }

    /**
     * @notice Remove strategy from storage array using calldata array and update the strategies hash
     * @dev Should significantly lower the cost of removing a strategy
     *
     * @param allStrategies current valid strategies stored in calldata
     * @param strategy strategy address to remove
     */
    function _removeStrategyCalldata(address[] calldata allStrategies, address strategy) private {
        uint256 lastEntry = allStrategies.length - 1;
        address[] memory newStrategies = allStrategies[0:lastEntry];

        for (uint256 i = 0; i < lastEntry; i++) {
            if (allStrategies[i] == strategy) {
                strategies[i] = allStrategies[lastEntry];
                newStrategies[i] = allStrategies[lastEntry];
                break;
            }
        }

        strategies.pop();

        _updateStrategiesHash(newStrategies);
    }

    /**
     * @notice Liquidating all actively deployed funds within a strategy after it was disabled.
     *
     * @param strategy strategy to withdraw from
     * @param data data to perform the withdrawal
     */
    function _emergencyWithdraw(
        address strategy,
        uint256[] calldata data
    )
        private
    {
        spool.emergencyWithdraw(
            strategy,
            _getEmergencyRecipient(),
            data
        );

        emit EmergencyWithdrawStrategy(strategy);
    }

    /**
     * @notice Returns address to send the emergency whithdrawn funds
     * @dev if the address is not defined assets are sent to the caller address
     */
    function _getEmergencyRecipient() private view returns(address _emergencyRecipient) {
        _emergencyRecipient = emergencyRecipient;

        if (_emergencyRecipient == address(0)) {
            _emergencyRecipient = msg.sender;
        }
    }

    /**
     * @notice Execute strategy disable function after it was removed.
     *
     * @dev
     * Requirements:
     *
     * - the caller must be the emergency withdrawer
     *
     * @param strategy strategy to execute disable
     */
    function runDisableStrategy(address strategy)
        external
        onlyEmergencyWithdrawer
    {
        require(
            !validStrategy[strategy],
            "Controller::runDisableStrategy: Strategy is still valid"
        );

        spool.runDisableStrategy(strategy);
    }

    /**
     * @notice Add or remove the emergency withdrawer right
     *
     * @dev
     * Requirements:
     *
     * - the caller must be the contract owner (Spool DAO)
     */
    function setEmergencyWithdrawer(address user, bool _isEmergencyWithdrawer) external onlyOwner {
        isEmergencyWithdrawer[user] = _isEmergencyWithdrawer;
        emit EmergencyWithdrawerUpdated(user, _isEmergencyWithdrawer);
    }

    /**
     * @notice Set the emergency withdraw recipient
     *
     * @dev
     * Requirements:
     *
     * - the caller must be the contract owner (Spool DAO)
     */
    function setEmergencyRecipient(address _emergencyRecipient) external onlyOwner {
        emergencyRecipient = _emergencyRecipient;
        emit EmergencyRecipientUpdated(_emergencyRecipient);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /**
     * @notice Following strategies change, update the strategies hash in storage.
     *
     * @param _strategies addresses of all valid strategies
     */
    function _updateStrategiesHash(address[] memory _strategies) private {
        strategiesHash = Hash.hashStrategies(_strategies);
    }

    /**
     * @notice Verify caller is a valid vault contact
     *
     * @dev
     * Only callable from onlyVault modifier.
     *
     * Requirements:
     *
     * - msg.sender is contained in validVault address mapping
     */
    function _onlyVault() private view {
        require(
            validVault[msg.sender],
            "Controller::_onlyVault: Can only be invoked by vault"
        );
    }

    /**
     * @notice Ensures that the caller is the emergency withdrawer
     */
    function _onlyEmergencyWithdrawer() private view {
        require(
            isEmergencyWithdrawer[msg.sender] || isSpoolOwner(),
            "Controller::_onlyEmergencyWithdrawer: Can only be invoked by the emergency withdrawer"
        );
    }

    /**
     * @notice Ensures the provided strategies are correct
     * @dev Allow if array of strategies is empty
     */
    function _validStrategiesOrEmpty(address[] memory _strategies) private view {
        require(
            _strategies.length == 0 ||
            Hash.sameStrategies(strategies, strategiesHash),
            "Controller::_validStrategiesOrEmpty: Strategies do not match"
        );
    }

    /* ========== MODIFIERS ========== */

    /**
     * @notice Throws if called by a non-valid vault
     */
    modifier onlyVault() {
        _onlyVault();
        _;
    }

    /**
     * @notice Throws if the caller is not emergency withdraw
     */
    modifier onlyEmergencyWithdrawer() {
        _onlyEmergencyWithdrawer();
        _;
    }

    /**
     * @notice Throws if the strategies are not valid or empty array
     */
    modifier validStrategiesOrEmpty(address[] memory allStrategies) {
        _validStrategiesOrEmpty(allStrategies);
        _;
    }
}
