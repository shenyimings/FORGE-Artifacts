// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Interfaces
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";
import {IBaseStrategy} from "../../contracts/interfaces/IBaseStrategy.sol";

// Random strategy
import {StrategyCollectionOffer} from "../../contracts/executionStrategies/StrategyCollectionOffer.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract FalseBaseStrategy is IBaseStrategy {
    /**
     * @inheritdoc IBaseStrategy
     */
    function isLooksRareV2Strategy() external pure override returns (bool) {
        return false;
    }
}

contract StrategyManagerTest is ProtocolBase, IStrategyManager {
    /**
     * Owner can discontinue strategy
     */
    function testOwnerCanDiscontinueStrategy() public asPrankedUser(_owner) {
        uint256 strategyId = 0;
        uint16 standardProtocolFeeBp = 249;
        uint16 minTotalFeeBp = 250;
        bool isActive = false;

        vm.expectEmit(false, false, false, true);
        emit StrategyUpdated(strategyId, isActive, standardProtocolFeeBp, minTotalFeeBp);
        looksRareProtocol.updateStrategy(strategyId, standardProtocolFeeBp, minTotalFeeBp, isActive);

        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(strategyId);

        assertFalse(strategyIsActive);
        assertEq(strategyStandardProtocolFee, standardProtocolFeeBp);
        assertEq(strategyMinTotalFee, minTotalFeeBp);
        assertEq(strategyMaxProtocolFee, _maxProtocolFeeBp);
        assertEq(strategySelector, _EMPTY_BYTES4);
        assertFalse(strategyIsMakerBid);
        assertEq(strategyImplementation, address(0));
    }

    function testNewStrategyEventIsEmitted() public asPrankedUser(_owner) {
        StrategyCollectionOffer strategy = new StrategyCollectionOffer();

        uint256 strategyId = 1;
        uint16 standardProtocolFeeBp = 0;
        uint16 minTotalFeeBp = 200;
        uint16 maxProtocolFeeBp = 200;
        bytes4 selector = StrategyCollectionOffer.executeCollectionStrategyWithTakerAsk.selector;
        bool isMakerBid = true;
        address implementation = address(strategy);

        vm.expectEmit(true, false, false, true);
        emit NewStrategy(
            strategyId,
            standardProtocolFeeBp,
            minTotalFeeBp,
            maxProtocolFeeBp,
            selector,
            isMakerBid,
            implementation
        );

        looksRareProtocol.addStrategy(
            standardProtocolFeeBp,
            minTotalFeeBp,
            maxProtocolFeeBp,
            selector,
            isMakerBid,
            implementation
        );
    }

    /**
     * Owner can change protocol fee information
     */
    function testOwnerCanChangeStrategyProtocolFees() public asPrankedUser(_owner) {
        uint256 strategyId = 0;
        uint16 newStandardProtocolFeeBp = 100;
        uint16 newMinTotalFeeBp = 265;
        bool isActive = true;

        vm.expectEmit(false, false, false, true);
        emit StrategyUpdated(strategyId, isActive, newStandardProtocolFeeBp, newMinTotalFeeBp);
        looksRareProtocol.updateStrategy(strategyId, newStandardProtocolFeeBp, newMinTotalFeeBp, isActive);

        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(strategyId);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, newStandardProtocolFeeBp);
        assertEq(strategyMinTotalFee, newMinTotalFeeBp);
        assertEq(strategyMaxProtocolFee, _maxProtocolFeeBp);
        assertEq(strategySelector, _EMPTY_BYTES4);
        assertFalse(strategyIsMakerBid);
        assertEq(strategyImplementation, address(0));
    }

    /**
     * Owner functions for strategy updates revert as expected under multiple revertion scenarios
     */
    function testOwnerRevertionsForWrongParametersUpdateStrategy() public asPrankedUser(_owner) {
        (
            ,
            uint16 currentStandardProtocolFee,
            uint16 currentMinTotalFee,
            uint16 maxProtocolFeeBp,
            ,
            ,

        ) = looksRareProtocol.strategyInfo(0);

        // 1. newStandardProtocolFee is higher than maxProtocolFeeBp
        uint16 newStandardProtocolFee = maxProtocolFeeBp + 1;
        uint16 newMinTotalFee = currentMinTotalFee;
        vm.expectRevert(StrategyProtocolFeeTooHigh.selector);
        looksRareProtocol.updateStrategy(0, newStandardProtocolFee, newMinTotalFee, true);

        // 2. newMinTotalFee is higher than maxProtocolFeeBp
        newStandardProtocolFee = currentStandardProtocolFee;
        newMinTotalFee = maxProtocolFeeBp + 1;
        vm.expectRevert(StrategyProtocolFeeTooHigh.selector);
        looksRareProtocol.updateStrategy(0, newStandardProtocolFee, newMinTotalFee, true);

        // 3. It reverts if strategy doesn't exist
        vm.expectRevert(StrategyNotUsed.selector);
        looksRareProtocol.updateStrategy(1, currentStandardProtocolFee, currentMinTotalFee, true);
    }

    /**
     * Owner functions for strategy additions revert as expected under multiple revertion scenarios
     */
    function testOwnerRevertionsForWrongParametersAddStrategy() public asPrankedUser(_owner) {
        uint16 standardProtocolFeeBp = 250;
        uint16 minTotalFeeBp = 300;
        uint16 maxProtocolFeeBp = 300;
        address implementation = address(0);

        // 1. standardProtocolFeeBp is higher than maxProtocolFeeBp
        maxProtocolFeeBp = standardProtocolFeeBp - 1;
        vm.expectRevert(abi.encodeWithSelector(IStrategyManager.StrategyProtocolFeeTooHigh.selector));
        looksRareProtocol.addStrategy(
            standardProtocolFeeBp,
            minTotalFeeBp,
            maxProtocolFeeBp,
            _EMPTY_BYTES4,
            true,
            implementation
        );

        // 2. minTotalFeeBp is higher than maxProtocolFeeBp
        maxProtocolFeeBp = minTotalFeeBp - 1;
        vm.expectRevert(abi.encodeWithSelector(IStrategyManager.StrategyProtocolFeeTooHigh.selector));
        looksRareProtocol.addStrategy(
            standardProtocolFeeBp,
            minTotalFeeBp,
            maxProtocolFeeBp,
            _EMPTY_BYTES4,
            true,
            implementation
        );

        // 3. maxProtocolFeeBp is higher than _MAX_PROTOCOL_FEE
        maxProtocolFeeBp = 500 + 1;
        vm.expectRevert(abi.encodeWithSelector(IStrategyManager.StrategyProtocolFeeTooHigh.selector));
        looksRareProtocol.addStrategy(
            standardProtocolFeeBp,
            minTotalFeeBp,
            maxProtocolFeeBp,
            _EMPTY_BYTES4,
            true,
            implementation
        );
    }

    function testAddStrategyNoSelector() public asPrankedUser(_owner) {
        vm.expectRevert(IStrategyManager.StrategyHasNoSelector.selector);
        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            _EMPTY_BYTES4,
            true,
            address(0)
        );
    }

    function testAddStrategyNotV2Strategy() public asPrankedUser(_owner) {
        bytes4 randomSelector = StrategyCollectionOffer.executeCollectionStrategyWithTakerAsk.selector;

        // 1. EOA
        vm.expectRevert();
        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            randomSelector,
            true,
            address(0)
        );

        // 2. Wrong contract (e.g. LooksRareProtocol)
        vm.expectRevert();
        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            randomSelector,
            true,
            address(looksRareProtocol)
        );

        // 3. Contract that implements the function but returns false
        FalseBaseStrategy falseStrategy = new FalseBaseStrategy();

        vm.expectRevert(NotV2Strategy.selector);
        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            randomSelector,
            true,
            address(falseStrategy)
        );
    }

    function testAddStrategyNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            _EMPTY_BYTES4,
            true,
            address(0)
        );
    }

    function testUpdateStrategyNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateStrategy(0, 299, 100, false);
    }
}
