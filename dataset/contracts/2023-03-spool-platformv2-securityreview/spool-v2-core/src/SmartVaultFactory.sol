// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import "./interfaces/IAction.sol";
import "./interfaces/IAssetGroupRegistry.sol";
import "./interfaces/IGuardManager.sol";
import "./interfaces/IRiskManager.sol";
import "./interfaces/ISmartVault.sol";
import "./interfaces/ISmartVaultManager.sol";
import "./interfaces/ISpoolAccessControl.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/CommonErrors.sol";
import "./interfaces/Constants.sol";
import "./interfaces/RequestType.sol";
import "./access/Roles.sol";
import "./SmartVault.sol";

/* ========== ERRORS ========== */

/**
 * @notice Used when no strategy was provided during smart vault registration.
 */
error SmartVaultRegistrationNoStrategies();

/**
 * @notice Used when too many strategies were provided during smart vault registration.
 */
error StrategyCapExceeded();

/**
 * @notice Used when user has duplicated strategies when creating a new vault
 */
error StrategiesNotUnique();

/**
 * @notice Used when the number of allocation values is less than the number of strategies.
 */
error InvalidStrategyAllocationsLength();

/* ========== STRUCTS ========== */

/**
 * @notice Specification for smart vault deployment.
 * @custom:member smartVaultName Name of the smart vault.
 * @custom:member assetGroupId ID of the asset group.
 * @custom:member strategies Strategies used by the smart vault.
 * @custom:member strategyAllocation Optional. If empty array, values will be calculated on the spot.
 * @custom:member riskTolerance Risk appetite of the smart vault.
 * @custom:member riskProvider Risk provider used by the smart vault.
 * @custom:member allocationProvider Allocation provider used by the smart vault.
 * @custom:member actions Actions to register for the smart vault.
 * @custom:member actionRequestTypes Request types for actions.
 * @custom:member guards Guards to register for the smart vault.
 * @custom:member guardRequestTypes Request types for the smart vault.
 * @custom:member managementFeePCt Management fee percentage.
 * @custom:member depositFeePct Deposit fee percentage.
 * @custom:member allowRedeemFor Allow vault owner to initiate redeem on behalf of others.
 */
struct SmartVaultSpecification {
    string smartVaultName;
    uint256 assetGroupId;
    address[] strategies;
    uint16a16 strategyAllocation;
    int8 riskTolerance;
    address riskProvider;
    address allocationProvider;
    IAction[] actions;
    RequestType[] actionRequestTypes;
    GuardDefinition[][] guards;
    RequestType[] guardRequestTypes;
    uint16 managementFeePct;
    uint16 depositFeePct;
    uint16 performanceFeePct;
    bool allowRedeemFor;
}

/* ========== CONTRACTS ========== */

/**
 * @dev Requires roles:
 * - ROLE_SMART_VAULT_INTEGRATOR
 */
