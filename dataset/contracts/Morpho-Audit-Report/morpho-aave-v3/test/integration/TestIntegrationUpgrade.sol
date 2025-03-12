// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "test/helpers/IntegrationTest.sol";
import {Ownable2StepUpgradeable as Ownable} from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract TestIntegrationUpgrade is IntegrationTest {
    using Strings for uint256;

    UserMock internal supplier1;
    UserMock internal supplier2;
    UserMock internal borrower1;
    UserMock internal borrower2;

    // Excludes isManagedBy, userNonce
    struct UserStorageToCheck {
        uint256 scaledPoolSupplyBalance;
        uint256 scaledPoolBorrowBalance;
        uint256 scaledP2PSupplyBalance;
        uint256 scaledP2PBorrowBalance;
        uint256 scaledCollateralBalance;
        address[] userCollaterals;
        address[] userBorrows;
    }

    // Excludes positions manager.
    struct StorageToCheck {
        address owner;
        address pool;
        address addressesProvider;
        bytes32 domainSeparator;
        uint256 eModeCategoryId;
        Types.Market market;
        address[] marketsCreated;
        Types.Iterations defaultIterations;
        address rewardsManager;
        address treasuryVault;
        bool isClaimRewardsPaused;
        UserStorageToCheck supplier1;
        UserStorageToCheck supplier2;
        UserStorageToCheck borrower1;
        UserStorageToCheck borrower2;
    }

    function setUp() public virtual override {
        super.setUp();

        uint256 daiTokenUnit = 10 ** testMarkets[dai].decimals;
        uint256 usdcTokenUnit = 10 ** testMarkets[usdc].decimals;

        supplier1 = _initUser();
        supplier2 = _initUser();
        borrower1 = _initUser();
        borrower2 = _initUser();

        // Assigning variables to user's storage slots.
        // Supplier 1 should have 100 DAI in P2P
        // Supplier 2 should have 100 USDC on pool, 100 DAI in P2P
        // Borrower 1 should have 1000 USDC collateral and 150 DAI borrowed P2P
        // Borrower 2 should have 1000 USDC collateral, 50 DAI borrowed P2P, 250 DAI borrowed on pool.
        supplier1.approve(dai, 100 * daiTokenUnit);
        supplier2.approve(dai, 100 * daiTokenUnit);
        borrower1.approve(usdc, 1000 * usdcTokenUnit);
        borrower2.approve(usdc, 1000 * usdcTokenUnit);

        supplier1.supply(dai, 100 * daiTokenUnit);
        supplier2.supply(dai, 100 * daiTokenUnit);

        borrower1.supplyCollateral(usdc, 1000 * usdcTokenUnit);
        borrower2.supplyCollateral(usdc, 1000 * usdcTokenUnit);

        borrower1.borrow(dai, 150 * daiTokenUnit);
        borrower2.borrow(dai, 300 * daiTokenUnit);
    }

    function testUpgradeMorphoFailsIfNotProxyAdminOwner(address caller) public {
        vm.assume(caller != address(this));
        Morpho newMorphoImpl = new Morpho();

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(address(morpho))), address(newMorphoImpl));
    }

    function testUpgradeMorpho() public {
        address positionsManagerBefore = morpho.positionsManager();
        StorageToCheck memory s1 = _populateStorageToCheck();

        Morpho newMorphoImpl = new Morpho();
        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(address(morpho))), address(newMorphoImpl));

        StorageToCheck memory s2 = _populateStorageToCheck();

        _assertStorageEq(s1, s2);
        assertEq(positionsManagerBefore, morpho.positionsManager(), "positions manager");
        assertFalse(address(newMorphoImpl) == address(morphoImpl), "not new morpho impl");
    }

    function testSetPositionsManagerFailsIfNotOwner() public {
        positionsManager = new PositionsManager();
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(1));
        morpho.setPositionsManager(address(positionsManager));
    }

    function testSetPositionsManager() public {
        StorageToCheck memory s1 = _populateStorageToCheck();

        PositionsManager newPositionsManager = new PositionsManager();
        morpho.setPositionsManager(address(newPositionsManager));

        StorageToCheck memory s2 = _populateStorageToCheck();
        _assertStorageEq(s1, s2);
        assertFalse(morpho.positionsManager() == address(positionsManager), "not new positions manager");
    }

    function _populateStorageToCheck() internal view returns (StorageToCheck memory s) {
        s.owner = Ownable(address(morpho)).owner();
        s.pool = morpho.pool();
        s.addressesProvider = morpho.addressesProvider();
        s.domainSeparator = morpho.DOMAIN_SEPARATOR();
        s.eModeCategoryId = morpho.eModeCategoryId();
        s.market = morpho.market(dai);
        s.marketsCreated = morpho.marketsCreated();
        s.defaultIterations = morpho.defaultIterations();
        s.rewardsManager = morpho.rewardsManager();
        s.treasuryVault = morpho.treasuryVault();
        s.isClaimRewardsPaused = morpho.isClaimRewardsPaused();
        s.supplier1 = _populateUserStorageToCheck(address(supplier1));
        s.supplier2 = _populateUserStorageToCheck(address(supplier2));
        s.borrower1 = _populateUserStorageToCheck(address(borrower1));
        s.borrower2 = _populateUserStorageToCheck(address(borrower2));
    }

    function _populateUserStorageToCheck(address user) internal view returns (UserStorageToCheck memory u) {
        u.scaledPoolSupplyBalance = morpho.scaledPoolSupplyBalance(dai, user);
        u.scaledPoolBorrowBalance = morpho.scaledPoolBorrowBalance(dai, user);
        u.scaledP2PSupplyBalance = morpho.scaledP2PSupplyBalance(dai, user);
        u.scaledP2PBorrowBalance = morpho.scaledP2PBorrowBalance(dai, user);
        u.scaledCollateralBalance = morpho.scaledCollateralBalance(dai, user);
        u.userCollaterals = morpho.userCollaterals(user);
        u.userBorrows = morpho.userBorrows(user);
    }

    function _assertStorageEq(StorageToCheck memory s1, StorageToCheck memory s2) internal {
        assertEq(s1.owner, s2.owner, "owner");
        assertEq(s1.pool, s2.pool, "pool");
        assertEq(s1.addressesProvider, s2.addressesProvider, "addressesProvider");
        assertEq(s1.domainSeparator, s2.domainSeparator, "domainSeparator");
        assertEq(s1.eModeCategoryId, s2.eModeCategoryId, "eModeCategoryId");

        assertEq(
            s1.market.indexes.supply.poolIndex, s2.market.indexes.supply.poolIndex, "market.indexes.supply.poolIndex"
        );
        assertEq(s1.market.indexes.supply.p2pIndex, s2.market.indexes.supply.p2pIndex, "market.indexes.supply.p2pIndex");
        assertEq(
            s1.market.indexes.borrow.poolIndex, s2.market.indexes.borrow.poolIndex, "market.indexes.borrow.poolIndex"
        );
        assertEq(s1.market.indexes.borrow.p2pIndex, s2.market.indexes.borrow.p2pIndex, "market.indexes.borrow.p2pIndex");
        assertEq(
            s1.market.deltas.supply.scaledDelta, s2.market.deltas.supply.scaledDelta, "market.deltas.supply.scaledDelta"
        );
        assertEq(
            s1.market.deltas.supply.scaledP2PTotal,
            s2.market.deltas.supply.scaledP2PTotal,
            "market.deltas.supply.scaledP2PTotal"
        );
        assertEq(
            s1.market.deltas.borrow.scaledDelta, s2.market.deltas.borrow.scaledDelta, "market.deltas.borrow.scaledDelta"
        );
        assertEq(
            s1.market.deltas.borrow.scaledP2PTotal,
            s2.market.deltas.borrow.scaledP2PTotal,
            "market.deltas.borrow.scaledP2PTotal"
        );
        assertEq(s1.market.underlying, s2.market.underlying, "market.underlying");
        assertEq(
            s1.market.pauseStatuses.isP2PDisabled,
            s2.market.pauseStatuses.isP2PDisabled,
            "market.pauseStatuses.isP2PDisabled"
        );
        assertEq(
            s1.market.pauseStatuses.isSupplyPaused,
            s2.market.pauseStatuses.isSupplyPaused,
            "market.pauseStatuses.isSupplyPaused"
        );
        assertEq(
            s1.market.pauseStatuses.isSupplyCollateralPaused,
            s2.market.pauseStatuses.isSupplyCollateralPaused,
            "market.pauseStatuses.isSupplyCollateralPaused"
        );
        assertEq(
            s1.market.pauseStatuses.isBorrowPaused,
            s2.market.pauseStatuses.isBorrowPaused,
            "market.pauseStatuses.isBorrowPaused"
        );
        assertEq(
            s1.market.pauseStatuses.isWithdrawPaused,
            s2.market.pauseStatuses.isWithdrawPaused,
            "market.pauseStatuses.isWithdrawPaused"
        );
        assertEq(
            s1.market.pauseStatuses.isWithdrawCollateralPaused,
            s2.market.pauseStatuses.isWithdrawCollateralPaused,
            "market.pauseStatuses.isWithdrawCollateralPaused"
        );
        assertEq(
            s1.market.pauseStatuses.isRepayPaused,
            s2.market.pauseStatuses.isRepayPaused,
            "market.pauseStatuses.isRepayPaused"
        );
        assertEq(
            s1.market.pauseStatuses.isLiquidateCollateralPaused,
            s2.market.pauseStatuses.isLiquidateCollateralPaused,
            "market.pauseStatuses.isLiquidateCollateralPaused"
        );
        assertEq(
            s1.market.pauseStatuses.isLiquidateBorrowPaused,
            s2.market.pauseStatuses.isLiquidateBorrowPaused,
            "market.pauseStatuses.isLiquidateBorrowPaused"
        );
        assertEq(
            s1.market.pauseStatuses.isDeprecated,
            s2.market.pauseStatuses.isDeprecated,
            "market.pauseStatuses.isDeprecated"
        );
        assertEq(s1.market.variableDebtToken, s2.market.variableDebtToken, "market.variableDebtToken");
        assertEq(s1.market.lastUpdateTimestamp, s2.market.lastUpdateTimestamp, "market.lastUpdateTimestamp");
        assertEq(s1.market.reserveFactor, s2.market.reserveFactor, "market.reserveFactor");
        assertEq(s1.market.p2pIndexCursor, s2.market.p2pIndexCursor, "market.p2pIndexCursor");
        assertEq(s1.market.aToken, s2.market.aToken, "market.aToken");
        assertEq(s1.market.stableDebtToken, s2.market.stableDebtToken, "market.stableDebtToken");
        assertEq(s1.market.idleSupply, s2.market.idleSupply, "market.idleSupply");

        for (uint256 i; i < s1.marketsCreated.length; i++) {
            assertEq(s1.marketsCreated[i], s2.marketsCreated[i], string.concat("marketsCreated", i.toString()));
        }
        assertEq(s1.defaultIterations.repay, s2.defaultIterations.repay, "defaultIterations.repay");
        assertEq(s1.defaultIterations.withdraw, s2.defaultIterations.withdraw, "defaultIterations.withdraw");
        assertEq(s1.rewardsManager, s2.rewardsManager, "rewardsManager");
        assertEq(s1.treasuryVault, s2.treasuryVault, "treasuryVault");
        assertEq(s1.isClaimRewardsPaused, s2.isClaimRewardsPaused, "isClaimRewardsPaused");

        _assertUserStorageEq(s1.supplier1, s2.supplier1);
        _assertUserStorageEq(s1.supplier2, s2.supplier2);
        _assertUserStorageEq(s1.borrower1, s2.borrower1);
        _assertUserStorageEq(s1.borrower2, s2.borrower2);
    }

    function _assertUserStorageEq(UserStorageToCheck memory u1, UserStorageToCheck memory u2) internal {
        assertEq(u1.scaledPoolSupplyBalance, u2.scaledPoolSupplyBalance, "scaledPoolSupplyBalance");
        assertEq(u1.scaledPoolBorrowBalance, u2.scaledPoolBorrowBalance, "scaledPoolBorrowBalance");
        assertEq(u1.scaledP2PSupplyBalance, u2.scaledP2PSupplyBalance, "scaledP2PSupplyBalance");
        assertEq(u1.scaledP2PBorrowBalance, u2.scaledP2PBorrowBalance, "scaledP2PBorrowBalance");
        assertEq(u1.scaledCollateralBalance, u2.scaledCollateralBalance, "scaledCollateralBalance");
        for (uint256 i; i < u1.userCollaterals.length; i++) {
            assertEq(u1.userCollaterals[i], u2.userCollaterals[i], string.concat("userCollaterals", i.toString()));
        }
        for (uint256 i; i < u1.userBorrows.length; i++) {
            assertEq(u1.userBorrows[i], u2.userBorrows[i], string.concat("userBorrows", i.toString()));
        }
    }
}
