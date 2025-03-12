// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.8.17;

import { PythPriceFeed_BaseTest, PythPriceFeed, IPyth, FakePyth } from "./PythPriceFeed_BaseTest.t.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract PythPriceFeed_GetPrice is PythPriceFeed_BaseTest {
  using SafeCast for int256;
  using SafeCast for uint256;
  using SafeCast for int32;

  bytes32 internal constant WBNB_PRICE_ID =
    0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f;

  struct PriceFeedData {
    bytes32 id;
    int64 price;
    uint64 conf;
    int32 expo;
    int64 emaPrice;
    uint64 emaConf;
    uint64 publishTime;
  }

  function setUp() public override {
    super.setUp();
  }

  function _convertPythPriceDataToTetherFormat(
    PythStructs.Price memory _price,
    bool _maximise
  ) internal pure returns (uint256) {
    uint256 tokenDecimals = _price.expo < 0
      ? (10**int256(-_price.expo).toUint256())
      : 10**int256(_price.expo).toUint256();
    if (_maximise) {
      return
        ((int256(_price.price) + uint256(_price.conf).toInt256()).toUint256() *
          PRICE_PRECISION) / tokenDecimals;
    }
    return
      ((int256(_price.price) - uint256(_price.conf).toInt256()).toUint256() *
        PRICE_PRECISION) / tokenDecimals;
  }

  function testCorrectness_WhenPriceIsOlderThanMaxPrice() external {
    // set max price agge to 15
    pythPriceFeed.setMaxPriceAge(15);

    // set price
    PriceFeedData memory data = PriceFeedData({
      id: WBNB_PRICE_ID,
      price: int64(28895911666),
      conf: uint64(16436851),
      expo: int32(-8),
      emaPrice: int64(28895911666),
      emaConf: uint64(16436851),
      publishTime: uint64(block.timestamp)
    });
    bytes memory priceFeedData = FakePyth(address(pyth))
      .createPriceFeedUpdateData({
        id: data.id,
        price: data.price,
        conf: data.conf,
        expo: data.expo,
        emaPrice: data.emaPrice,
        emaConf: data.emaConf,
        publishTime: data.publishTime
      });

    // update price in a Pyth contract
    bytes[] memory priceFeedDatas = new bytes[](1);
    priceFeedDatas[0] = priceFeedData;
    pyth.updatePriceFeeds{ value: FEE }(priceFeedDatas);

    // set token to the correct price id
    pythPriceFeed.setTokenPriceId(address(bnb), WBNB_PRICE_ID);

    // warp to 16 seconds later, so that price is older than MaxAge (15 seconds)
    vm.warp(block.timestamp + 16);

    // get price, should return ref price instead
    uint256 refPrice = 20000 * 10**30;
    uint256 price = pythPriceFeed.getPrice(address(bnb), refPrice, true);

    assertEq(price, refPrice);
  }

  function testCorrectness_WhenPriceIsNotOlderThanMaxPrice() external {
    // set max price agge to 15
    pythPriceFeed.setMaxPriceAge(15);

    // set price
    PriceFeedData memory data = PriceFeedData({
      id: WBNB_PRICE_ID,
      price: int64(28895911666),
      conf: uint64(16436851),
      expo: int32(-8),
      emaPrice: int64(28895911666),
      emaConf: uint64(16436851),
      publishTime: uint64(block.timestamp)
    });
    bytes memory priceFeedData = FakePyth(address(pyth))
      .createPriceFeedUpdateData({
        id: data.id,
        price: data.price,
        conf: data.conf,
        expo: data.expo,
        emaPrice: data.emaPrice,
        emaConf: data.emaConf,
        publishTime: data.publishTime
      });

    // update price in a Pyth contract
    bytes[] memory priceFeedDatas = new bytes[](1);
    priceFeedDatas[0] = priceFeedData;
    pyth.updatePriceFeeds{ value: FEE }(priceFeedDatas);

    // set token to the correct price id
    pythPriceFeed.setTokenPriceId(address(bnb), WBNB_PRICE_ID);

    // warp to 15 seconds later, so that it's still within MaxAge (15 seconds)
    vm.warp(block.timestamp + 15);

    // get price, should return ref price instead
    uint256 refPrice = 20000 * 10**30;
    uint256 price = pythPriceFeed.getPrice(address(bnb), refPrice, true);

    PythStructs.Price memory priceStruct = PythStructs.Price({
      price: data.price,
      conf: data.conf,
      expo: data.expo,
      publishTime: data.publishTime
    });

    // It should return a price from Pyth service
    assertEq(price, _convertPythPriceDataToTetherFormat(priceStruct, true));
    // Calculation correctness check
    // Price should be 28895911666 * 10**30 / 10**8 = 288959116660000000000000000000000
    // With maximise = true, it should add confidence to the price
    // 288959116660000000000000000000000 + (16436851 * 10**30 / 10**8) = 289123485170000000000000000000000
    assertEq(price, 289123485170000000000000000000000);

    // Incase of maximise = false, it should subtract confidence from the price
    price = pythPriceFeed.getPrice(address(bnb), refPrice, false);

    // It should return a price from Pyth service
    assertEq(price, _convertPythPriceDataToTetherFormat(priceStruct, false));
    // Calculation correctness check
    // Price should be 28895911666 * 10**30 / 10**8 = 288959116660000000000000000000000
    // With maximise = true, it should add confidence to the price
    // 288959116660000000000000000000000 - (16436851 * 10**30 / 10**8) = 288794748150000000000000000000000
    assertEq(price, 288794748150000000000000000000000);
  }

  function testCorrectness_WhenFavorRefPrice() external {
    // set max price agge to 15
    pythPriceFeed.setMaxPriceAge(15);

    // set price
    PriceFeedData memory data = PriceFeedData({
      id: WBNB_PRICE_ID,
      price: int64(27775911666),
      conf: uint64(16436851),
      expo: int32(-8),
      emaPrice: int64(28895911666),
      emaConf: uint64(16436851),
      publishTime: uint64(block.timestamp)
    });
    bytes memory priceFeedData = FakePyth(address(pyth))
      .createPriceFeedUpdateData({
        id: data.id,
        price: data.price,
        conf: data.conf,
        expo: data.expo,
        emaPrice: data.emaPrice,
        emaConf: data.emaConf,
        publishTime: data.publishTime
      });

    // update price in a Pyth contract
    bytes[] memory priceFeedDatas = new bytes[](1);
    priceFeedDatas[0] = priceFeedData;
    pyth.updatePriceFeeds{ value: FEE }(priceFeedDatas);

    // set token to the correct price id
    pythPriceFeed.setTokenPriceId(address(bnb), WBNB_PRICE_ID);

    // favor ref price
    pythPriceFeed.setFavorRefPrice(true);

    // warp to 15 seconds later, set price again
    vm.warp(block.timestamp + 15);

    // set price
    data = PriceFeedData({
      id: WBNB_PRICE_ID,
      price: int64(28895911666),
      conf: uint64(16436851),
      expo: int32(-8),
      emaPrice: int64(28895911666),
      emaConf: uint64(16436851),
      publishTime: uint64(block.timestamp)
    });
    priceFeedData = FakePyth(address(pyth)).createPriceFeedUpdateData({
      id: data.id,
      price: data.price,
      conf: data.conf,
      expo: data.expo,
      emaPrice: data.emaPrice,
      emaConf: data.emaConf,
      publishTime: data.publishTime
    });

    // update price in a Pyth contract
    priceFeedDatas[0] = priceFeedData;
    pyth.updatePriceFeeds{ value: FEE }(priceFeedDatas);

    // warp to 15 seconds later, so that it's still within MaxAge (15 seconds)
    vm.warp(block.timestamp + 15);

    // get price, should return ref price instead since the price we feed is stale now
    uint256 refPrice = 20000 * 10**30;
    uint256 price = pythPriceFeed.getPrice(address(bnb), refPrice, true);

    assertEq(price, refPrice);
  }
}
