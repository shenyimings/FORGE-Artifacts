// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {Deployment} from "../helpers/Deployment.MainnetFork.sol";
import {Vault} from "../../contracts/Vault.sol";
import "../../contracts/utils/PerpOwnable.sol";

// interfaces
import {IPerpetual} from "../../contracts/interfaces/IPerpetual.sol";
import {IClearingHouse} from "../../contracts/interfaces/IClearingHouse.sol";
import {IVault} from "../../contracts/interfaces/IVault.sol";
import {IOracle} from "../../contracts/interfaces/IOracle.sol";
import {IInsurance} from "../../contracts/interfaces/IInsurance.sol";
import {IVBase} from "../../contracts/interfaces/IVBase.sol";
import {AggregatorV3Interface} from "../../lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// libraries
import {LibPerpetual} from "../../contracts/lib/LibPerpetual.sol";
import "../../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "../../contracts/lib/LibMath.sol";

contract Governance is Deployment {
    // events
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event MarketAdded(IPerpetual indexed perpetual, uint256 listedIdx, uint256 numPerpetuals);
    event MarketRemoved(IPerpetual indexed perpetual, uint256 delistedIdx, uint256 numPerpetuals);
    event OracleChanged(IOracle newOracle);
    event HeartBeatUpdated(uint256 newHeartBeat);
    event SequencerUptimeFeedUpdated(AggregatorV3Interface newSequencerUptimeFeed);
    event GracePeriodUpdated(uint256 newGracePeriod);
    event TradingExpansionPauseToggled(address admin, bool toPause);
    event Paused(address account);
    event Unpaused(address account);
    event DustSold(uint256 indexed idx, int256 profit, int256 tradingFeesPayed);
    event ClearingHouseParametersChanged(
        int256 newMinMargin,
        int256 newMinMarginAtCreation,
        uint256 newMinPositiveOpenNotional,
        uint256 newLiquidationReward,
        uint256 newInsuranceRatio,
        uint256 newLiquidationRewardInsuranceShare,
        uint256 newLiquidationDiscount,
        uint256 nonUACollSeizureDiscount,
        int256 uaDebtSeizureThreshold
    );
    event PerpetualParametersChanged(
        uint256 newRiskWeight,
        uint256 newMaxLiquidityProvided,
        uint256 newTwapFrequency,
        int256 newSensitivity,
        uint256 newMaxBlockTradeAmount,
        int256 newInsuranceFee,
        int256 newLpDebtCoef,
        uint256 lockPeriod
    );

    // libraries
    using LibMath for uint256;
    using LibMath for int256;

    // addresses
    address user = address(123);
    address lp = address(456);

    // roles
    bytes32 public GOVERNANCE;
    bytes32 public EMERGENCY_ADMIN;

    function setUp() public virtual override {
        super.setUp();

        GOVERNANCE = clearingHouse.GOVERNANCE();
        EMERGENCY_ADMIN = clearingHouse.EMERGENCY_ADMIN();
    }

    function _expectOnlyGovernanceRevert(address addr) internal {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(addr),
                " is missing role ",
                Strings.toHexString(uint256(GOVERNANCE), 32)
            )
        );
    }

    function _expectOnlyAdminRevert(address addr) internal {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(addr),
                " is missing role ",
                Strings.toHexString(uint256(EMERGENCY_ADMIN), 32)
            )
        );
    }

    function _dealAndApprove(address addr, uint256 quoteAmount) internal {
        deal(address(ua), addr, quoteAmount);
        vm.startPrank(addr);
        ua.approve(address(vault), quoteAmount);
        vm.stopPrank();
    }

    function _dealAndProvideLiquidity(address addr, uint256 quoteAmount, uint256 baseAmount) internal {
        _dealAndApprove(addr, quoteAmount);

        vm.startPrank(addr);
        clearingHouse.deposit(quoteAmount, ua);

        clearingHouse.provideLiquidity(0, [quoteAmount / 3, baseAmount / 3], 0);
        vm.stopPrank();
    }

    // IncreAccessControl

    function test_TransferRolesFromDeployer() public {
        // grant GOVERNANCE role to user
        vm.expectEmit(true, true, true, false);
        emit RoleGranted(GOVERNANCE, user, address(this));
        clearingHouse.grantRole(GOVERNANCE, user);
        assertTrue(clearingHouse.isGovernor(user));

        // transfer EMERGENCY_ADMIN role to user
        vm.expectEmit(true, true, true, false);
        emit RoleGranted(EMERGENCY_ADMIN, user, address(this));
        clearingHouse.grantRole(EMERGENCY_ADMIN, user);
        assertTrue(clearingHouse.isEmergencyAdmin(user));

        // renounce EMERGENCY_ADMIN role
        vm.expectEmit(true, true, true, false);
        emit RoleRevoked(EMERGENCY_ADMIN, user, user);
        vm.startPrank(user);
        clearingHouse.renounceRole(EMERGENCY_ADMIN, user);
        vm.stopPrank();
        assertTrue(!clearingHouse.isEmergencyAdmin(user));
    }

    // Allowlist / Delist markets

    function test_FailsToAllowlistMarket() public {
        _expectOnlyGovernanceRevert(user);
        vm.startPrank(user);
        clearingHouse.allowListPerpetual(IPerpetual(address(1)));
        vm.stopPrank();
    }

    function test_FailsDeployerAllowlistDuplicateMarket() public {
        uint256 initialNumMarkets = clearingHouse.getNumMarkets();
        vm.expectRevert(IClearingHouse.ClearingHouse_PerpetualMarketAlreadyAssigned.selector);
        clearingHouse.allowListPerpetual(perpetual);
        assertEq(clearingHouse.getNumMarkets(), initialNumMarkets);
    }

    function test_FailsAllowlistMarketZeroAddress() public {
        vm.expectRevert(IClearingHouse.ClearingHouse_ZeroAddress.selector);
        clearingHouse.allowListPerpetual(IPerpetual(address(0)));
    }

    function test_DeployerCanAllowlistMarket() public {
        uint256 initialNumMarkets = clearingHouse.getNumMarkets();

        vm.expectEmit(true, true, true, false);
        emit MarketAdded(IPerpetual(address(1)), 1, 1);
        clearingHouse.allowListPerpetual(IPerpetual(address(1)));
        assertEq(clearingHouse.getNumMarkets(), initialNumMarkets + 1);
        assertEq(address(clearingHouse.perpetuals(1)), address(1));
    }

    function test_FailsUserDelistAttempt() public {
        clearingHouse.allowListPerpetual(IPerpetual(address(1)));
        _expectOnlyGovernanceRevert(user);
        vm.startPrank(user);
        clearingHouse.delistPerpetual(IPerpetual(address(1)));
        vm.stopPrank();
    }

    function test_FailsDelistNonExistentMarket() public {
        vm.expectRevert(IClearingHouse.ClearingHouse_MarketDoesNotExist.selector);
        clearingHouse.delistPerpetual(IPerpetual(address(1)));
    }

    function test_DeployerCanDelistMarket() public {
        clearingHouse.allowListPerpetual(IPerpetual(address(1)));

        assertEq(clearingHouse.id(0), 0);
        assertEq(clearingHouse.id(1), 1);
        assertEq(clearingHouse.getNumMarkets(), 2);

        vm.expectEmit(true, true, true, false);
        emit MarketRemoved(IPerpetual(address(1)), 1, 1);
        clearingHouse.delistPerpetual(IPerpetual(address(1)));

        assertEq(clearingHouse.getNumMarkets(), 1);
        assertEq(clearingHouse.id(0), 0);
    }

    function test_DeployerCanDelistMultipleMarkets() public {
        clearingHouse.allowListPerpetual(IPerpetual(address(1)));
        clearingHouse.allowListPerpetual(IPerpetual(address(2)));
        clearingHouse.allowListPerpetual(IPerpetual(address(3)));

        assertEq(clearingHouse.getNumMarkets(), 4);
        assertEq(clearingHouse.id(0), 0);
        assertEq(clearingHouse.id(1), 1);
        assertEq(clearingHouse.id(2), 2);
        assertEq(clearingHouse.id(3), 3);

        vm.expectEmit(true, true, true, false);
        emit MarketRemoved(IPerpetual(address(1)), 1, 3);
        clearingHouse.delistPerpetual(IPerpetual(address(1)));

        assertEq(clearingHouse.getNumMarkets(), 3);
        assertEq(clearingHouse.id(0), 0);
        assertEq(clearingHouse.id(1), 3);
        assertEq(clearingHouse.id(2), 2);

        clearingHouse.allowListPerpetual(IPerpetual(address(4)));

        assertEq(clearingHouse.getNumMarkets(), 4);
        assertEq(clearingHouse.id(0), 0);
        assertEq(clearingHouse.id(1), 3);
        assertEq(clearingHouse.id(2), 2);
        assertEq(clearingHouse.id(3), 4);

        vm.expectEmit(true, true, true, false);
        emit MarketRemoved(IPerpetual(address(3)), 3, 3);
        clearingHouse.delistPerpetual(IPerpetual(address(3)));

        assertEq(clearingHouse.getNumMarkets(), 3);
        assertEq(clearingHouse.id(0), 0);
        assertEq(clearingHouse.id(1), 4);
        assertEq(clearingHouse.id(2), 2);
    }

    // Changes to Vault Contract

    function test_FailsToSetVaultClearingHouseAfterDeploy() public {
        vm.expectRevert(IVault.Vault_ClearingHouseAlreadySet.selector);
        vault.setClearingHouse(clearingHouse);
    }

    function test_FailsToSetVaultClearingHouseToZeroAddress() public {
        Vault testVault = new Vault(ua);
        vm.expectRevert(IVault.Vault_ClearingHouseZeroAddress.selector);
        testVault.setClearingHouse(IClearingHouse(address(0)));
    }

    function test_FailsToSetVaultInsuranceAfterDeploy() public {
        vm.expectRevert(IVault.Vault_InsuranceAlreadySet.selector);
        vault.setInsurance(insurance);
    }

    function test_FailsToSetVaultInsuranceToZeroAddress() public {
        Vault testVault = new Vault(ua);
        vm.expectRevert(IVault.Vault_InsuranceZeroAddress.selector);
        testVault.setInsurance(IInsurance(address(0)));
    }

    function test_FailsToChangeOracleWithoutGovernorRole() public {
        _expectOnlyGovernanceRevert(user);
        vm.startPrank(user);
        vault.setOracle(IOracle(address(1)));
        vm.stopPrank();
    }

    function test_FailsToSetOracleZeroAddress() public {
        vm.expectRevert(IVault.Vault_OracleZeroAddress.selector);
        vault.setOracle(IOracle(address(0)));
    }

    function test_GovernorCanSetOracle() public {
        vm.expectEmit(true, true, true, false);
        emit OracleChanged(oracle);
        vault.setOracle(oracle);
        assertEq(address(vault.oracle()), address(oracle));
    }

    // Change Insurance Contract

    function test_FailsToSetInsuranceClearingHouseToZeroAddress() public {
        vm.expectRevert(IInsurance.Insurance_ClearingHouseZeroAddress.selector);
        insurance.setClearingHouse(IClearingHouse(address(0)));
    }

    function test_FailsToSetInsuranceClearingHouseAfterDeploy() public {
        vm.expectRevert(IInsurance.Insurance_ClearingHouseAlreadySet.selector);
        insurance.setClearingHouse(clearingHouse);
    }

    // Changes to vBase contract

    function testFuzz_FailsToSetVBaseHeartBeatWithoutGovernorRole(uint256 newHeartBeat) public {
        vm.assume(newHeartBeat != 0);

        _expectOnlyGovernanceRevert(user);
        vm.startPrank(user);
        vBase.setHeartBeat(newHeartBeat);
        vm.stopPrank();
    }

    function test_FailsToSetVBaseHeartBeatZero() public {
        vm.expectRevert(IVBase.VBase_IncorrectHeartBeat.selector);
        vBase.setHeartBeat(0);
    }

    function testFuzz_CanChangeVBaseHeartBeat(uint256 newHeartBeat) public {
        vm.assume(newHeartBeat != 0);

        vm.expectEmit(true, true, true, false);
        emit HeartBeatUpdated(newHeartBeat);
        vBase.setHeartBeat(newHeartBeat);
        assertEq(vBase.heartBeat(), newHeartBeat);
    }

    function test_FailsToSetVBaseSequencerWithoutGovernorRole() public {
        _expectOnlyGovernanceRevert(user);
        vm.startPrank(user);
        vBase.setSequencerUptimeFeed(AggregatorV3Interface(address(1)));
        vm.stopPrank();
    }

    function test_FailsToSetVBaseSequencerZeroAddress() public {
        vm.expectRevert(IVBase.VBase_SequencerUptimeFeedZeroAddress.selector);
        vBase.setSequencerUptimeFeed(AggregatorV3Interface(address(0)));
    }

    function test_CanChangeSequencerAddress() public {
        vm.expectEmit(true, true, true, false);
        emit SequencerUptimeFeedUpdated(AggregatorV3Interface(address(1)));
        vBase.setSequencerUptimeFeed(AggregatorV3Interface(address(1)));
        assertEq(address(vBase.sequencerUptimeFeed()), address(1));
    }

    function test_FailsToSetNewGracePeriodWithoutGovernorRole(uint256 newGracePeriod) public {
        vm.assume(newGracePeriod >= 60 && newGracePeriod <= 3600);
        _expectOnlyGovernanceRevert(user);
        vm.startPrank(user);
        vBase.setGracePeriod(newGracePeriod);
        vm.stopPrank();
    }

    function test_FailsToSetNewGracePeriodOutsideOfBounds(uint256 newGracePeriod) public {
        vm.assume(newGracePeriod < 60 || newGracePeriod > 3600);
        vm.expectRevert(IVBase.VBase_IncorrectGracePeriod.selector);
        vBase.setGracePeriod(newGracePeriod);
    }

    function test_CanChangeGracePeriod(uint256 newGracePeriod) public {
        vm.assume(newGracePeriod >= 60 && newGracePeriod <= 3600);
        vm.expectEmit(true, true, true, false);
        emit GracePeriodUpdated(newGracePeriod);
        vBase.setGracePeriod(newGracePeriod);
        assertEq(vBase.gracePeriod(), newGracePeriod);
    }

    // Pause Trading Expansion Operations

    function test_FailsToPauseTradingExpansionWithoutAdminRole() public {
        _expectOnlyAdminRevert(user);
        vm.startPrank(user);
        perpetual.toggleTradingExpansionPause(false);
        vm.stopPrank();
    }

    function test_CanPauseTradingExpansion() public {
        vm.expectEmit(true, true, true, false);
        emit TradingExpansionPauseToggled(address(this), false);
        perpetual.toggleTradingExpansionPause(false);
        assertTrue(!perpetual.isTradingExpansionAllowed());

        vm.expectEmit(true, true, true, false);
        emit TradingExpansionPauseToggled(address(this), true);
        perpetual.toggleTradingExpansionPause(true);
        assertTrue(perpetual.isTradingExpansionAllowed());
    }

    function test_FailsToCreateOrExtendPositionsWhilePaused(uint256 quoteAmount) public {
        quoteAmount = bound(quoteAmount, 100 ether, 5000 ether);
        uint256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());

        // provide liquidity and deal user
        _dealAndProvideLiquidity(lp, quoteAmount * 5, baseAmount * 5);
        _dealAndApprove(user, quoteAmount);

        // PAUSE
        perpetual.toggleTradingExpansionPause(false);

        vm.expectRevert(IPerpetual.Perpetual_TradingExpansionPaused.selector);
        vm.startPrank(user);
        clearingHouse.changePosition(0, 1, 1, LibPerpetual.Side.Long);
        vm.stopPrank();

        vm.expectRevert(IPerpetual.Perpetual_TradingExpansionPaused.selector);
        vm.startPrank(user);
        clearingHouse.extendPositionWithCollateral(0, user, quoteAmount, ua, 1, LibPerpetual.Side.Long, 0);
        vm.stopPrank();

        // UNPAUSE
        perpetual.toggleTradingExpansionPause(true);

        // open position
        vm.startPrank(user);
        clearingHouse.extendPositionWithCollateral(0, user, quoteAmount, ua, quoteAmount, LibPerpetual.Side.Long, 0);
        vm.stopPrank();

        // PAUSE
        perpetual.toggleTradingExpansionPause(false);

        uint256 proposedAmount = viewer.getTraderProposedAmount(0, user, 1 ether, 10, 0);
        uint256 indexPrice = perpetual.indexPrice().toUint256();

        // reversing position should fail
        vm.expectRevert(IPerpetual.Perpetual_TradingExpansionPaused.selector);
        vm.startPrank(user);
        clearingHouse.openReversePosition(
            0, proposedAmount, 0, (quoteAmount * 2).wadDiv(indexPrice), 0, LibPerpetual.Side.Short
        );
        vm.stopPrank();

        // but reducing position should succeed
        vm.startPrank(user);
        clearingHouse.changePosition(0, (quoteAmount / 3).wadDiv(indexPrice), 0, LibPerpetual.Side.Short);
        vm.stopPrank();

        // and closing position should succeed
        proposedAmount = viewer.getTraderProposedAmount(0, user, 1 ether, 10, 0);
        vm.startPrank(user);
        clearingHouse.closePositionWithdrawCollateral(0, proposedAmount, 0, ua);
        vm.stopPrank();
    }

    // Pause ClearingHouse

    function test_FailsToPauseWithoutAdminRole() public {
        _expectOnlyAdminRevert(user);
        vm.startPrank(user);
        clearingHouse.pause();
        vm.stopPrank();
    }

    function test_CanPauseClearingHouse() public {
        vm.expectEmit(true, true, true, false);
        emit Paused(address(this));
        clearingHouse.pause();
        assertTrue(clearingHouse.paused());
    }

    function test_FailsToUnpauseWithoutAdminRole() public {
        clearingHouse.pause();
        _expectOnlyAdminRevert(user);
        vm.startPrank(user);
        clearingHouse.unpause();
        vm.stopPrank();
    }

    function test_CanUnpauseClearingHouse() public {
        clearingHouse.pause();
        vm.expectEmit(true, true, true, false);
        emit Unpaused(address(this));
        clearingHouse.unpause();
        assertTrue(!clearingHouse.paused());
    }

    function test_FailsToDepositWithdrawTradeLiquidateOrManageLiquidityWhenClearingHousePaused() public {
        clearingHouse.pause();

        // deposit
        vm.expectRevert("Pausable: paused");
        vm.startPrank(user);
        clearingHouse.deposit(1 ether, ua);
        vm.stopPrank();

        // withdraw
        vm.expectRevert("Pausable: paused");
        vm.startPrank(user);
        clearingHouse.withdraw(1 ether, ua);
        vm.stopPrank();

        // trade
        vm.expectRevert("Pausable: paused");
        vm.startPrank(user);
        clearingHouse.changePosition(0, 1 ether, 1, LibPerpetual.Side.Long);
        vm.stopPrank();

        // deposit & trade
        vm.expectRevert("Pausable: paused");
        vm.startPrank(user);
        clearingHouse.extendPositionWithCollateral(0, user, 1 ether, ua, 1 ether, LibPerpetual.Side.Long, 0);
        vm.stopPrank();

        // liquidate lp
        vm.expectRevert("Pausable: paused");
        vm.startPrank(user);
        clearingHouse.liquidateLp(0, user, [uint256(0), uint256(0)], 1, 0);
        vm.stopPrank();

        // liquidate trader
        vm.expectRevert("Pausable: paused");
        vm.startPrank(user);
        clearingHouse.liquidateTrader(0, user, 1, 0);
        vm.stopPrank();

        // provide liquidity
        vm.expectRevert("Pausable: paused");
        vm.startPrank(user);
        clearingHouse.provideLiquidity(0, [uint256(1), uint256(1)], 0);
        vm.stopPrank();

        // remove liquidity
        vm.expectRevert("Pausable: paused");
        vm.startPrank(user);
        clearingHouse.removeLiquidity(0, 1, [uint256(0), uint256(0)], 0, 0);
        vm.stopPrank();
    }

    // Pause Perpetual

    function test_FailsToPausePerpetualWithoutAdminRole() public {
        _expectOnlyAdminRevert(user);
        vm.startPrank(user);
        perpetual.pause();
        vm.stopPrank();
    }

    function test_CanPausePerpetual() public {
        vm.expectEmit(true, true, true, false);
        emit Paused(address(this));
        perpetual.pause();
        assertTrue(perpetual.paused());
    }

    function test_FailsToUnpausePerpetualWithoutAdminRole() public {
        perpetual.pause();
        _expectOnlyAdminRevert(user);
        vm.startPrank(user);
        perpetual.unpause();
        vm.stopPrank();
    }

    function test_CanUnpausePerpetual() public {
        perpetual.pause();
        vm.expectEmit(true, true, true, false);
        emit Unpaused(address(this));
        perpetual.unpause();
        assertTrue(!perpetual.paused());
    }

    function test_FailsToTradeOrManageLiquidityWhenPerpetualPaused() public {
        perpetual.pause();
        _dealAndApprove(user, 10 ether);

        // trade
        vm.expectRevert("Pausable: paused");
        vm.startPrank(user);
        perpetual.changePosition(user, 1 ether, 0, LibPerpetual.Side.Long, false);
        vm.stopPrank();

        // provide liquidity
        vm.expectRevert("Pausable: paused");
        vm.startPrank(user);
        perpetual.provideLiquidity(user, [uint256(0), uint256(0)], 0);
        vm.stopPrank();

        // remove liquidity
        vm.expectRevert("Pausable: paused");
        vm.startPrank(user);
        perpetual.removeLiquidity(user, 0, [uint256(0), uint256(0)], 0, 0, false);
        vm.stopPrank();
    }

    // Pause UA

    function test_FailsToPauseUAWithoutAdminRole() public {
        _expectOnlyAdminRevert(user);
        vm.startPrank(user);
        ua.pause();
        vm.stopPrank();
    }

    function test_CanPauseUA() public {
        vm.expectEmit(true, true, true, false);
        emit Paused(address(this));
        ua.pause();
        assertTrue(ua.paused());
    }

    function test_FailsToUnpauseUAWithoutAdminRole() public {
        ua.pause();
        _expectOnlyAdminRevert(user);
        vm.startPrank(user);
        ua.unpause();
        vm.stopPrank();
    }

    function test_CanUnpauseUA() public {
        ua.pause();
        vm.expectEmit(true, true, true, false);
        emit Unpaused(address(this));
        ua.unpause();
        assertTrue(!ua.paused());
    }

    function test_FailsToMintOrWithdrawWhenUAIsPaused() public {
        ua.pause();

        // mint
        vm.expectRevert("Pausable: paused");
        vm.startPrank(user);
        ua.mintWithReserve(usdc, 0);
        vm.stopPrank();

        // withdraw
        vm.expectRevert("Pausable: paused");
        vm.startPrank(user);
        ua.withdraw(usdc, 0);
        vm.stopPrank();
    }

    // Dust

    function _sellDust(int256 quoteAmount, int256 baseAmount, int256 fundingRate, int256 liquidityAmount) internal {
        _dealAndProvideLiquidity(
            lp, liquidityAmount.toUint256(), liquidityAmount.wadDiv(perpetual.indexPrice()).toUint256()
        );
        int256 insuranceBalanceBefore = ua.balanceOf(address(insurance)).toInt256();

        // generate some dust
        perpetual.__TestPerpetual__setTraderPosition(
            address(clearingHouse), int128(quoteAmount), int128(baseAmount), int128(fundingRate)
        );

        // withdraw dust
        uint256 proposedAmount = viewer.getTraderProposedAmount(0, address(clearingHouse), 1 ether, 10, 0);

        uint8 sellIndex = baseAmount > 0 ? 1 : 0;
        uint8 buyIndex = sellIndex == 0 ? 1 : 0;
        uint256 dy = cryptoSwap.get_dy(sellIndex, buyIndex, proposedAmount);
        uint256 dy_ex_fees = curveCryptoViews.get_dy_no_fee_deduct(cryptoSwap, sellIndex, buyIndex, proposedAmount);
        int256 fee_perc = ((dy_ex_fees - dy).wadDiv(dy_ex_fees)).toInt256();
        int256 quoteProceeds = baseAmount > 0 ? dy_ex_fees.toInt256() : -(proposedAmount.toInt256());

        int256 expectedTradingFee = quoteProceeds.abs().wadMul(fee_perc);
        int256 expectedProfit = quoteProceeds - expectedTradingFee + quoteAmount;

        if (expectedProfit > 0) {
            vm.expectEmit(true, true, true, false);
            emit DustSold(0, expectedProfit, expectedTradingFee);
            clearingHouse.settleDust(0, proposedAmount, 0, LibPerpetual.Side.Short);
            assertEq(ua.balanceOf(address(insurance)), (insuranceBalanceBefore + expectedProfit).toUint256());
        } else {
            vm.expectRevert(IClearingHouse.ClearingHouse_NegativeDustProceeds.selector);
            clearingHouse.settleDust(0, proposedAmount, 0, LibPerpetual.Side.Long);
        }
    }

    function testFuzz_OwnerCanWithdrawWithProfit(int256 quoteAmount) public {
        quoteAmount = bound(quoteAmount, 100 ether, 500 ether);
        int256 fundingRate = perpetual.getGlobalPosition().cumFundingRate;
        int256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice());

        _sellDust(-1, baseAmount, fundingRate, quoteAmount * 100);
    }

    function testFuzz_OwnerCanWithdrawWithLoss(int256 quoteAmount) public {
        quoteAmount = bound(quoteAmount, 100 ether, 500 ether);
        int256 fundingRate = perpetual.getGlobalPosition().cumFundingRate;
        int256 baseAmount = -quoteAmount.wadDiv(perpetual.indexPrice());

        _sellDust(1, baseAmount, fundingRate, quoteAmount * 100);
    }

    // Change ClearingHouse Parameters

    function test_FailsToUpdateClearingHouseParamsWithoutGovernorRole() public {
        IClearingHouse.ClearingHouseParams memory params = IClearingHouse.ClearingHouseParams({
            minMargin: 0,
            minMarginAtCreation: 0,
            minPositiveOpenNotional: 0,
            liquidationReward: 0,
            insuranceRatio: 0,
            liquidationRewardInsuranceShare: 0,
            liquidationDiscount: 0,
            nonUACollSeizureDiscount: 0,
            uaDebtSeizureThreshold: 0
        });

        _expectOnlyGovernanceRevert(user);
        vm.startPrank(user);
        clearingHouse.setParameters(params);
        vm.stopPrank();
    }

    function testFuzz_CanUpdateClearingHouseParamsWithinBounds(
        int256 minMargin,
        int256 minMarginAtCreation,
        uint256 minPositiveOpenNotional,
        uint256 liquidationReward,
        uint256 insuranceRatio,
        uint256 liquidationRewardInsuranceShare,
        uint256 liquidationDiscount,
        uint256 nonUACollSeizureDiscount,
        int256 uaDebtSeizureThreshold
    ) public {
        minMargin = bound(minMargin, 2e16, 2e17);
        minMarginAtCreation = bound(minMarginAtCreation, minMargin + 1, 5e17);
        minPositiveOpenNotional = bound(minPositiveOpenNotional, 0, 1000 * 1e18);
        liquidationReward = bound(liquidationReward, 1e16, minMargin.toUint256() - 1);
        insuranceRatio = bound(insuranceRatio, 1e17, 5e17);
        liquidationRewardInsuranceShare = bound(liquidationRewardInsuranceShare, 0, 1e18);
        liquidationDiscount = bound(liquidationDiscount, 7e17, type(uint256).max);
        nonUACollSeizureDiscount = bound(nonUACollSeizureDiscount, 0, liquidationDiscount - 1e17);
        uaDebtSeizureThreshold = bound(uaDebtSeizureThreshold, 1e20, type(int256).max);

        IClearingHouse.ClearingHouseParams memory params = IClearingHouse.ClearingHouseParams({
            minMargin: minMargin,
            minMarginAtCreation: minMarginAtCreation,
            minPositiveOpenNotional: minPositiveOpenNotional,
            liquidationReward: liquidationReward,
            insuranceRatio: insuranceRatio,
            liquidationRewardInsuranceShare: liquidationRewardInsuranceShare,
            liquidationDiscount: liquidationDiscount,
            nonUACollSeizureDiscount: nonUACollSeizureDiscount,
            uaDebtSeizureThreshold: uaDebtSeizureThreshold
        });

        vm.expectEmit(true, true, true, false);
        emit ClearingHouseParametersChanged(
            minMargin,
            minMarginAtCreation,
            minPositiveOpenNotional,
            liquidationReward,
            insuranceRatio,
            liquidationRewardInsuranceShare,
            liquidationDiscount,
            nonUACollSeizureDiscount,
            uaDebtSeizureThreshold
        );
        clearingHouse.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidMinMargin(int256 minMargin) public {
        vm.assume(minMargin < 2e16 || minMargin > 2e17);

        IClearingHouse.ClearingHouseParams memory params = IClearingHouse.ClearingHouseParams({
            minMargin: minMargin,
            minMarginAtCreation: clearingHouse.minMarginAtCreation(),
            minPositiveOpenNotional: clearingHouse.minPositiveOpenNotional(),
            liquidationReward: clearingHouse.liquidationReward(),
            insuranceRatio: clearingHouse.insuranceRatio(),
            liquidationRewardInsuranceShare: clearingHouse.liquidationRewardInsuranceShare(),
            liquidationDiscount: clearingHouse.liquidationDiscount(),
            nonUACollSeizureDiscount: clearingHouse.nonUACollSeizureDiscount(),
            uaDebtSeizureThreshold: clearingHouse.uaDebtSeizureThreshold()
        });

        vm.expectRevert(IClearingHouse.ClearingHouse_InvalidMinMargin.selector);
        clearingHouse.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidMinMarginAtCreation(int256 minMargin, int256 minMarginAtCreation) public {
        minMargin = bound(minMargin, 2e16, 2e17);
        vm.assume(minMarginAtCreation <= minMargin || minMarginAtCreation > 5e17);

        IClearingHouse.ClearingHouseParams memory params = IClearingHouse.ClearingHouseParams({
            minMargin: minMargin,
            minMarginAtCreation: minMarginAtCreation,
            minPositiveOpenNotional: clearingHouse.minPositiveOpenNotional(),
            liquidationReward: clearingHouse.liquidationReward(),
            insuranceRatio: clearingHouse.insuranceRatio(),
            liquidationRewardInsuranceShare: clearingHouse.liquidationRewardInsuranceShare(),
            liquidationDiscount: clearingHouse.liquidationDiscount(),
            nonUACollSeizureDiscount: clearingHouse.nonUACollSeizureDiscount(),
            uaDebtSeizureThreshold: clearingHouse.uaDebtSeizureThreshold()
        });

        vm.expectRevert(IClearingHouse.ClearingHouse_InvalidMinMarginAtCreation.selector);
        clearingHouse.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidMinPositiveOpenNotional(uint256 minPositiveOpenNotional) public {
        minPositiveOpenNotional = bound(minPositiveOpenNotional, 1000 * 1e18 + 1, type(uint256).max);

        IClearingHouse.ClearingHouseParams memory params = IClearingHouse.ClearingHouseParams({
            minMargin: clearingHouse.minMargin(),
            minMarginAtCreation: clearingHouse.minMarginAtCreation(),
            minPositiveOpenNotional: minPositiveOpenNotional,
            liquidationReward: clearingHouse.liquidationReward(),
            insuranceRatio: clearingHouse.insuranceRatio(),
            liquidationRewardInsuranceShare: clearingHouse.liquidationRewardInsuranceShare(),
            liquidationDiscount: clearingHouse.liquidationDiscount(),
            nonUACollSeizureDiscount: clearingHouse.nonUACollSeizureDiscount(),
            uaDebtSeizureThreshold: clearingHouse.uaDebtSeizureThreshold()
        });

        vm.expectRevert(IClearingHouse.ClearingHouse_ExcessivePositiveOpenNotional.selector);
        clearingHouse.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidLiquidationReward(
        int256 minMargin,
        int256 minMarginAtCreation,
        uint256 liquidationReward
    ) public {
        minMargin = bound(minMargin, 2e16, 2e17);
        minMarginAtCreation = bound(minMarginAtCreation, minMargin + 1, 5e17);
        vm.assume(liquidationReward < 1e16 || liquidationReward >= minMargin.toUint256());

        IClearingHouse.ClearingHouseParams memory params = IClearingHouse.ClearingHouseParams({
            minMargin: minMargin,
            minMarginAtCreation: minMarginAtCreation,
            minPositiveOpenNotional: clearingHouse.minPositiveOpenNotional(),
            liquidationReward: liquidationReward,
            insuranceRatio: clearingHouse.insuranceRatio(),
            liquidationRewardInsuranceShare: clearingHouse.liquidationRewardInsuranceShare(),
            liquidationDiscount: clearingHouse.liquidationDiscount(),
            nonUACollSeizureDiscount: clearingHouse.nonUACollSeizureDiscount(),
            uaDebtSeizureThreshold: clearingHouse.uaDebtSeizureThreshold()
        });

        vm.expectRevert(IClearingHouse.ClearingHouse_InvalidLiquidationReward.selector);
        clearingHouse.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidInsuranceRatio(uint256 insuranceRatio) public {
        vm.assume(insuranceRatio < 1e17 || insuranceRatio > 5e17);

        IClearingHouse.ClearingHouseParams memory params = IClearingHouse.ClearingHouseParams({
            minMargin: clearingHouse.minMargin(),
            minMarginAtCreation: clearingHouse.minMarginAtCreation(),
            minPositiveOpenNotional: clearingHouse.minPositiveOpenNotional(),
            liquidationReward: clearingHouse.liquidationReward(),
            insuranceRatio: insuranceRatio,
            liquidationRewardInsuranceShare: clearingHouse.liquidationRewardInsuranceShare(),
            liquidationDiscount: clearingHouse.liquidationDiscount(),
            nonUACollSeizureDiscount: clearingHouse.nonUACollSeizureDiscount(),
            uaDebtSeizureThreshold: clearingHouse.uaDebtSeizureThreshold()
        });

        vm.expectRevert(IClearingHouse.ClearingHouse_InvalidInsuranceRatio.selector);
        clearingHouse.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidLiquidationRewardInsuranceShare(uint256 liquidationRewardInsuranceShare)
        public
    {
        liquidationRewardInsuranceShare = bound(liquidationRewardInsuranceShare, 1e18 + 1, type(uint256).max);

        IClearingHouse.ClearingHouseParams memory params = IClearingHouse.ClearingHouseParams({
            minMargin: clearingHouse.minMargin(),
            minMarginAtCreation: clearingHouse.minMarginAtCreation(),
            minPositiveOpenNotional: clearingHouse.minPositiveOpenNotional(),
            liquidationReward: clearingHouse.liquidationReward(),
            insuranceRatio: clearingHouse.insuranceRatio(),
            liquidationRewardInsuranceShare: liquidationRewardInsuranceShare,
            liquidationDiscount: clearingHouse.liquidationDiscount(),
            nonUACollSeizureDiscount: clearingHouse.nonUACollSeizureDiscount(),
            uaDebtSeizureThreshold: clearingHouse.uaDebtSeizureThreshold()
        });

        vm.expectRevert(IClearingHouse.ClearingHouse_ExcessiveLiquidationRewardInsuranceShare.selector);
        clearingHouse.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidLiquidationDiscount(
        uint256 liquidationDiscount,
        uint256 nonUACollSeizureDiscount
    ) public {
        liquidationDiscount = bound(liquidationDiscount, 1e17, 7e17 - 1);
        nonUACollSeizureDiscount = bound(nonUACollSeizureDiscount, 0, liquidationDiscount - 1e17);

        IClearingHouse.ClearingHouseParams memory params = IClearingHouse.ClearingHouseParams({
            minMargin: clearingHouse.minMargin(),
            minMarginAtCreation: clearingHouse.minMarginAtCreation(),
            minPositiveOpenNotional: clearingHouse.minPositiveOpenNotional(),
            liquidationReward: clearingHouse.liquidationReward(),
            insuranceRatio: clearingHouse.insuranceRatio(),
            liquidationRewardInsuranceShare: clearingHouse.liquidationRewardInsuranceShare(),
            liquidationDiscount: liquidationDiscount,
            nonUACollSeizureDiscount: nonUACollSeizureDiscount,
            uaDebtSeizureThreshold: clearingHouse.uaDebtSeizureThreshold()
        });

        vm.expectRevert(IClearingHouse.ClearingHouse_ExcessiveLiquidationDiscount.selector);
        clearingHouse.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidNonUACollSeizureDiscount(
        uint256 liquidationDiscount,
        uint256 nonUACollSeizureDiscount
    ) public {
        liquidationDiscount = bound(liquidationDiscount, 7e17, type(uint256).max - 1);
        nonUACollSeizureDiscount =
            bound(nonUACollSeizureDiscount, liquidationDiscount - 1e17 + 1, type(uint256).max - 1e17);

        IClearingHouse.ClearingHouseParams memory params = IClearingHouse.ClearingHouseParams({
            minMargin: clearingHouse.minMargin(),
            minMarginAtCreation: clearingHouse.minMarginAtCreation(),
            minPositiveOpenNotional: clearingHouse.minPositiveOpenNotional(),
            liquidationReward: clearingHouse.liquidationReward(),
            insuranceRatio: clearingHouse.insuranceRatio(),
            liquidationRewardInsuranceShare: clearingHouse.liquidationRewardInsuranceShare(),
            liquidationDiscount: liquidationDiscount,
            nonUACollSeizureDiscount: nonUACollSeizureDiscount,
            uaDebtSeizureThreshold: clearingHouse.uaDebtSeizureThreshold()
        });

        vm.expectRevert(
            IClearingHouse.ClearingHouse_InsufficientDiffBtwLiquidationDiscountAndNonUACollSeizureDiscount.selector
        );
        clearingHouse.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidUADebtSeizureThreshold(int256 uaDebtSeizureThreshold) public {
        uaDebtSeizureThreshold = bound(uaDebtSeizureThreshold, 0, 1e20 - 1);

        IClearingHouse.ClearingHouseParams memory params = IClearingHouse.ClearingHouseParams({
            minMargin: clearingHouse.minMargin(),
            minMarginAtCreation: clearingHouse.minMarginAtCreation(),
            minPositiveOpenNotional: clearingHouse.minPositiveOpenNotional(),
            liquidationReward: clearingHouse.liquidationReward(),
            insuranceRatio: clearingHouse.insuranceRatio(),
            liquidationRewardInsuranceShare: clearingHouse.liquidationRewardInsuranceShare(),
            liquidationDiscount: clearingHouse.liquidationDiscount(),
            nonUACollSeizureDiscount: clearingHouse.nonUACollSeizureDiscount(),
            uaDebtSeizureThreshold: uaDebtSeizureThreshold
        });

        vm.expectRevert(IClearingHouse.ClearingHouse_InsufficientUaDebtSeizureThreshold.selector);
        clearingHouse.setParameters(params);
    }

    // Change Perpetual Parameters

    function test_FailsToUpdatePerpetualParamsWithoutGovernorRole() public {
        IPerpetual.PerpetualParams memory params = IPerpetual.PerpetualParams({
            riskWeight: perpetual.riskWeight(),
            maxLiquidityProvided: perpetual.maxLiquidityProvided(),
            twapFrequency: perpetual.twapFrequency(),
            sensitivity: perpetual.sensitivity(),
            maxBlockTradeAmount: perpetual.maxBlockTradeAmount(),
            insuranceFee: perpetual.insuranceFee(),
            lpDebtCoef: perpetual.lpDebtCoef(),
            lockPeriod: perpetual.lockPeriod()
        });

        _expectOnlyGovernanceRevert(user);
        vm.startPrank(user);
        perpetual.setParameters(params);
        vm.stopPrank();
    }

    function testFuzz_CanUpdateClearingHouseParamsWithinBounds(
        uint256 riskWeight,
        uint256 maxLiquidityProvided,
        uint256 twapFrequency,
        int256 sensitivity,
        uint256 maxBlockTradeAmount,
        int256 insuranceFee,
        int256 lpDebtCoef,
        uint256 lockPeriod
    ) public {
        sensitivity = bound(sensitivity, 2e17, 10e18);
        insuranceFee = bound(insuranceFee, 1e14, 1e16);
        lpDebtCoef = bound(lpDebtCoef, 1e18, 20e18);
        maxBlockTradeAmount = bound(maxBlockTradeAmount, 100e18, type(uint256).max);
        twapFrequency = bound(twapFrequency, 1 minutes, 60 minutes);
        lockPeriod = bound(lockPeriod, 10 minutes, 30 minutes);
        riskWeight = bound(riskWeight, 1e18, 50e18);

        IPerpetual.PerpetualParams memory params = IPerpetual.PerpetualParams({
            riskWeight: riskWeight,
            maxLiquidityProvided: maxLiquidityProvided,
            twapFrequency: twapFrequency,
            sensitivity: sensitivity,
            maxBlockTradeAmount: maxBlockTradeAmount,
            insuranceFee: insuranceFee,
            lpDebtCoef: lpDebtCoef,
            lockPeriod: lockPeriod
        });

        vm.expectEmit(true, true, true, false);
        emit PerpetualParametersChanged(
            riskWeight,
            maxLiquidityProvided,
            twapFrequency,
            sensitivity,
            maxBlockTradeAmount,
            insuranceFee,
            lpDebtCoef,
            lockPeriod
        );
        perpetual.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidRiskWeight(uint256 riskWeight) public {
        vm.assume(riskWeight < 1e18 || riskWeight > 50e18);

        IPerpetual.PerpetualParams memory params = IPerpetual.PerpetualParams({
            riskWeight: riskWeight,
            maxLiquidityProvided: perpetual.maxLiquidityProvided(),
            twapFrequency: perpetual.twapFrequency(),
            sensitivity: perpetual.sensitivity(),
            maxBlockTradeAmount: perpetual.maxBlockTradeAmount(),
            insuranceFee: perpetual.insuranceFee(),
            lpDebtCoef: perpetual.lpDebtCoef(),
            lockPeriod: perpetual.lockPeriod()
        });

        vm.expectRevert(abi.encodeWithSelector(IPerpetual.Perpetual_RiskWeightInvalid.selector, riskWeight));
        perpetual.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidTwapFrequency(uint256 twapFrequency) public {
        vm.assume(twapFrequency < 1 minutes || twapFrequency > 60 minutes);

        IPerpetual.PerpetualParams memory params = IPerpetual.PerpetualParams({
            riskWeight: perpetual.riskWeight(),
            maxLiquidityProvided: perpetual.maxLiquidityProvided(),
            twapFrequency: twapFrequency,
            sensitivity: perpetual.sensitivity(),
            maxBlockTradeAmount: perpetual.maxBlockTradeAmount(),
            insuranceFee: perpetual.insuranceFee(),
            lpDebtCoef: perpetual.lpDebtCoef(),
            lockPeriod: perpetual.lockPeriod()
        });

        vm.expectRevert(abi.encodeWithSelector(IPerpetual.Perpetual_TwapFrequencyInvalid.selector, twapFrequency));
        perpetual.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidSensitivity(int256 sensitivity) public {
        vm.assume(sensitivity < 2e17 || sensitivity > 10e18);

        IPerpetual.PerpetualParams memory params = IPerpetual.PerpetualParams({
            riskWeight: perpetual.riskWeight(),
            maxLiquidityProvided: perpetual.maxLiquidityProvided(),
            twapFrequency: perpetual.twapFrequency(),
            sensitivity: sensitivity,
            maxBlockTradeAmount: perpetual.maxBlockTradeAmount(),
            insuranceFee: perpetual.insuranceFee(),
            lpDebtCoef: perpetual.lpDebtCoef(),
            lockPeriod: perpetual.lockPeriod()
        });

        vm.expectRevert(abi.encodeWithSelector(IPerpetual.Perpetual_SensitivityInvalid.selector, sensitivity));
        perpetual.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidMaxBlockTradeAmount(uint256 maxBlockTradeAmount) public {
        maxBlockTradeAmount = bound(maxBlockTradeAmount, 0, 100e18 - 1);

        IPerpetual.PerpetualParams memory params = IPerpetual.PerpetualParams({
            riskWeight: perpetual.riskWeight(),
            maxLiquidityProvided: perpetual.maxLiquidityProvided(),
            twapFrequency: perpetual.twapFrequency(),
            sensitivity: perpetual.sensitivity(),
            maxBlockTradeAmount: maxBlockTradeAmount,
            insuranceFee: perpetual.insuranceFee(),
            lpDebtCoef: perpetual.lpDebtCoef(),
            lockPeriod: perpetual.lockPeriod()
        });

        vm.expectRevert(
            abi.encodeWithSelector(IPerpetual.Perpetual_MaxBlockAmountInvalid.selector, maxBlockTradeAmount)
        );
        perpetual.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidInsuranceFee(int256 insuranceFee) public {
        vm.assume(insuranceFee < 1e14 || insuranceFee > 1e16);

        IPerpetual.PerpetualParams memory params = IPerpetual.PerpetualParams({
            riskWeight: perpetual.riskWeight(),
            maxLiquidityProvided: perpetual.maxLiquidityProvided(),
            twapFrequency: perpetual.twapFrequency(),
            sensitivity: perpetual.sensitivity(),
            maxBlockTradeAmount: perpetual.maxBlockTradeAmount(),
            insuranceFee: insuranceFee,
            lpDebtCoef: perpetual.lpDebtCoef(),
            lockPeriod: perpetual.lockPeriod()
        });

        vm.expectRevert(abi.encodeWithSelector(IPerpetual.Perpetual_InsuranceFeeInvalid.selector, insuranceFee));
        perpetual.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidLpDebtCoef(int256 lpDebtCoef) public {
        vm.assume(lpDebtCoef < 1e18 || lpDebtCoef > 20e18);

        IPerpetual.PerpetualParams memory params = IPerpetual.PerpetualParams({
            riskWeight: perpetual.riskWeight(),
            maxLiquidityProvided: perpetual.maxLiquidityProvided(),
            twapFrequency: perpetual.twapFrequency(),
            sensitivity: perpetual.sensitivity(),
            maxBlockTradeAmount: perpetual.maxBlockTradeAmount(),
            insuranceFee: perpetual.insuranceFee(),
            lpDebtCoef: lpDebtCoef,
            lockPeriod: perpetual.lockPeriod()
        });

        vm.expectRevert(abi.encodeWithSelector(IPerpetual.Perpetual_LpDebtCoefInvalid.selector, lpDebtCoef));
        perpetual.setParameters(params);
    }

    function testFuzz_FailsToSetInvalidLockPeriod(uint256 lockPeriod) public {
        vm.assume(lockPeriod < 10 minutes || lockPeriod > 30 days);

        IPerpetual.PerpetualParams memory params = IPerpetual.PerpetualParams({
            riskWeight: perpetual.riskWeight(),
            maxLiquidityProvided: perpetual.maxLiquidityProvided(),
            twapFrequency: perpetual.twapFrequency(),
            sensitivity: perpetual.sensitivity(),
            maxBlockTradeAmount: perpetual.maxBlockTradeAmount(),
            insuranceFee: perpetual.insuranceFee(),
            lpDebtCoef: perpetual.lpDebtCoef(),
            lockPeriod: lockPeriod
        });

        vm.expectRevert(abi.encodeWithSelector(IPerpetual.Perpetual_LockPeriodInvalid.selector, lockPeriod));
        perpetual.setParameters(params);
    }

    function test_FailsToTransferPerpetualToZeroAddress() public {
        vm.expectRevert(PerpOwnable_TransferZeroAddress.selector);
        vm.startPrank(address(perpetual));
        vBase.transferPerpOwner(address(0));
        vm.stopPrank();
    }
}
