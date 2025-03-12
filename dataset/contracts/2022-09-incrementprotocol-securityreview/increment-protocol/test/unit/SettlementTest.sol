// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

import "../helpers/Deployment.MainnetFork.sol";
import {Merkle} from "../../lib/murky/src/Merkle.sol";
import {PerpSettlement} from "../../contracts/PerpSettlement.sol";
import {ISettlement} from "../../contracts/interfaces/ISettlement.sol";
import {IPerpetual} from "../../contracts/interfaces/IPerpetual.sol";
import {LibMath} from "../../contracts/lib/LibMath.sol";
import {LibPerpetual} from "../../contracts/lib/LibPerpetual.sol";

contract SettlementTest is Deployment {
    using LibMath for uint256;
    using LibMath for int256;

    event PositionVerified(address indexed account, int128 openNotional, bytes32[] merkleProof);

    PerpSettlement public settlement;
    Merkle public merkle;
    bytes32[] public data;
    bytes32 public root;

    // constants
    uint256 constant VQUOTE_INDEX = 0;
    uint256 constant VBASE_INDEX = 1;

    // addresses
    address lp = address(123);
    address lp2 = address(456);
    address alice = address(789);
    address bob = address(987);

    // config values
    uint256 maxTradeAmount;
    uint256 minTradeAmount;
    int256 insuranceFee;

    function _dealAndDeposit(address addr, uint256 amount) internal {
        deal(address(ua), addr, amount);

        vm.startPrank(addr);
        ua.approve(address(vault), amount);
        clearingHouse.deposit(amount, ua);
        vm.stopPrank();
    }

    function _dealAndProvideLiquidity(uint256 idx, address addr, uint256 amount) internal {
        _dealAndDeposit(addr, amount);
        uint256 quoteAmount = amount / 2;
        uint256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.prank(addr);
        clearingHouse.provideLiquidity(idx, [quoteAmount, baseAmount], 0);
    }

    function _openPosition(
        uint256 idx,
        address trader,
        LibPerpetual.Side direction,
        uint256 minAmount,
        uint256 sellAmount
    ) internal {
        vm.startPrank(trader);
        clearingHouse.changePosition(idx, sellAmount, minAmount, direction);
        vm.stopPrank();
    }

    function _updateMerkleTree(IPerpetual perp) internal returns (int128 alicePnL, int128 bobPnL, int128 lpPnL) {
        alicePnL = int128(perp.getPendingPnL(alice));
        bobPnL = int128(perp.getPendingPnL(bob));
        lpPnL = int128(perp.getPendingPnL(lp));
        data = new bytes32[](3);
        data[0] = keccak256(abi.encodePacked(alice, alicePnL));
        data[1] = keccak256(abi.encodePacked(bob, bobPnL));
        data[2] = keccak256(abi.encodePacked(lp, lpPnL));
        root = merkle.getRoot(data);
        settlement.setMerkleRoot(root);
    }

    function _postProofs(int128 alicePnL, int128 bobPnL, int128 lpPnL) internal {
        ISettlement.PnLProof memory proof =
            ISettlement.PnLProof({account: alice, pnl: alicePnL, merkleProof: merkle.getProof(data, 0)});
        settlement.postPnL(proof);
        proof = ISettlement.PnLProof({account: bob, pnl: bobPnL, merkleProof: merkle.getProof(data, 1)});
        settlement.postPnL(proof);
        proof = ISettlement.PnLProof({account: lp, pnl: lpPnL, merkleProof: merkle.getProof(data, 2)});
        settlement.postPnL(proof);
    }

    function setUp() public override {
        super.setUp();
        maxTradeAmount = perpetual.maxPosition() / 2;
        minTradeAmount = clearingHouse.minPositiveOpenNotional() * 2;
        insuranceFee = perpetual.insuranceFee();

        // Create Merkle root
        merkle = new Merkle();
        data = new bytes32[](2);
        data[0] = keccak256(abi.encodePacked(alice, int128(100)));
        data[1] = keccak256(abi.encodePacked(bob, int128(-100)));
        root = merkle.getRoot(data);

        // Create settlement contract
        IPerpetual[] memory markets = new IPerpetual[](1);
        markets[0] = perpetual;
        settlement = new PerpSettlement(clearingHouse, markets, root);

        // Deploy second perpetual contract
        _deployEthMarket();
    }

    function test_PostProof() public {
        // test invalid proof
        ISettlement.PnLProof memory proof =
            ISettlement.PnLProof({account: alice, pnl: int128(100), merkleProof: new bytes32[](0)});
        assertTrue(!settlement.verifyPnL(proof));
        vm.expectRevert(abi.encodeWithSignature("Settlement_InvalidMerkleProof()"));
        settlement.postPnL(proof);
        proof = ISettlement.PnLProof({account: alice, pnl: int128(-100), merkleProof: merkle.getProof(data, 0)});
        assertTrue(!settlement.verifyPnL(proof));
        vm.expectRevert(abi.encodeWithSignature("Settlement_InvalidMerkleProof()"));
        settlement.postPnL(proof);

        // test valid proof
        proof = ISettlement.PnLProof({account: alice, pnl: int128(100), merkleProof: merkle.getProof(data, 0)});
        assertTrue(settlement.verifyPnL(proof));
        vm.expectEmit(false, false, false, true);
        emit PositionVerified(alice, 100, proof.merkleProof);
        settlement.postPnL(proof);
        assertEq(settlement.getTraderUnrealizedPnL(alice), 100);
        proof = ISettlement.PnLProof({account: bob, pnl: int128(-100), merkleProof: merkle.getProof(data, 1)});
        assertTrue(settlement.verifyPnL(proof));
        vm.expectEmit(false, false, false, true);
        emit PositionVerified(bob, -100, proof.merkleProof);
        settlement.postPnL(proof);
        assertEq(settlement.getTraderUnrealizedPnL(bob), -100);
    }

    function test_SettlementPerpetualViews() public {
        assertTrue(!settlement.isTradingExpansionAllowed());
        assertTrue(!settlement.isLpPositionOpen(alice));
        assertEq(address(settlement.market()), address(0));
        assertEq(address(settlement.vBase()), address(0));
        assertEq(address(settlement.vQuote()), address(0));
        assertEq(address(settlement.curveCryptoViews()), address(0));
        assertEq(settlement.maxLiquidityProvided(), 0);
        assertEq(settlement.oracleCumulativeAmount(), 0);
        assertEq(settlement.oracleCumulativeAmountAtBeginningOfPeriod(), 0);
        assertEq(settlement.marketCumulativeAmount(), 0);
        assertEq(settlement.marketCumulativeAmountAtBeginningOfPeriod(), 0);
        assertEq(settlement.riskWeight(), 1e18);
        assertEq(settlement.twapFrequency(), 0);
        assertEq(settlement.sensitivity(), 0);
        assertEq(settlement.maxBlockTradeAmount(), 0);
        assertEq(settlement.maxPosition(), 0);
        assertEq(settlement.insuranceFee(), 0);
        assertEq(settlement.lpDebtCoef(), 1e18);
        assertEq(settlement.lockPeriod(), 0);
        assertEq(settlement.oracleTwap(), 1e18);
        assertEq(settlement.marketTwap(), 1e18);
        assertEq(settlement.getLpPositionAfterWithdrawal(alice).openNotional, 0);
        assertEq(settlement.getLpPositionAfterWithdrawal(alice).positionSize, 0);
        assertEq(settlement.getLpPositionAfterWithdrawal(alice).cumFundingRate, 0);
        assertEq(settlement.getLpLiquidity(alice), 0);
        assertEq(settlement.getLpPosition(alice).liquidityBalance, 0);
        assertEq(settlement.getLpPosition(alice).depositTime, 0);
        assertEq(settlement.getLpPosition(alice).totalTradingFeesGrowth, 0);
        assertEq(settlement.getGlobalPosition().timeOfLastTrade, 0);
        assertEq(settlement.getGlobalPosition().totalQuoteProvided, 0);
        assertEq(settlement.getGlobalPosition().currentBlockTradeAmount, 0);
        assertEq(settlement.getLpUnrealizedPnL(alice), 0);
        assertEq(settlement.getLpTradingFees(alice), 0);
        assertEq(settlement.marketPrice(), 1e18);
        assertEq(settlement.indexPrice(), 1e18);
        assertEq(settlement.getTotalLiquidityProvided(), 0);
        assertEq(settlement.getLpOpenNotional(alice), 0);
        assertEq(settlement.settleLpFunding(alice), 0);
        // cover functions that do nothing but do not revert
        settlement.pause();
        settlement.unpause();
        settlement.updateGlobalState();
    }

    function test_SettlementPerpetualErrors() public {
        vm.expectRevert(abi.encodeWithSignature("Perpetual_SenderNotClearingHouse()"));
        settlement.changePosition(alice, 0, 0, LibPerpetual.Side.Long, false);
        vm.expectRevert(abi.encodeWithSignature("Settlement_RemoveLiquidityNotAllowed()"));
        settlement.removeLiquiditySwap(alice, 0, [uint256(0), uint256(0)], bytes(""));
        vm.expectRevert(abi.encodeWithSignature("Settlement_RemoveLiquidityNotAllowed()"));
        settlement.removeLiquidity(alice, 0, [uint256(0), uint256(0)], 0, 0, false);
        vm.expectRevert(abi.encodeWithSignature("Settlement_ProvideLiquidityNotAllowed()"));
        settlement.provideLiquidity(alice, [uint256(0), uint256(0)], 0);
        vm.expectRevert(abi.encodeWithSignature("Settlement_ToggleTradingExpansionNotAllowed()"));
        settlement.toggleTradingExpansionPause(false);
        vm.expectRevert(abi.encodeWithSignature("Settlement_SetParametersNotAllowed()"));
        settlement.setParameters(
            IPerpetual.PerpetualParams({
                riskWeight: 0,
                maxLiquidityProvided: 0,
                twapFrequency: 0,
                sensitivity: 0,
                maxBlockTradeAmount: 0,
                insuranceFee: 0,
                lpDebtCoef: 0,
                lockPeriod: 0
            })
        );
    }

    function testFuzz_SettlementProofRequirement(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount, maxTradeAmount);
        _dealAndProvideLiquidity(0, lp, depositAmount * 2);
        _dealAndDeposit(alice, depositAmount);
        _dealAndDeposit(bob, depositAmount);

        // alice open long position
        uint256 expectedVBase = viewer.getTraderDy(0, depositAmount, LibPerpetual.Side.Long);
        uint256 minVBaseAmount = expectedVBase.wadMul(0.99 ether);
        _openPosition(0, alice, LibPerpetual.Side.Long, minVBaseAmount, depositAmount);

        // bob open short position
        uint256 vBasePrice = perpetual.indexPrice().toUint256();
        uint256 sellAmount = depositAmount.wadDiv(vBasePrice);
        uint256 expectedVQuote = viewer.getTraderDy(0, sellAmount, LibPerpetual.Side.Short);
        uint256 minVQuoteAmount = expectedVQuote.wadMul(0.99 ether);
        _openPosition(0, bob, LibPerpetual.Side.Short, minVQuoteAmount, sellAmount);

        // update merkle tree with new data
        (int128 alicePnL, int128 bobPnL, int128 lpPnL) = _updateMerkleTree(perpetual);

        // make sure users with open trading/lp positions must post proof
        assertTrue(settlement.mustPostPosition(alice));
        assertTrue(settlement.mustPostPosition(bob));
        assertTrue(settlement.mustPostPosition(lp));
        assertTrue(!settlement.mustPostPosition(lp2));

        // make sure appropriate functions fail if users still need to post proof
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        settlement.getTraderPosition(alice);
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        settlement.getTraderUnrealizedPnL(bob);
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        settlement.getPendingPnL(lp);
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        settlement.getUserDebt(alice);
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        settlement.isTraderPositionOpen(bob);
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        settlement.settleTraderFunding(bob);
        vm.startPrank(address(clearingHouse));
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        settlement.changePosition(alice, 0, 0, LibPerpetual.Side.Long, false);
        vm.stopPrank();

        // post proofs
        _postProofs(alicePnL, bobPnL, lpPnL);

        // make sure users who posted proofs don't need to post again
        assertTrue(!settlement.mustPostPosition(alice));
        assertTrue(!settlement.mustPostPosition(bob));
        assertTrue(!settlement.mustPostPosition(lp));

        // make sure appropriate functions succeed once users post proof
        assertEq(settlement.getTraderPosition(alice).openNotional, alicePnL);
        assertEq(settlement.getTraderUnrealizedPnL(bob), bobPnL);
        assertEq(settlement.getPendingPnL(lp), lpPnL);
        assertEq(settlement.getUserDebt(alice), int256(alicePnL).min(0));
        assertTrue(settlement.isTraderPositionOpen(bob));
        assertEq(settlement.settleTraderFunding(bob), 0);
    }

    function testFuzz_ClearingHouseProofRequirement(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount, maxTradeAmount);
        _dealAndProvideLiquidity(0, lp, depositAmount * 2);
        _dealAndDeposit(alice, depositAmount);
        _dealAndDeposit(bob, depositAmount);

        // alice open long position
        uint256 expectedVBase = viewer.getTraderDy(0, depositAmount, LibPerpetual.Side.Long);
        uint256 minVBaseAmount = expectedVBase.wadMul(0.99 ether);
        _openPosition(0, alice, LibPerpetual.Side.Long, minVBaseAmount, depositAmount);

        // bob open short position
        uint256 sellAmount = depositAmount.wadDiv(perpetual.indexPrice().toUint256());
        uint256 minVQuoteAmount = viewer.getTraderDy(0, sellAmount, LibPerpetual.Side.Short).wadMul(0.99 ether);
        _openPosition(0, bob, LibPerpetual.Side.Short, minVQuoteAmount, sellAmount);

        // lp2 provide liquidity to eth_perpetual
        _dealAndDeposit(lp2, depositAmount);
        uint256 quoteAmount = depositAmount / 2;
        uint256 baseAmount = quoteAmount.wadDiv(eth_perpetual.indexPrice().toUint256());
        vm.startPrank(lp2);
        clearingHouse.provideLiquidity(1, [quoteAmount, baseAmount], 0);
        vm.stopPrank();

        // update merkle tree with new data
        _updateMerkleTree(perpetual);

        // delist old market and add settlement contract to clearing house
        clearingHouse.delistPerpetual(perpetual);
        clearingHouse.allowListPerpetual(settlement);

        // make sure users with open trading/lp positions in delisted market must post proof
        // before interacting with any market via the clearing house
        _dealAndDeposit(lp, depositAmount);
        vm.startPrank(lp);
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        clearingHouse.provideLiquidity(1, [quoteAmount, baseAmount], 0);
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        clearingHouse.removeLiquidity(1, depositAmount, [quoteAmount, baseAmount], depositAmount, 0);
        vm.stopPrank();
        vm.startPrank(alice);
        deal(address(ua), alice, depositAmount);
        ua.approve(address(vault), depositAmount);
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        clearingHouse.extendPositionWithCollateral(
            1, alice, depositAmount, ua, depositAmount, LibPerpetual.Side.Long, 0
        );
        clearingHouse.deposit(depositAmount, ua);
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        clearingHouse.changePosition(1, depositAmount, minVBaseAmount, LibPerpetual.Side.Long);
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        clearingHouse.closePositionWithdrawCollateral(1, depositAmount, 0, ua);
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        clearingHouse.openReversePosition(1, depositAmount, 0, depositAmount, 0, LibPerpetual.Side.Short);
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        clearingHouse.liquidateTrader(1, bob, depositAmount, 0);
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        clearingHouse.liquidateLp(1, lp, [uint256(0), uint256(0)], depositAmount, 0);
        vm.expectRevert(abi.encodeWithSignature("Settlement_MustPostPositionProof()"));
        clearingHouse.seizeCollateral(bob);
        vm.stopPrank();
    }

    function testFuzz_ClearingHouseAfterProof(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount, maxTradeAmount);
        _dealAndProvideLiquidity(0, lp, depositAmount * 2);
        _dealAndDeposit(alice, depositAmount);
        _dealAndDeposit(bob, depositAmount);

        // alice open long position
        uint256 expectedVBase = viewer.getTraderDy(0, depositAmount, LibPerpetual.Side.Long);
        uint256 minVBaseAmount = expectedVBase.wadMul(0.99 ether);
        _openPosition(0, alice, LibPerpetual.Side.Long, minVBaseAmount, depositAmount);

        // bob open short position
        uint256 sellAmount = depositAmount.wadDiv(perpetual.indexPrice().toUint256());
        uint256 minVQuoteAmount = viewer.getTraderDy(0, sellAmount, LibPerpetual.Side.Short).wadMul(0.99 ether);
        _openPosition(0, bob, LibPerpetual.Side.Short, minVQuoteAmount, sellAmount);

        // lp2 provide liquidity to eth_perpetual
        _dealAndDeposit(lp2, depositAmount);
        uint256 quoteAmount = depositAmount / 2;
        uint256 baseAmount = quoteAmount.wadDiv(eth_perpetual.indexPrice().toUint256());
        vm.startPrank(lp2);
        clearingHouse.provideLiquidity(1, [quoteAmount, baseAmount], 0);
        vm.stopPrank();

        // update merkle tree with new data
        (int128 alicePnL, int128 bobPnL, int128 lpPnL) = _updateMerkleTree(perpetual);

        // delist old market and add settlement contract to clearing house
        clearingHouse.delistPerpetual(perpetual);
        clearingHouse.allowListPerpetual(settlement);

        // post proofs
        _postProofs(alicePnL, bobPnL, lpPnL);

        // make sure users' PnL and debt are properly accounted for after posting proof
        assertTrue(settlement.isTraderPositionOpen(alice));
        assertEq(clearingHouse.getPnLAcrossMarkets(alice), alicePnL);
        assertEq(clearingHouse.getDebtAcrossMarkets(alice), int256(alicePnL) < 0 ? int256(alicePnL) : int256(0));
        assertTrue(settlement.isTraderPositionOpen(bob));
        assertEq(clearingHouse.getPnLAcrossMarkets(bob), bobPnL);
        assertEq(clearingHouse.getDebtAcrossMarkets(bob), int256(bobPnL) < 0 ? int256(bobPnL) : int256(0));
        assertTrue(settlement.isTraderPositionOpen(lp));
        assertEq(clearingHouse.getPnLAcrossMarkets(lp), lpPnL);
        assertEq(clearingHouse.getDebtAcrossMarkets(lp), int256(lpPnL) < 0 ? int256(lpPnL) : int256(0));

        // make sure users who posted proofs can now interact with any market via the clearing house
        vm.startPrank(lp);
        clearingHouse.provideLiquidity(1, [quoteAmount, baseAmount], 0);
        assertTrue(eth_perpetual.isLpPositionOpen(lp));
        vm.stopPrank();
        vm.startPrank(alice);
        clearingHouse.changePosition(1, depositAmount / 2, 0, LibPerpetual.Side.Long);
        assertTrue(eth_perpetual.isTraderPositionOpen(alice));

        // make sure changePosition only settles in the vault and affects reserveValue
        // by the exact settlement amount
        int256 vaultBalanceBefore = vault.getBalance(alice, 0);
        int256 reserveValueBefore = vault.getReserveValue(alice, false);
        clearingHouse.changePosition(2, depositAmount, 0, LibPerpetual.Side.Long);
        assertTrue(!settlement.isTraderPositionOpen(alice));
        assertEq(vault.getBalance(alice, 0), vaultBalanceBefore + alicePnL);
        assertEq(vault.getReserveValue(alice, false), reserveValueBefore + alicePnL);
        vm.stopPrank();
    }
}
