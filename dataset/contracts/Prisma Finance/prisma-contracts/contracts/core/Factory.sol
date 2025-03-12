// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "../dependencies/PrismaOwnable.sol";
import "../interfaces/ITroveManager.sol";
import "../interfaces/IBorrowerOperations.sol";
import "../interfaces/IDebtToken.sol";
import "../interfaces/ISortedTroves.sol";
import "../interfaces/IStabilityPool.sol";
import "../interfaces/ILiquidationManager.sol";

/**
    @title Prisma Trove Factory
    @notice Deploys cloned pairs of `TroveManager` and `SortedTroves` in order to
            add new collateral types within the system.
 */
contract Factory is PrismaOwnable {
    using Clones for address;

    // fixed single-deployment contracts
    IDebtToken public immutable debtToken;
    IStabilityPool public immutable stabilityPool;
    ILiquidationManager public immutable liquidationManager;
    IBorrowerOperations public immutable borrowerOperations;

    // implementation contracts, redeployed each time via clone proxy
    address public sortedTrovesImpl;
    address public troveManagerImpl;

    mapping(address collateral => address troveManagerImpl) public troveManagerOverrides;
    mapping(address collateral => bool deployed) public collateralDeployed;

    struct DeploymentParams {
        uint256 minuteDecayFactor;
        uint256 redemptionFeeFloor;
        uint256 maxRedemptionFee;
        uint256 borrowingFeeFloor;
        uint256 maxBorrowingFee;
        uint256 interestRate;
        uint256 maxDebt;
    }

    error CollateralAlreadyDeployed(address collateral);

    event NewDeployment(address collateral, address priceFeed, address troveManager, address sortedTroves);

    constructor(
        address _prismaCore,
        IDebtToken _debtToken,
        IStabilityPool _stabilityPool,
        IBorrowerOperations _borrowerOperations,
        address _sortedTroves,
        address _troveManager,
        ILiquidationManager _liquidationManager
    ) PrismaOwnable(_prismaCore) {
        debtToken = _debtToken;
        stabilityPool = _stabilityPool;
        borrowerOperations = _borrowerOperations;

        sortedTrovesImpl = _sortedTroves;
        troveManagerImpl = _troveManager;
        liquidationManager = _liquidationManager;
    }

    /**
        @notice Deploy new instances of `TroveManager` and `SortedTroves`, adding
                a new collateral type to the system.
        @dev After calling this function, the owner should also call `Treasury.registerReceiver`
             to enable PRISMA emissions on the newly deployed `TroveManager`
        @param collateral Collateral token to use in new deployment
        @param priceFeed Custom `PriceFeed` deployment. Leave as `address(0)` to use the default.
        @param customTroveManagerImpl Custom `TroveManager` implementation to clone from.
                                      Leave as `address(0)` to use the default.
        @param customSortedTrovesImpl Custom `SortedTroves` implementation to clone from.
                                      Leave as `address(0)` to use the default.
        @param params Struct of initial parameters to be set on the new trove manager
     */
    function deployNewInstance(
        address collateral,
        address priceFeed,
        address customTroveManagerImpl,
        address customSortedTrovesImpl,
        DeploymentParams memory params
    ) external onlyOwner {
        if (collateralDeployed[collateral]) revert CollateralAlreadyDeployed(collateral);
        address troveManager;
        if (customTroveManagerImpl == address(0)) {
            troveManager = troveManagerImpl.cloneDeterministic(bytes32(bytes20(collateral)));
        } else {
            troveManager = customTroveManagerImpl.cloneDeterministic(bytes32(bytes20(collateral)));
            troveManagerOverrides[collateral] = customTroveManagerImpl;
        }
        address sortedTroves;
        if (customSortedTrovesImpl == address(0)) {
            sortedTroves = sortedTrovesImpl.cloneDeterministic(bytes32(bytes20(collateral)));
        } else {
            sortedTroves = customSortedTrovesImpl.cloneDeterministic(bytes32(bytes20(collateral)));
        }

        ITroveManager(troveManager).setAddresses(priceFeed, sortedTroves, collateral);
        ISortedTroves(sortedTroves).setAddresses(troveManager);

        stabilityPool.enableCollateral(collateral);
        liquidationManager.enableCollateral(troveManager, collateral);
        debtToken.enableCollateral(troveManager);
        borrowerOperations.enableCollateral(troveManager, collateral);

        ITroveManager(troveManager).setParameters(
            params.minuteDecayFactor,
            params.redemptionFeeFloor,
            params.maxRedemptionFee,
            params.borrowingFeeFloor,
            params.maxBorrowingFee,
            params.interestRate,
            params.maxDebt
        );
        collateralDeployed[collateral] = true;
        emit NewDeployment(collateral, priceFeed, troveManager, sortedTroves);
    }

    function setImplementations(address _troveManagerImpl, address _sortedTrovesImpl) external onlyOwner {
        troveManagerImpl = _troveManagerImpl;
        sortedTrovesImpl = _sortedTrovesImpl;
    }

    function getTroveManager(address collateral) public view returns (ITroveManager) {
        if (!collateralDeployed[collateral]) return ITroveManager(address(0));
        address overrideImpl = troveManagerOverrides[collateral];
        address actualTroveManagerImpl = overrideImpl == address(0) ? troveManagerImpl : overrideImpl;
        return ITroveManager(Clones.predictDeterministicAddress(actualTroveManagerImpl, bytes32(bytes20(collateral))));
    }
}
