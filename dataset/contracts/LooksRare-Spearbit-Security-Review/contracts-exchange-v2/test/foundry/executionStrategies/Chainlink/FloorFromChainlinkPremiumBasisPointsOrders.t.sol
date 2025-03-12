// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../../../contracts/interfaces/IExecutionManager.sol";

// Strategies
import {StrategyFloorFromChainlink} from "../../../../contracts/executionStrategies/Chainlink/StrategyFloorFromChainlink.sol";

// Other tests
import {FloorFromChainlinkPremiumOrdersTest} from "./FloorFromChainlinkPremiumOrders.t.sol";

/**
 * @notice The primary scenarios are tested in FloorFromChainlinkPremiumFixedAmountOrdersTest
 */
contract FloorFromChainlinkPremiumBasisPointsOrdersTest is FloorFromChainlinkPremiumOrdersTest {
    function setUp() public override {
        _setIsFixedAmount(0);
        _setPremium(100);
        _setSelector(StrategyFloorFromChainlink.executeBasisPointsPremiumStrategyWithTakerBid.selector, false);
        super.setUp();
    }

    function testInactiveStrategy() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        vm.prank(_owner);
        looksRareProtocol.updateStrategy(1, _standardProtocolFeeBp, _minTotalFeeBp, false);

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyNotAvailable.selector, 1));
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceGreaterThanMinPrice() public {
        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.7 ETH
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        _testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceGreaterThanOrEqualToMinPrice(makerAsk, takerBid);
    }

    function testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceEqualToMinPrice() public {
        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.7 ETH
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });
        makerAsk.minPrice = 9.797 ether;

        _testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceGreaterThanOrEqualToMinPrice(makerAsk, takerBid);
    }

    function _testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceGreaterThanOrEqualToMinPrice(
        OrderStructs.MakerAsk memory newMakerAsk,
        OrderStructs.TakerBid memory newTakerBid
    ) private {
        bytes memory signature = _signMakerAsk(newMakerAsk, makerUserPK);

        _setPriceFeed();

        // Verify it is valid
        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(newMakerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        _executeTakerBid(newTakerBid, newMakerAsk, signature);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);
        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 9.797 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 9.60106 ether);
    }

    function testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceLessThanMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloorFromChainlink = StrategyFloorFromChainlink(implementation);

        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.8 ETH
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        makerAsk.minPrice = 9.8 ether;
        takerBid.maxPrice = makerAsk.minPrice;

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        // Verify it is valid
        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        _executeTakerBid(takerBid, makerAsk, signature);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 9.8 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 9.604 ether);
    }
}
