// SPDX-License-Identifier: MIT
// NOTE: This strategy will not works for enabled merkletree verification funds
pragma solidity ^0.6.12;

import "./chainlink/AggregatorV3Interface.sol";
import "./chainlink/KeeperCompatibleInterface.sol";
import "../zeppelin-solidity/contracts/math/SafeMath.sol";
import "../zeppelin-solidity/contracts/access/Ownable.sol";

interface IRouter {
  function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IFund {
  function trade(
    address _source,
    uint256 _sourceAmount,
    address _destination,
    uint256 _type,
    bytes32[] calldata _proof,
    uint256[] calldata _positions,
    bytes calldata _additionalData,
    uint256 _minReturn
  ) external;

  function getFundTokenHolding(address _token) external view returns (uint256);
  function coreFundAsset() external view returns(address);
}

interface IERC20 {
  function balanceOf(address) external view returns(uint256);
}

contract UNIBuyLowSellHigh is KeeperCompatibleInterface, Ownable {
    using SafeMath for uint256;

    uint256 public previousLDRatePrice;
    address public poolAddress;
    uint256 public triggerPercent = 1;

    IRouter public router;
    address[] public path;
    IFund public fund;
    address public UNI_TOKEN;
    address public UNDERLYING_ADDRESS;
    address public LD_TOKEN;

    uint256 public dexType = 4;

    enum TradeType { Skip, BuyUNI, SellUNI }


    constructor(
        address _router,      // Uniswap v2 router
        address _poolAddress, // UNI/XXX pair (Note: XXX second connector should be same as LD_TOKEN)
        address _fund,        // SmartFund address
        address _UNI_TOKEN,   // Uniswap token
        address _LD_TOKEN     // WETH or any another backed pool token
      )
      public
    {
      router = IRouter(_router);
      poolAddress = _poolAddress;

      address[] memory _path = new address[](2);
      _path[0] = _UNI_TOKEN;
      _path[1] = _LD_TOKEN;
      path = _path;

      fund = IFund(_fund);

      UNI_TOKEN = _UNI_TOKEN;
      UNDERLYING_ADDRESS = fund.coreFundAsset();
      LD_TOKEN = _LD_TOKEN;

      previousLDRatePrice = getLDRatePrice();
    }

    // Helper for check price for 1 UNI in UNDERLYING / LD * 2
    function getLDRatePrice()
      public
      view
      returns (uint256)
    {
      uint256 oneUNIinUnderlying = getUNIPriceInUNDERLYING();
      uint256 LD = getLDAmount();
      return oneUNIinUnderlying.mul(1e18).div(LD.mul(2));
    }

    // Helper for check price for 1 UNI in UNDERLYING
    function getUNIPriceInUNDERLYING()
      public
      view
      returns (uint256)
    {
      uint256[] memory res = router.getAmountsOut(1000000000000000000, path);
      return res[1];
    }

    // Helper for get WETH or any other token connector amount in pool
    function getLDAmount() public view returns(uint256){
      return IERC20(LD_TOKEN).balanceOf(poolAddress);
    }

    // Check if need unkeep
    function checkUpkeep(bytes calldata)
      external
      override
      returns (bool upkeepNeeded, bytes memory)
    {
        if(computeTradeAction() != 0)
          upkeepNeeded = true;
    }

    // Check if need perform unkeep
    function performUpkeep(bytes calldata) external override {
        // perform action
        uint256 actionType = computeTradeAction();

        // BUY action
        if(actionType == uint256(TradeType.BuyUNI)){
          // Trade from underlying to uni
          trade(
            UNDERLYING_ADDRESS,
            UNI_TOKEN,
            underlyingAmountToSell()
           );
        }
        // SELL action
        else if(actionType == uint256(TradeType.SellUNI)){
          // Trade from uni to underlying
          trade(
            UNI_TOKEN,
            UNDERLYING_ADDRESS,
            uniAmountToSell()
           );
        }
        // NO need action
        else{
          return;
        }

        // update data after buy or sell action
        previousLDRatePrice = getLDRatePrice();
    }

    // compute if need trade
    // 0 - Skip, 1 - Buy, 2 - Sell
    function computeTradeAction() public view returns(uint){
       uint256 currentLDRatePrice = getLDRatePrice();

       // BUY if previos rate > trigger % of current
       // This means UNI go DOWN
       if(previousLDRatePrice > currentLDRatePrice){
          uint256 res = computeTrigger(
            previousLDRatePrice,
            currentLDRatePrice,
            triggerPercent
          )
          ? 1 // BUY UNI
          : 0;

          return res;
       }

       // SELL if previos rate < trigger % of current
       // This means UNI go UP
       else if(previousLDRatePrice < currentLDRatePrice){
         uint256 res = computeTrigger(
           currentLDRatePrice,
           previousLDRatePrice,
           triggerPercent
         )
         ? 2 // SELL UNI
         : 0;

         return res;
       }
       else{
         return 0; // SKIP
       }
    }

    // return true if difference >= trigger percent
    function computeTrigger(
      uint256 priceA,
      uint256 priceB,
      uint256 triggerPercent
    )
      public
      view
      returns(bool)
    {
      uint256 currentDifference = priceA.sub(priceB);
      uint256 triggerPercent = previousLDRatePrice.div(100).mul(triggerPercent);
      return currentDifference >= triggerPercent;
    }

    // Calculate how much % of UNDERLYING send from fund balance for buy UNI
    function underlyingAmountToSell() public view returns(uint256){
      uint256 totatlETH = fund.getFundTokenHolding(UNDERLYING_ADDRESS);
      return totatlETH.div(100).mul(triggerPercent);
    }

    // Calculate how much % of UNI send from fund balance for buy UNDERLYING
    function uniAmountToSell() public view returns(uint256){
      uint256 totalUNI = fund.getFundTokenHolding(UNI_TOKEN);
      return totalUNI.div(100).mul(triggerPercent);
    }

    // Helper for trade
    function trade(address _fromToken, address _toToken, uint256 _amount) internal {
      bytes32[] memory proof;
      uint256[] memory positions;

      fund.trade(
        _fromToken,
        _amount,
        _toToken,
        dexType,
        proof,
        positions,
        "0x",
        1
      );
    }

    // Only owner setters
    function setTriggerPercent(uint256 _triggerPercent) external onlyOwner{
      require(triggerPercent <= 100, "Wrong %");
      triggerPercent = _triggerPercent;
    }

    function setDexType(uint256 _dexType) external onlyOwner {
      dexType = _dexType;
    }
}
