// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import "buttonswap-core_forge-std/Test.sol";
import {
    IButtonswapFactoryEvents,
    IButtonswapFactoryErrors
} from "../src/interfaces/IButtonswapFactory/IButtonswapFactory.sol";
import {IButtonswapPair} from "../src/interfaces/IButtonswapPair/IButtonswapPair.sol";
import {ButtonswapFactory} from "../src/ButtonswapFactory.sol";
import {Utils} from "./utils/Utils.sol";

contract ButtonswapFactoryTest is Test, IButtonswapFactoryEvents, IButtonswapFactoryErrors {
    struct Tokens {
        address A;
        address B;
        address _0;
        address _1;
    }

    function getTokens(address tokenA, address tokenB) internal pure returns (Tokens memory) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        Tokens memory tokens;
        tokens.A = tokenA;
        tokens.B = tokenB;
        tokens._0 = token0;
        tokens._1 = token1;
        return tokens;
    }

    function test_createPair(
        address initialFeeToSetter,
        address initialIsCreationRestrictedSetter,
        address initialIsPausedSetter,
        address initialParamSetter,
        address token0A,
        address token0B,
        address token1A,
        address token1B,
        address token2A
    ) public {
        // Ensure fuzzed addresses are all non-zero
        vm.assume(token0A != address(0));
        vm.assume(token0B != address(0));
        vm.assume(token1A != address(0));
        vm.assume(token1B != address(0));
        vm.assume(token2A != address(0));

        // Ensure fuzzed addresses are all distinct
        vm.assume(token0A != token0B);
        vm.assume(token0A != token1A);
        vm.assume(token0A != token1B);
        vm.assume(token0A != token2A);

        vm.assume(token0B != token1A);
        vm.assume(token0B != token1B);
        vm.assume(token0B != token2A);

        vm.assume(token1A != token1B);
        vm.assume(token1A != token2A);

        vm.assume(token1B != token2A);

        // Calculate sorted token pairs
        Tokens memory tokens0 = getTokens(token0A, token0B);
        Tokens memory tokens1 = getTokens(token1A, token1B);
        // Share B token to confirm pair creation works
        Tokens memory tokens2 = getTokens(token2A, token1B);

        // Two factories so we can test that token param order doesn't matter
        ButtonswapFactory buttonswapFactory1 =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        ButtonswapFactory buttonswapFactory2 =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);

        assertEq(buttonswapFactory1.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory1.allPairs(0);
        assertEq(buttonswapFactory1.getPair(tokens0.A, tokens0.B), address(0));
        assertEq(buttonswapFactory1.getPair(tokens0.B, tokens0.A), address(0));
        vm.expectRevert();
        buttonswapFactory1.allPairs(1);
        assertEq(buttonswapFactory1.getPair(tokens1.A, tokens1.B), address(0));
        assertEq(buttonswapFactory1.getPair(tokens1.B, tokens1.A), address(0));
        vm.expectRevert();
        buttonswapFactory1.allPairs(2);
        assertEq(buttonswapFactory1.getPair(tokens2.A, tokens2.B), address(0));
        assertEq(buttonswapFactory1.getPair(tokens2.B, tokens2.A), address(0));

        assertEq(buttonswapFactory2.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory2.allPairs(0);
        assertEq(buttonswapFactory2.getPair(tokens0.A, tokens0.B), address(0));
        assertEq(buttonswapFactory2.getPair(tokens0.B, tokens0.A), address(0));
        vm.expectRevert();
        buttonswapFactory2.allPairs(1);
        assertEq(buttonswapFactory2.getPair(tokens1.A, tokens1.B), address(0));
        assertEq(buttonswapFactory2.getPair(tokens1.B, tokens1.A), address(0));
        vm.expectRevert();
        buttonswapFactory2.allPairs(2);
        assertEq(buttonswapFactory2.getPair(tokens2.A, tokens2.B), address(0));
        assertEq(buttonswapFactory2.getPair(tokens2.B, tokens2.A), address(0));

        // Ideally confirm event params on all but pair address but invalid final param doesn't fail test as expected
        //   so best indicate we're not checking it instead.
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens0._0, tokens0._1, address(0), 1);
        address pair10 = buttonswapFactory1.createPair(tokens0.A, tokens0.B);
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens0._0, tokens0._1, address(0), 1);
        address pair20 = buttonswapFactory2.createPair(tokens0.B, tokens0.A);

        assertTrue(pair10 != pair20);
        assertEq(IButtonswapPair(pair10).token0(), tokens0._0);
        assertEq(IButtonswapPair(pair10).token1(), tokens0._1);
        assertEq(IButtonswapPair(pair20).token0(), tokens0._0);
        assertEq(IButtonswapPair(pair20).token1(), tokens0._1);

        assertEq(buttonswapFactory1.allPairsLength(), 1);
        assertEq(buttonswapFactory1.allPairs(0), pair10);
        assertEq(buttonswapFactory1.getPair(tokens0.A, tokens0.B), pair10);
        assertEq(buttonswapFactory1.getPair(tokens0.B, tokens0.A), pair10);
        vm.expectRevert();
        buttonswapFactory1.allPairs(1);
        assertEq(buttonswapFactory1.getPair(tokens1.A, tokens1.B), address(0));
        assertEq(buttonswapFactory1.getPair(tokens1.B, tokens1.A), address(0));
        vm.expectRevert();
        buttonswapFactory1.allPairs(2);
        assertEq(buttonswapFactory1.getPair(tokens2.A, tokens2.B), address(0));
        assertEq(buttonswapFactory1.getPair(tokens2.B, tokens2.A), address(0));

        assertEq(buttonswapFactory2.allPairsLength(), 1);
        assertEq(buttonswapFactory2.allPairs(0), pair20);
        assertEq(buttonswapFactory2.getPair(tokens0.A, tokens0.B), pair20);
        assertEq(buttonswapFactory2.getPair(tokens0.B, tokens0.A), pair20);
        vm.expectRevert();
        buttonswapFactory2.allPairs(1);
        assertEq(buttonswapFactory2.getPair(tokens1.A, tokens1.B), address(0));
        assertEq(buttonswapFactory2.getPair(tokens1.B, tokens1.A), address(0));
        vm.expectRevert();
        buttonswapFactory2.allPairs(2);
        assertEq(buttonswapFactory2.getPair(tokens2.A, tokens2.B), address(0));
        assertEq(buttonswapFactory2.getPair(tokens2.B, tokens2.A), address(0));

        // Test that creating a second pair behaves as expected
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens1._0, tokens1._1, address(0), 2);
        address pair11 = buttonswapFactory1.createPair(tokens1.A, tokens1.B);
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens1._0, tokens1._1, address(0), 2);
        address pair21 = buttonswapFactory2.createPair(tokens1.B, tokens1.A);

        assertTrue(pair11 != pair21);
        assertEq(IButtonswapPair(pair11).token0(), tokens1._0);
        assertEq(IButtonswapPair(pair11).token1(), tokens1._1);
        assertEq(IButtonswapPair(pair21).token0(), tokens1._0);
        assertEq(IButtonswapPair(pair21).token1(), tokens1._1);

        assertEq(buttonswapFactory1.allPairsLength(), 2);
        assertEq(buttonswapFactory1.allPairs(0), pair10);
        assertEq(buttonswapFactory1.getPair(tokens0.A, tokens0.B), pair10);
        assertEq(buttonswapFactory1.getPair(tokens0.B, tokens0.A), pair10);
        assertEq(buttonswapFactory1.allPairs(1), pair11);
        assertEq(buttonswapFactory1.getPair(tokens1.A, tokens1.B), pair11);
        assertEq(buttonswapFactory1.getPair(tokens1.B, tokens1.A), pair11);
        vm.expectRevert();
        buttonswapFactory1.allPairs(2);
        assertEq(buttonswapFactory1.getPair(tokens2.A, tokens2.B), address(0));
        assertEq(buttonswapFactory1.getPair(tokens2.B, tokens2.A), address(0));

        assertEq(buttonswapFactory2.allPairsLength(), 2);
        assertEq(buttonswapFactory2.allPairs(0), pair20);
        assertEq(buttonswapFactory2.getPair(tokens0.A, tokens0.B), pair20);
        assertEq(buttonswapFactory2.getPair(tokens0.B, tokens0.A), pair20);
        assertEq(buttonswapFactory2.allPairs(1), pair21);
        assertEq(buttonswapFactory2.getPair(tokens1.A, tokens1.B), pair21);
        assertEq(buttonswapFactory2.getPair(tokens1.B, tokens1.A), pair21);
        vm.expectRevert();
        buttonswapFactory2.allPairs(2);
        assertEq(buttonswapFactory2.getPair(tokens2.A, tokens2.B), address(0));
        assertEq(buttonswapFactory2.getPair(tokens2.B, tokens2.A), address(0));

        // Test that creating a third pair, which shares a token with a previous pair, behaves as expected
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens2._0, tokens2._1, address(0), 3);
        address pair12 = buttonswapFactory1.createPair(tokens2.A, tokens2.B);
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens2._0, tokens2._1, address(0), 3);
        address pair22 = buttonswapFactory2.createPair(tokens2.B, tokens2.A);

        assertTrue(pair12 != pair22);
        assertEq(IButtonswapPair(pair12).token0(), tokens2._0);
        assertEq(IButtonswapPair(pair12).token1(), tokens2._1);
        assertEq(IButtonswapPair(pair22).token0(), tokens2._0);
        assertEq(IButtonswapPair(pair22).token1(), tokens2._1);

        assertEq(buttonswapFactory1.allPairsLength(), 3);
        assertEq(buttonswapFactory1.allPairs(0), pair10);
        assertEq(buttonswapFactory1.getPair(tokens0.A, tokens0.B), pair10);
        assertEq(buttonswapFactory1.getPair(tokens0.B, tokens0.A), pair10);
        assertEq(buttonswapFactory1.allPairs(1), pair11);
        assertEq(buttonswapFactory1.getPair(tokens1.A, tokens1.B), pair11);
        assertEq(buttonswapFactory1.getPair(tokens1.B, tokens1.A), pair11);
        assertEq(buttonswapFactory1.allPairs(2), pair12);
        assertEq(buttonswapFactory1.getPair(tokens2.A, tokens2.B), pair12);
        assertEq(buttonswapFactory1.getPair(tokens2.B, tokens2.A), pair12);

        assertEq(buttonswapFactory2.allPairsLength(), 3);
        assertEq(buttonswapFactory2.allPairs(0), pair20);
        assertEq(buttonswapFactory2.getPair(tokens0.A, tokens0.B), pair20);
        assertEq(buttonswapFactory2.getPair(tokens0.B, tokens0.A), pair20);
        assertEq(buttonswapFactory2.allPairs(1), pair21);
        assertEq(buttonswapFactory2.getPair(tokens1.A, tokens1.B), pair21);
        assertEq(buttonswapFactory2.getPair(tokens1.B, tokens1.A), pair21);
        assertEq(buttonswapFactory2.allPairs(2), pair22);
        assertEq(buttonswapFactory2.getPair(tokens2.A, tokens2.B), pair22);
        assertEq(buttonswapFactory2.getPair(tokens2.B, tokens2.A), pair22);
    }

    function test_createPair_CannotCreatePairWithIdenticalTokens(
        address initialFeeToSetter,
        address initialIsCreationRestrictedSetter,
        address initialIsPausedSetter,
        address initialParamSetter,
        address token
    ) public {
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);

        assertEq(buttonswapFactory.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory.allPairs(0);
        assertEq(buttonswapFactory.getPair(token, token), address(0));

        vm.expectRevert(TokenIdenticalAddress.selector);
        address pair = buttonswapFactory.createPair(token, token);

        assertEq(pair, address(0));
        assertEq(buttonswapFactory.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory.allPairs(0);
        assertEq(buttonswapFactory.getPair(token, token), address(0));
    }

    function test_createPair_CannotCreatePairWithZeroAddressTokens(
        address initialFeeToSetter,
        address initialIsCreationRestrictedSetter,
        address initialIsPausedSetter,
        address initialParamSetter,
        address token
    ) public {
        // Ensure fuzzed address is non-zero
        vm.assume(token != address(0));
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);

        assertEq(buttonswapFactory.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory.allPairs(0);
        assertEq(buttonswapFactory.getPair(token, address(0)), address(0));

        vm.expectRevert(TokenZeroAddress.selector);
        address pair1 = buttonswapFactory.createPair(token, address(0));

        assertEq(pair1, address(0));
        assertEq(buttonswapFactory.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory.allPairs(0);
        assertEq(buttonswapFactory.getPair(token, address(0)), address(0));

        // Test it with the zero address as the other parameter
        vm.expectRevert(TokenZeroAddress.selector);
        address pair2 = buttonswapFactory.createPair(address(0), token);

        assertEq(pair2, address(0));
        assertEq(buttonswapFactory.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory.allPairs(0);
        assertEq(buttonswapFactory.getPair(token, address(0)), address(0));
    }

    function test_createPair_CannotCreatePairThatWasAlreadyCreated(
        address initialFeeToSetter,
        address initialIsCreationRestrictedSetter,
        address initialIsPausedSetter,
        address initialParamSetter,
        address tokenA,
        address tokenB
    ) public {
        // Ensure fuzzed addresses are non-zero
        vm.assume(tokenA != address(0));
        vm.assume(tokenB != address(0));
        // Ensure fuzzed addresses are not identical
        vm.assume(tokenA != tokenB);
        // Calculate sorted token pairs
        Tokens memory tokens = getTokens(tokenA, tokenB);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);

        assertEq(buttonswapFactory.allPairsLength(), 0);
        vm.expectRevert();
        buttonswapFactory.allPairs(0);
        assertEq(buttonswapFactory.getPair(tokens.A, tokens.B), address(0));

        // First creation should succeed
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens._0, tokens._1, address(0), 1);
        address pair1 = buttonswapFactory.createPair(tokens.A, tokens.B);

        assertTrue(pair1 != address(0));
        assertEq(IButtonswapPair(pair1).token0(), tokens._0);
        assertEq(IButtonswapPair(pair1).token1(), tokens._1);
        assertEq(buttonswapFactory.allPairsLength(), 1);
        assertEq(buttonswapFactory.allPairs(0), pair1);
        assertEq(buttonswapFactory.getPair(tokens.A, tokens.B), pair1);

        // Try to create the pair again
        vm.expectRevert(PairExists.selector);
        address pair2 = buttonswapFactory.createPair(tokens.A, tokens.B);

        assertEq(pair2, address(0));
        assertEq(buttonswapFactory.allPairsLength(), 1);
        vm.expectRevert();
        buttonswapFactory.allPairs(1);

        // Try to create the pair again, but with token params swapped order
        vm.expectRevert(PairExists.selector);
        address pair3 = buttonswapFactory.createPair(tokens.B, tokens.A);

        assertEq(pair3, address(0));
        assertEq(buttonswapFactory.allPairsLength(), 1);
        vm.expectRevert();
        buttonswapFactory.allPairs(1);
    }

    function test_createPair_CannotCreatePairIfCreationLockedAndNotIsCreationRestrictedSetter(
        address initialIsCreationRestrictedSetter,
        address pairCreator,
        address tokenA,
        address tokenB
    ) public {
        address initialFeeToSetter = address(0);
        address initialIsPausedSetter = address(0);
        address initialParamSetter = address(0);
        vm.assume(pairCreator != initialIsCreationRestrictedSetter);
        // Ensure fuzzed addresses are non-zero
        vm.assume(tokenA != address(0));
        vm.assume(tokenB != address(0));
        // Ensure fuzzed addresses are not identical
        vm.assume(tokenA != tokenB);
        // Calculate sorted token pairs
        Tokens memory tokens = getTokens(tokenA, tokenB);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);

        // IsCreationRestrictedSetter locking pair creation
        vm.prank(initialIsCreationRestrictedSetter);
        buttonswapFactory.setIsCreationRestricted(true);

        // PairCreator attempting to create pair
        vm.startPrank(pairCreator);
        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.createPair(tokens.A, tokens.B);
        vm.stopPrank();
    }

    function test_createPair_IsCreationRestrictedSetterCanCreatePairIfCreationLocked(
        address initialIsCreationRestrictedSetter,
        address tokenA,
        address tokenB
    ) public {
        address initialFeeToSetter = address(0);
        address initialIsPausedSetter = address(0);
        address initialParamSetter = address(0);
        // Ensure fuzzed addresses are non-zero
        vm.assume(tokenA != address(0));
        vm.assume(tokenB != address(0));
        // Ensure fuzzed addresses are not identical
        vm.assume(tokenA != tokenB);
        // Calculate sorted token pairs
        Tokens memory tokens = getTokens(tokenA, tokenB);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);

        // IsCreationRestrictedSetter locking pair creation
        vm.prank(initialIsCreationRestrictedSetter);
        buttonswapFactory.setIsCreationRestricted(true);

        // IsCreationRestrictedSetter can create pair
        vm.startPrank(initialIsCreationRestrictedSetter);
        vm.expectEmit(true, true, false, false);
        emit PairCreated(tokens._0, tokens._1, address(0), 1);
        buttonswapFactory.createPair(tokens.A, tokens.B);
        vm.stopPrank();
    }

    function test_setFeeTo(address initialFeeToSetter, address feeTo) public {
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);
        address initialParamSetter = address(0);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        assertEq(buttonswapFactory.feeTo(), address(0));

        vm.prank(initialFeeToSetter);
        buttonswapFactory.setFeeTo(feeTo);
        assertEq(buttonswapFactory.feeTo(), feeTo);
    }

    function test_setFeeTo_CannotCallWhenNotFeeToSetter(address initialFeeToSetter, address caller, address feeTo)
        public
    {
        vm.assume(caller != initialFeeToSetter);
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);
        address initialParamSetter = address(0);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        assertEq(buttonswapFactory.feeTo(), address(0));

        vm.startPrank(caller);
        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.setFeeTo(feeTo);
        vm.stopPrank();
        assertEq(buttonswapFactory.feeTo(), address(0));
    }

    function test_setFeeToSetter(address initialFeeToSetter, address newFeeToSetter) public {
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);
        address initialParamSetter = address(0);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        assertEq(buttonswapFactory.feeToSetter(), initialFeeToSetter);

        vm.prank(initialFeeToSetter);
        buttonswapFactory.setFeeToSetter(newFeeToSetter);
        assertEq(buttonswapFactory.feeToSetter(), newFeeToSetter);
    }

    function test_setFeeToSetter_CannotCallWhenNotFeeToSetter(
        address initialFeeToSetter,
        address caller,
        address newFeeToSetter
    ) public {
        vm.assume(caller != initialFeeToSetter);
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);
        address initialParamSetter = address(0);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        assertEq(buttonswapFactory.feeToSetter(), initialFeeToSetter);

        vm.startPrank(caller);
        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.setFeeToSetter(newFeeToSetter);
        vm.stopPrank();
        assertEq(buttonswapFactory.feeToSetter(), initialFeeToSetter);
    }

    function test_setIsCreationRestricted(address initialIsCreationRestrictedSetter, bool isCreationRestricted)
        public
    {
        address initialFeeToSetter = address(0);
        address initialIsPausedSetter = address(0);
        address initialParamSetter = address(0);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        assertEq(buttonswapFactory.isCreationRestricted(), false);

        vm.prank(initialIsCreationRestrictedSetter);
        buttonswapFactory.setIsCreationRestricted(isCreationRestricted);
        assertEq(buttonswapFactory.isCreationRestricted(), isCreationRestricted);
    }

    function test_setIsCreationRestricted_CannotCallWhenNotIsCreationRestrictedSetter(
        address initialIsCreationRestrictedSetter,
        address caller,
        bool isCreationRestricted
    ) public {
        vm.assume(caller != initialIsCreationRestrictedSetter);
        address initialFeeToSetter = address(0);
        address initialIsPausedSetter = address(0);
        address initialParamSetter = address(0);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        assertEq(buttonswapFactory.isCreationRestricted(), false);

        vm.startPrank(caller);
        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.setIsCreationRestricted(isCreationRestricted);
        vm.stopPrank();
        assertEq(buttonswapFactory.isCreationRestricted(), false);
    }

    function test_setIsCreationRestrictedSetter(
        address initialIsCreationRestrictedSetter,
        address newIsCreationRestrictedSetter
    ) public {
        address initialFeeToSetter = address(0);
        address initialIsPausedSetter = address(0);
        address initialParamSetter = address(0);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        assertEq(buttonswapFactory.isCreationRestrictedSetter(), initialIsCreationRestrictedSetter);

        vm.prank(initialIsCreationRestrictedSetter);
        buttonswapFactory.setIsCreationRestrictedSetter(newIsCreationRestrictedSetter);
        assertEq(buttonswapFactory.isCreationRestrictedSetter(), newIsCreationRestrictedSetter);
    }

    function test_setIsCreationRestrictedSetter_CannotCallWhenNotIsCreationRestrictedSetter(
        address initialIsCreationRestrictedSetter,
        address caller,
        address newIsCreationRestrictedSetter
    ) public {
        vm.assume(caller != initialIsCreationRestrictedSetter);
        address initialFeeToSetter = address(0);
        address initialIsPausedSetter = address(0);
        address initialParamSetter = address(0);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        assertEq(buttonswapFactory.isCreationRestrictedSetter(), initialIsCreationRestrictedSetter);

        vm.startPrank(caller);
        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.setIsCreationRestrictedSetter(newIsCreationRestrictedSetter);
        vm.stopPrank();
        assertEq(buttonswapFactory.isCreationRestrictedSetter(), initialIsCreationRestrictedSetter);
    }

    function test_setIsPaused(address initialIsPausedSetter, address tokenA, address tokenB, bool isPausedNew) public {
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialParamSetter = address(0);

        vm.assume(tokenA != tokenB && tokenA != address(0) && tokenB != address(0));
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        address pairAddress = buttonswapFactory.createPair(tokenA, tokenB);
        address[] memory pairAddresses = new address[](1);
        pairAddresses[0] = pairAddress;

        vm.startPrank(initialIsPausedSetter);
        buttonswapFactory.setIsPaused(pairAddresses, isPausedNew);
        assertEq(IButtonswapPair(pairAddress).getIsPaused(), isPausedNew, "isPaused should have updated");
        vm.stopPrank();
    }

    function test_setIsPaused_CannotCallIfNotIsPausedSetter(
        address initialIsPausedSetter,
        address setIsPausedCaller,
        address tokenA,
        address tokenB,
        bool isPausedNew
    ) public {
        vm.assume(setIsPausedCaller != initialIsPausedSetter);
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialParamSetter = address(0);

        vm.assume(tokenA != tokenB && tokenA != address(0) && tokenB != address(0));
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        address pairAddress = buttonswapFactory.createPair(tokenA, tokenB);
        address[] memory pairAddresses = new address[](1);
        pairAddresses[0] = pairAddress;

        vm.prank(setIsPausedCaller);
        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.setIsPaused(pairAddresses, isPausedNew);
    }

    function test_setIsPausedSetter(address initialIsPausedSetter, address newIsPausedSetter) public {
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialParamSetter = address(0);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        assertEq(buttonswapFactory.isPausedSetter(), initialIsPausedSetter);

        vm.prank(initialIsPausedSetter);
        buttonswapFactory.setIsPausedSetter(newIsPausedSetter);
        assertEq(buttonswapFactory.isPausedSetter(), newIsPausedSetter);
    }

    function test_setIsPausedSetter_CannotCallWhenNotIsPausedSetter(
        address initialIsPausedSetter,
        address caller,
        address newIsPausedSetter
    ) public {
        vm.assume(caller != initialIsPausedSetter);
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialParamSetter = address(0);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        assertEq(buttonswapFactory.isPausedSetter(), initialIsPausedSetter);

        vm.startPrank(caller);
        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.setIsPausedSetter(newIsPausedSetter);
        vm.stopPrank();
        assertEq(buttonswapFactory.isPausedSetter(), initialIsPausedSetter);
    }

    function test_setParamSetter(address initialParamSetter, address newParamSetter) public {
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        assertEq(buttonswapFactory.paramSetter(), initialParamSetter);

        vm.prank(initialParamSetter);
        buttonswapFactory.setParamSetter(newParamSetter);
        assertEq(buttonswapFactory.paramSetter(), newParamSetter);
    }

    function test_setParamSetter_CannotCallWhenNotParamSetter(
        address initialParamSetter,
        address caller,
        address newParamSetter
    ) public {
        vm.assume(caller != initialParamSetter);
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        assertEq(buttonswapFactory.paramSetter(), initialParamSetter);

        vm.startPrank(caller);
        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.setParamSetter(newParamSetter);
        vm.stopPrank();
        assertEq(buttonswapFactory.paramSetter(), initialParamSetter);
    }

    function test_setDefaultParameters(
        address initialParamSetter,
        uint16 newDefaultMaxVolatilityBps,
        uint32 newDefaultMinTimelockDuration,
        uint32 newDefaultMaxTimelockDuration,
        uint16 newDefaultMaxSwappableReservoirLimitBps,
        uint32 newDefaultSwappableReservoirGrowthWindow
    ) public {
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);

        vm.prank(initialParamSetter);
        buttonswapFactory.setDefaultParameters(
            newDefaultMaxVolatilityBps,
            newDefaultMinTimelockDuration,
            newDefaultMaxTimelockDuration,
            newDefaultMaxSwappableReservoirLimitBps,
            newDefaultSwappableReservoirGrowthWindow
        );

        assertEq(buttonswapFactory.defaultMaxVolatilityBps(), newDefaultMaxVolatilityBps);
        assertEq(buttonswapFactory.defaultMinTimelockDuration(), newDefaultMinTimelockDuration);
        assertEq(buttonswapFactory.defaultMaxTimelockDuration(), newDefaultMaxTimelockDuration);
        assertEq(buttonswapFactory.defaultMaxSwappableReservoirLimitBps(), newDefaultMaxSwappableReservoirLimitBps);
        assertEq(buttonswapFactory.defaultSwappableReservoirGrowthWindow(), newDefaultSwappableReservoirGrowthWindow);
    }

    function test_setDefaultParameters_CannotCallWhenNotParamSetter(
        address initialParamSetter,
        address caller,
        uint16 newDefaultMaxVolatilityBps,
        uint32 newDefaultMinTimelockDuration,
        uint32 newDefaultMaxTimelockDuration,
        uint16 newDefaultMaxSwappableReservoirLimitBps,
        uint32 newDefaultSwappableReservoirGrowthWindow
    ) public {
        vm.assume(caller != initialParamSetter);
        ButtonswapFactory buttonswapFactory =
            new ButtonswapFactory(address(0), address(0), address(0), initialParamSetter);

        uint256 initialDefaultMaxVolatilityBps = buttonswapFactory.defaultMaxVolatilityBps();
        uint256 initialDefaultMinTimelockDuration = buttonswapFactory.defaultMinTimelockDuration();
        uint256 initialDefaultMaxTimelockDuration = buttonswapFactory.defaultMaxTimelockDuration();
        uint256 initialDefaultMaxSwappableReservoirLimitBps = buttonswapFactory.defaultMaxSwappableReservoirLimitBps();
        uint256 initialDefaultSwappableReservoirGrowthWindow = buttonswapFactory.defaultSwappableReservoirGrowthWindow();

        // Attempt to change parameters
        vm.startPrank(caller);
        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.setDefaultParameters(
            newDefaultMaxVolatilityBps,
            newDefaultMinTimelockDuration,
            newDefaultMaxTimelockDuration,
            newDefaultMaxSwappableReservoirLimitBps,
            newDefaultSwappableReservoirGrowthWindow
        );
        vm.stopPrank();

        // Confirm initial parameters are still set
        assertEq(buttonswapFactory.defaultMaxVolatilityBps(), initialDefaultMaxVolatilityBps);
        assertEq(buttonswapFactory.defaultMinTimelockDuration(), initialDefaultMinTimelockDuration);
        assertEq(buttonswapFactory.defaultMaxTimelockDuration(), initialDefaultMaxTimelockDuration);
        assertEq(buttonswapFactory.defaultMaxSwappableReservoirLimitBps(), initialDefaultMaxSwappableReservoirLimitBps);
        assertEq(
            buttonswapFactory.defaultSwappableReservoirGrowthWindow(), initialDefaultSwappableReservoirGrowthWindow
        );
    }

    function test_setMaxVolatilityBps(
        address initialParamSetter,
        address tokenA,
        address tokenB,
        uint16 newMaxVolatilityBps
    ) public {
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);

        vm.assume(tokenA != tokenB && tokenA != address(0) && tokenB != address(0));
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        address pairAddress = buttonswapFactory.createPair(tokenA, tokenB);
        address[] memory pairAddresses = new address[](1);
        pairAddresses[0] = pairAddress;

        vm.startPrank(initialParamSetter);
        buttonswapFactory.setMaxVolatilityBps(pairAddresses, newMaxVolatilityBps);
        assertEq(
            IButtonswapPair(pairAddress).maxVolatilityBps(), newMaxVolatilityBps, "maxVolatilityBps should have updated"
        );
        vm.stopPrank();
    }

    function test_setMaxVolatilityBps_CannotCallIfNotParamSetter(
        address initialParamSetter,
        address setMaxVolatilityBpsCaller,
        address tokenA,
        address tokenB,
        uint16 newMaxVolatilityBps
    ) public {
        vm.assume(setMaxVolatilityBpsCaller != initialParamSetter);
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);

        vm.assume(tokenA != tokenB && tokenA != address(0) && tokenB != address(0));
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        address pairAddress = buttonswapFactory.createPair(tokenA, tokenB);
        address[] memory pairAddresses = new address[](1);
        pairAddresses[0] = pairAddress;

        vm.prank(setMaxVolatilityBpsCaller);
        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.setMaxVolatilityBps(pairAddresses, newMaxVolatilityBps);
    }

    function test_setMinTimelockDuration(
        address initialParamSetter,
        address tokenA,
        address tokenB,
        uint16 newMinTimelockDuration
    ) public {
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);

        vm.assume(tokenA != tokenB && tokenA != address(0) && tokenB != address(0));
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        address pairAddress = buttonswapFactory.createPair(tokenA, tokenB);
        address[] memory pairAddresses = new address[](1);
        pairAddresses[0] = pairAddress;

        vm.startPrank(initialParamSetter);
        buttonswapFactory.setMinTimelockDuration(pairAddresses, newMinTimelockDuration);
        assertEq(
            IButtonswapPair(pairAddress).minTimelockDuration(),
            newMinTimelockDuration,
            "minTimelockDuration should have updated"
        );
        vm.stopPrank();
    }

    function test_setMinTimelockDuration_CannotCallIfNotParamSetter(
        address initialParamSetter,
        address setMinTimelockDurationCaller,
        address tokenA,
        address tokenB,
        uint16 newMinTimelockDuration
    ) public {
        vm.assume(setMinTimelockDurationCaller != initialParamSetter);
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);

        vm.assume(tokenA != tokenB && tokenA != address(0) && tokenB != address(0));
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        address pairAddress = buttonswapFactory.createPair(tokenA, tokenB);
        address[] memory pairAddresses = new address[](1);
        pairAddresses[0] = pairAddress;

        vm.prank(setMinTimelockDurationCaller);
        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.setMinTimelockDuration(pairAddresses, newMinTimelockDuration);
    }

    function test_setMaxTimelockDuration(
        address initialParamSetter,
        address tokenA,
        address tokenB,
        uint16 newMaxTimelockDuration
    ) public {
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);

        vm.assume(tokenA != tokenB && tokenA != address(0) && tokenB != address(0));
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        address pairAddress = buttonswapFactory.createPair(tokenA, tokenB);
        address[] memory pairAddresses = new address[](1);
        pairAddresses[0] = pairAddress;

        vm.startPrank(initialParamSetter);
        buttonswapFactory.setMaxTimelockDuration(pairAddresses, newMaxTimelockDuration);
        assertEq(
            IButtonswapPair(pairAddress).maxTimelockDuration(),
            newMaxTimelockDuration,
            "maxTimelockDuration should have updated"
        );
        vm.stopPrank();
    }

    function test_setMaxTimelockDuration_CannotCallIfNotParamSetter(
        address initialParamSetter,
        address setMaxTimelockDurationCaller,
        address tokenA,
        address tokenB,
        uint16 newMaxTimelockDuration
    ) public {
        vm.assume(setMaxTimelockDurationCaller != initialParamSetter);
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);

        vm.assume(tokenA != tokenB && tokenA != address(0) && tokenB != address(0));
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        address pairAddress = buttonswapFactory.createPair(tokenA, tokenB);
        address[] memory pairAddresses = new address[](1);
        pairAddresses[0] = pairAddress;

        vm.prank(setMaxTimelockDurationCaller);
        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.setMaxTimelockDuration(pairAddresses, newMaxTimelockDuration);
    }

    function test_setMaxSwappableReservoirLimitBps(
        address initialParamSetter,
        address tokenA,
        address tokenB,
        uint16 newMaxSwappableReservoirLimitBps
    ) public {
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);

        vm.assume(tokenA != tokenB && tokenA != address(0) && tokenB != address(0));
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        address pairAddress = buttonswapFactory.createPair(tokenA, tokenB);
        address[] memory pairAddresses = new address[](1);
        pairAddresses[0] = pairAddress;

        vm.startPrank(initialParamSetter);
        buttonswapFactory.setMaxSwappableReservoirLimitBps(pairAddresses, newMaxSwappableReservoirLimitBps);
        assertEq(
            IButtonswapPair(pairAddress).maxSwappableReservoirLimitBps(),
            newMaxSwappableReservoirLimitBps,
            "maxSwappableReservoirLimitBps should have updated"
        );
        vm.stopPrank();
    }

    function test_setMaxSwappableReservoirLimitBps_CannotCallIfNotParamSetter(
        address initialParamSetter,
        address setMaxSwappableReservoirLimitBpsCaller,
        address tokenA,
        address tokenB,
        uint16 newMaxSwappableReservoirLimitBps
    ) public {
        vm.assume(setMaxSwappableReservoirLimitBpsCaller != initialParamSetter);
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);

        vm.assume(tokenA != tokenB && tokenA != address(0) && tokenB != address(0));
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        address pairAddress = buttonswapFactory.createPair(tokenA, tokenB);
        address[] memory pairAddresses = new address[](1);
        pairAddresses[0] = pairAddress;

        vm.prank(setMaxSwappableReservoirLimitBpsCaller);
        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.setMaxSwappableReservoirLimitBps(pairAddresses, newMaxSwappableReservoirLimitBps);
    }

    function test_setSwappableReservoirGrowthWindow(
        address initialParamSetter,
        address tokenA,
        address tokenB,
        uint32 newSwappableReservoirGrowthWindow
    ) public {
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);

        vm.assume(tokenA != tokenB && tokenA != address(0) && tokenB != address(0));
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        address pairAddress = buttonswapFactory.createPair(tokenA, tokenB);
        address[] memory pairAddresses = new address[](1);
        pairAddresses[0] = pairAddress;

        vm.startPrank(initialParamSetter);
        buttonswapFactory.setSwappableReservoirGrowthWindow(pairAddresses, newSwappableReservoirGrowthWindow);
        assertEq(
            IButtonswapPair(pairAddress).swappableReservoirGrowthWindow(),
            newSwappableReservoirGrowthWindow,
            "swappableReservoirGrowthWindow should have updated"
        );
        vm.stopPrank();
    }

    function test_setSwappableReservoirGrowthWindow_CannotCallIfNotParamSetter(
        address initialParamSetter,
        address setSwappableReservoirGrowthWindowCaller,
        address tokenA,
        address tokenB,
        uint32 newSwappableReservoirGrowthWindow
    ) public {
        vm.assume(setSwappableReservoirGrowthWindowCaller != initialParamSetter);
        address initialFeeToSetter = address(0);
        address initialIsCreationRestrictedSetter = address(0);
        address initialIsPausedSetter = address(0);

        vm.assume(tokenA != tokenB && tokenA != address(0) && tokenB != address(0));
        ButtonswapFactory buttonswapFactory =
        new ButtonswapFactory(initialFeeToSetter, initialIsCreationRestrictedSetter, initialIsPausedSetter, initialParamSetter);
        address pairAddress = buttonswapFactory.createPair(tokenA, tokenB);
        address[] memory pairAddresses = new address[](1);
        pairAddresses[0] = pairAddress;

        vm.prank(setSwappableReservoirGrowthWindowCaller);
        vm.expectRevert(Forbidden.selector);
        buttonswapFactory.setSwappableReservoirGrowthWindow(pairAddresses, newSwappableReservoirGrowthWindow);
    }

    function test_lastCreatedTokensAndParameters(
        address initialParamSetter,
        address tokenA,
        address tokenB,
        uint16 newDefaultMaxVolatilityBps,
        uint32 newDefaultMinTimelockDuration,
        uint32 newDefaultMaxTimelockDuration,
        uint16 newDefaultMaxSwappableReservoirLimitBps,
        uint32 newDefaultSwappableReservoirGrowthWindow
    ) public {
        vm.assume(tokenA != tokenB && tokenA != address(0) && tokenB != address(0));

        // If A<B, A should be token0 and vice-versa
        address expectedToken0 = tokenA < tokenB ? tokenA : tokenB;
        address expectedToken1 = tokenA < tokenB ? tokenB : tokenA;

        ButtonswapFactory buttonswapFactory =
            new ButtonswapFactory(address(0), address(0), address(0), initialParamSetter);

        // Setting up the new defaults
        vm.prank(initialParamSetter);
        buttonswapFactory.setDefaultParameters(
            newDefaultMaxVolatilityBps,
            newDefaultMinTimelockDuration,
            newDefaultMaxTimelockDuration,
            newDefaultMaxSwappableReservoirLimitBps,
            newDefaultSwappableReservoirGrowthWindow
        );

        // Creating the new pair
        address pairAddress = buttonswapFactory.createPair(tokenA, tokenB);

        // Confirming the new pair has the correct input values
        assertEq(IButtonswapPair(pairAddress).token0(), expectedToken0, "token0 should be expectedToken0");
        assertEq(IButtonswapPair(pairAddress).token1(), expectedToken1, "token1 should be expectedToken1");
        assertEq(
            IButtonswapPair(pairAddress).maxVolatilityBps(),
            newDefaultMaxVolatilityBps,
            "maxVolatilityBps should be newDefaultMaxVolatilityBps"
        );
        assertEq(
            IButtonswapPair(pairAddress).minTimelockDuration(),
            newDefaultMinTimelockDuration,
            "minTimelockDuration should be newDefaultMinTimelockDuration"
        );
        assertEq(
            IButtonswapPair(pairAddress).maxTimelockDuration(),
            newDefaultMaxTimelockDuration,
            "maxTimelockDuration should be newDefaultMaxTimelockDuration"
        );
        assertEq(
            IButtonswapPair(pairAddress).maxSwappableReservoirLimitBps(),
            newDefaultMaxSwappableReservoirLimitBps,
            "maxSwappableReservoirLimitBps should be newDefaultMaxSwappableReservoirLimitBps"
        );
        assertEq(
            IButtonswapPair(pairAddress).swappableReservoirGrowthWindow(),
            newDefaultSwappableReservoirGrowthWindow,
            "swappableReservoirGrowthWindow should be newDefaultSwappableReservoirGrowthWindow"
        );
    }
}