contract SmartVaultFactory is UpgradeableBeacon {
    using uint16a16Lib for uint16a16;

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when a new smart vault is deployed.
     * @param smartVault Address of the newly deployed smart vault.
     * @param deployer Address of the deployer.
     */
    event SmartVaultDeployed(address indexed smartVault, address indexed deployer);

    /* ========== CONSTANTS ========== */

    /**
     * @notice Spool access control contract.
     */
    ISpoolAccessControl immutable _accessControl;

    /**
     * @notice Action manager contract.
     */
    IActionManager immutable _actionManager;

    /**
     * @notice Guard manager contract.
     */
    IGuardManager immutable _guardManager;

    /**
     * @notice Smart vault manager contract.
     */
    ISmartVaultRegistry immutable _smartVaultRegistry;

    /**
     * @notice Asset group registry contract.
     */
    IAssetGroupRegistry immutable _assetGroupRegistry;

    /**
     * @notice Risk manager contract.
     */
    IRiskManager immutable _riskManager;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address implementation,
        ISpoolAccessControl accessControl_,
        IActionManager actionManager_,
        IGuardManager guardManager_,
        ISmartVaultRegistry smartVaultRegistry_,
        IAssetGroupRegistry assetGroupRegistry_,
        IRiskManager riskManager_
    ) UpgradeableBeacon(implementation) {
        _accessControl = accessControl_;
        _actionManager = actionManager_;
        _guardManager = guardManager_;
        _smartVaultRegistry = smartVaultRegistry_;
        _assetGroupRegistry = assetGroupRegistry_;
        _riskManager = riskManager_;
    }

    /* ========== EXTERNAL MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Deploys a new smart vault into the Spool ecosystem.
     * @param specification Specifications for the new smart vault.
     * @return smartVault Deployed smart vault.
     */
    function deploySmartVault(SmartVaultSpecification calldata specification) external returns (ISmartVault) {
        _validateSpecification(specification);

        address smartVaultAddress = address(
            new BeaconProxy(
                address(this),
                _encodeInitializationCalldata(specification)
            )
        );

        _integrateSmartVault(smartVaultAddress, specification);

        emit SmartVaultDeployed(smartVaultAddress, msg.sender);

        return ISmartVault(smartVaultAddress);
    }

    /**
     * @notice Deploys a new smart vault to a deterministic address.
     * @param specification Specifications for the new smart vault.
     * @param salt Salt for address determination.
     * @return smartVault Deployed smart vault.
     */
    function deploySmartVaultDeterministically(SmartVaultSpecification calldata specification, bytes32 salt)
        external
        returns (ISmartVault)
    {
        _validateSpecification(specification);

        address smartVaultAddress = address(
            new BeaconProxy{salt: salt}(
                address(this),
                _encodeInitializationCalldata(specification)
            )
        );

        _integrateSmartVault(smartVaultAddress, specification);

        emit SmartVaultDeployed(smartVaultAddress, msg.sender);

        return ISmartVault(smartVaultAddress);
    }

    /* ========== EXTERNAL VIEW FUNCTIONS ========== */

    /**
     * @notice Predicts deployment address deterministically deployed smart vault.
     * @param specification Specifications for the new smart vault.
     * @param salt Salt for address determination.
     * @return predictedAddress Predicted address.
     */
    function predictDeterministicAddress(SmartVaultSpecification calldata specification, bytes32 salt)
        external
        view
        returns (address)
    {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            keccak256(
                                abi.encodePacked(
                                    type(BeaconProxy).creationCode,
                                    abi.encode(address(this), _encodeInitializationCalldata(specification))
                                )
                            )
                        )
                    )
                )
            )
        );
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /**
     * @notice Validates smart vault specification.
     * @param specification Specifications for the new smart vault.
     */
    function _validateSpecification(SmartVaultSpecification calldata specification) private view {
        _assetGroupRegistry.validateAssetGroup(specification.assetGroupId);

        if (specification.strategies.length == 0) {
            revert SmartVaultRegistrationNoStrategies();
        }
        if (specification.strategies.length > STRATEGY_COUNT_CAP) {
            revert StrategyCapExceeded();
        }

        unchecked {
            bool fixedAllocations = uint16a16.unwrap(specification.strategyAllocation) > 0;
            for (uint256 i; i < specification.strategies.length; ++i) {
                if (fixedAllocations && specification.strategyAllocation.get(i) == 0) {
                    revert InvalidStrategyAllocationsLength();
                }

                if (!_accessControl.hasRole(ROLE_STRATEGY, specification.strategies[i])) {
                    revert InvalidStrategy(specification.strategies[i]);
                }

                if (IStrategy(specification.strategies[i]).assetGroupId() != specification.assetGroupId) {
                    revert NotSameAssetGroup();
                }

                for (uint256 j = i + 1; j < specification.strategies.length; ++j) {
                    if (specification.strategies[i] == specification.strategies[j]) {
                        revert StrategiesNotUnique();
                    }
                }
            }
        }

        if (specification.managementFeePct > MANAGEMENT_FEE_MAX) {
            revert ManagementFeeTooLarge(specification.managementFeePct);
        }
        if (specification.depositFeePct > DEPOSIT_FEE_MAX) {
            revert DepositFeeTooLarge(specification.depositFeePct);
        }
        if (specification.performanceFeePct > SV_PERFORMANCE_FEE_MAX) {
            revert PerformanceFeeTooLarge(specification.performanceFeePct);
        }
    }

    /**
     * @notice Encodes calldata for smart vault initialization.
     * @param specification Specifications for the new smart vault.
     * @return initializationCalldata Enoded initialization calldata.
     */
    function _encodeInitializationCalldata(SmartVaultSpecification calldata specification)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "initialize(string,uint256)", specification.smartVaultName, specification.assetGroupId
        );
    }

    /**
     * @notice Integrates newly created smart vault into the Spool ecosystem.
     * @param smartVaultAddress Address of created smart vault.
     * @param specification Specifications for the new smart vault.
     */
    function _integrateSmartVault(address smartVaultAddress, SmartVaultSpecification calldata specification) private {
        _accessControl.grantSmartVaultOwnership(smartVaultAddress, msg.sender);
        _actionManager.setActions(smartVaultAddress, specification.actions, specification.actionRequestTypes);
        _guardManager.setGuards(smartVaultAddress, specification.guards, specification.guardRequestTypes);

        if (specification.allowRedeemFor) {
            _accessControl.grantRole(ROLE_SMART_VAULT_ALLOW_REDEEM, smartVaultAddress);
        }

        uint16a16 allocations = specification.strategyAllocation;

        // set allocation
        if (uint16a16.unwrap(allocations) == 0) {
            _riskManager.setRiskProvider(smartVaultAddress, specification.riskProvider);
            _riskManager.setRiskTolerance(smartVaultAddress, specification.riskTolerance);
            _riskManager.setAllocationProvider(smartVaultAddress, specification.allocationProvider);

            allocations = _riskManager.calculateAllocation(smartVaultAddress, specification.strategies);
        }

        _smartVaultRegistry.registerSmartVault(
            smartVaultAddress,
            SmartVaultRegistrationForm({
                assetGroupId: specification.assetGroupId,
                strategies: specification.strategies,
                strategyAllocation: allocations,
                managementFeePct: specification.managementFeePct,
                depositFeePct: specification.depositFeePct,
                performanceFeePct: specification.performanceFeePct
            })
        );
    }
}
