pragma solidity 0.4.25;


import "./TRC20Interface.sol";
import "./Network.sol";
import "./Withdrawable.sol";
import "./ExpectedRateInterface.sol";


contract ExpectedRate is Withdrawable, ExpectedRateInterface, Utils2 {

    Network public network;
    uint public quantityFactor = 2;
    uint public worstCaseRateFactorInBps = 50;

    constructor(Network _network, address _admin) public {
        require(_admin != address(0));
        require(_network != address(0));
        network = _network;
        admin = _admin;
    }

    event NetworkSet(address network);

    function setNetwork(Network _network) public onlyOperator {
      require(_network != address(0));
      network = _network;
      emit NetworkSet(network);
    }

    event QuantityFactorSet (uint newFactor, uint oldFactor, address sender);

    function setQuantityFactor(uint newFactor) public onlyOperator {
        require(newFactor <= 100);

        emit QuantityFactorSet(newFactor, quantityFactor, msg.sender);
        quantityFactor = newFactor;
    }

    event MinSlippageFactorSet (uint newMin, uint oldMin, address sender);

    function setWorstCaseRateFactor(uint bps) public onlyOperator {
        require(bps <= 100 * 100);

        emit MinSlippageFactorSet(bps, worstCaseRateFactorInBps, msg.sender);
        worstCaseRateFactorInBps = bps;
    }

    //@dev when srcQty too small or 0 the expected rate will be calculated without quantity,
    // will enable rate reference before committing to any quantity
    //@dev when srcQty too small (no actual dest qty) slippage rate will be 0.
    function getExpectedRate(TRC20 src, TRC20 dest, uint srcQty)
        public view
        returns (uint expectedRate, uint slippageRate)
    {
        require(quantityFactor != 0);
        require(srcQty <= MAX_QTY);
        require(srcQty * quantityFactor <= MAX_QTY);

        if (srcQty == 0) srcQty = 1;

        uint bestReserve;
        uint worstCaseSlippageRate;

        (bestReserve, expectedRate) = network.findBestRate(src, dest, srcQty);
        (bestReserve, slippageRate) = network.findBestRate(src, dest, (srcQty * quantityFactor));

        if (expectedRate == 0) {
            expectedRate = expectedRateSmallQty(src, dest, srcQty);
        }

        require(expectedRate <= MAX_RATE);

        worstCaseSlippageRate = ((10000 - worstCaseRateFactorInBps) * expectedRate) / 10000;
        if (slippageRate >= worstCaseSlippageRate) {
            slippageRate = worstCaseSlippageRate;
        }

        return (expectedRate, slippageRate);
    }

    //@dev get expected fee rate from token to Tomo
    function getExpectedFeeRate(TRC20 token, uint srcQty)
      public
      view
      returns (uint expectedRate, uint slippageRate)
    {
      require(quantityFactor != 0);
      require(srcQty <= MAX_QTY);
      require(srcQty * quantityFactor <= MAX_QTY);

      expectedRate = network.findBestFeeRate(token, srcQty);
      slippageRate = network.findBestFeeRate(token, (srcQty * quantityFactor));

      require(expectedRate <= MAX_RATE);

      uint worstCaseSlippageRate = ((10000 - worstCaseRateFactorInBps) * expectedRate) / 10000;
      if (slippageRate >= worstCaseSlippageRate) {
          slippageRate = worstCaseSlippageRate;
      }
      return (expectedRate, slippageRate);
    }

    //@dev for small src quantities dest qty might be 0, then returned rate is zero.
    //@dev for backward compatibility we would like to return non zero rate (correct one) for small src qty
    function expectedRateSmallQty(TRC20 src, TRC20 dest, uint srcQty) internal view returns(uint) {
        address reserve;
        uint rateSrcToTomo;
        uint rateTomoToDest;
        (reserve, rateSrcToTomo) = network.searchBestRate(src, TOMO_TOKEN_ADDRESS, srcQty);

        uint ethQty = calcDestAmount(src, TOMO_TOKEN_ADDRESS, srcQty, rateSrcToTomo);

        (reserve, rateTomoToDest) = network.searchBestRate(TOMO_TOKEN_ADDRESS, dest, ethQty);
        return rateSrcToTomo * rateTomoToDest / PRECISION;
    }
}
