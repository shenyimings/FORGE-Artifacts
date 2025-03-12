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

/**
 * @notice The primary scenarios are tested in FloorFromChainlinkPremiumFixedAmountOrdersTest
 */
contract FloorFromChainlinkPremiumBasisPointsOrdersTest is FloorFromChainlinkPremiumOrdersTest {
    function setUp() public override {
        _setIsFixedAmount(0);
        _setPremium(100);
        _setSelector(StrategyChainlinkFloor.executeBasisPointsPremiumStrategyWithTakerBid.selector, false);
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

    function testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceGreaterThanMinPrice() public {
        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.7 ETH
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        _testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceGreaterThanOrEqualToMinPrice(makerAsk, takerBid);
    }

    function testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceEqualToMinPrice() public {
        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.7 ETH
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });
        makerAsk.price = 9.797 ether;

        _testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceGreaterThanOrEqualToMinPrice(makerAsk, takerBid);
    }

    function _testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceGreaterThanOrEqualToMinPrice(
        OrderStructs.Maker memory newMakerAsk,
        OrderStructs.Taker memory newTakerBid
    ) private {
        bytes memory signature = _signMakerOrder(newMakerAsk, makerUserPK);

        _setPriceFeed();

        // Verify it is valid
        _assertOrderIsValid(newMakerAsk);
        _assertValidMakerOrder(newMakerAsk, signature);

        _executeTakerBid(newTakerBid, newMakerAsk, signature);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);
        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 9.797 ether);
        // Maker ask user receives 99.5% of the whole price (0.5% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 9.748015 ether);
    }

    function testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceLessThanMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloorFromChainlink = StrategyChainlinkFloor(implementation);

        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.8 ETH
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        makerAsk.price = 9.8 ether;
        takerBid.additionalParameters = abi.encode(makerAsk.price);

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        _setPriceFeed();

        // Verify it is valid
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
}
