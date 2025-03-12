// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../../../contracts/interfaces/IExecutionManager.sol";

// Strategies
import {StrategyChainlinkFloor} from "../../../../contracts/executionStrategies/Chainlink/StrategyChainlinkFloor.sol";

// Other tests
import {FloorFromChainlinkPremiumOrdersTest} from "./FloorFromChainlinkPremiumOrders.t.sol";

// Errors and constants
import {STRATEGY_NOT_ACTIVE} from "../../../../contracts/constants/ValidationCodeConstants.sol";

contract FloorFromChainlinkPremiumFixedAmountOrdersTest is FloorFromChainlinkPremiumOrdersTest {
    function setUp() public override {
        _setPremium(0.1 ether);
        _setIsFixedAmount(1);
        _setSelector(StrategyChainlinkFloor.executeFixedPremiumStrategyWithTakerBid.selector, false);
        super.setUp();
    }

    function testInactiveStrategy() public {
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });
        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        _setPriceFeed();

        vm.prank(_owner);
        looksRareProtocol.updateStrategy(1, false, _standardProtocolFeeBp, _minTotalFeeBp);

        _assertOrderIsValid(makerAsk);
        _assertMakerOrderReturnValidationCode(makerAsk, signature, STRATEGY_NOT_ACTIVE);

        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyNotAvailable.selector, 1));
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumFixedAmountDesiredSalePriceGreaterThanMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloorFromChainlink = StrategyChainlinkFloor(implementation);

        // Floor price = 9.7 ETH, premium = 0.1 ETH, desired price = 9.8 ETH
        // Min price = 9.7 ETH
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });
        _testFloorFromChainlinkPremiumFixedAmountDesiredSalePriceGreaterThanOrEqualToMinPrice(makerAsk, takerBid);
    }

    function testFloorFromChainlinkPremiumFixedAmountDesiredSalePriceEqualToMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloorFromChainlink = StrategyChainlinkFloor(implementation);

        // Floor price = 9.7 ETH, premium = 0.1 ETH, desired price = 9.8 ETH
        // Min price = 9.8 ETH
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });
        makerAsk.price = 9.8 ether;
        _testFloorFromChainlinkPremiumFixedAmountDesiredSalePriceGreaterThanOrEqualToMinPrice(makerAsk, takerBid);
    }

    function _testFloorFromChainlinkPremiumFixedAmountDesiredSalePriceGreaterThanOrEqualToMinPrice(
        OrderStructs.Maker memory makerAsk,
        OrderStructs.Taker memory takerBid
    ) public {
        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        _setPriceFeed();

        _assertOrderIsValid(makerAsk);
        _assertValidMakerOrder(makerAsk, signature);

        _executeTakerBid(takerBid, makerAsk, signature);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);
        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 9.8 ether);
        // Maker ask user receives 99.5% of the whole price (0.5% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 9.751 ether);
    }

    function testFloorFromChainlinkPremiumFixedAmountDesiredSalePriceLessThanMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloorFromChainlink = StrategyChainlinkFloor(implementation);

        // Floor price = 9.7 ETH, premium = 0.1 ETH, desired price = 9.8 ETH
        // Min price = 9.9 ETH
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        makerAsk.price = 9.9 ether;
        takerBid.additionalParameters = abi.encode(makerAsk.price);

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        _setPriceFeed();

        _assertOrderIsValid(makerAsk);
        _assertValidMakerOrder(makerAsk, signature);

        _executeTakerBid(takerBid, makerAsk, signature);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 9.9 ether);
        // Maker ask user receives 99.5% of the whole price (0.5% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 9.8505 ether);
    }
}
