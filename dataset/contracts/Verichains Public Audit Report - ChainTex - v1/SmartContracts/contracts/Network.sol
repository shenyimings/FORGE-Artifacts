pragma solidity 0.4.25;

import "./TRC20Interface.sol";
import "./ReserveInterface.sol";
import "./NetworkInterface.sol";
import "./Withdrawable.sol";
import "./Utils2.sol";
import "./WhiteListInterface.sol";
import "./ExpectedRateInterface.sol";
import "./FeeSharingInterface.sol";

/**
 * @title Helps contracts guard against reentrancy attacks.
 */
contract ReentrancyGuard {

    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private guardCounter = 1;

    /**
     * @dev Prevents a function from calling itself, directly or indirectly.
     * Calling one `nonReentrant` function from
     * another is not supported. Instead, you can implement a
     * `private` function doing the actual work, and an `external`
     * wrapper marked as `nonReentrant`.
     */
    modifier nonReentrant() {
        guardCounter += 1;
        uint256 localCounter = guardCounter;
        _;
        require(localCounter == guardCounter);
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////
/// @title Network main contract
contract Network is Withdrawable, Utils2, NetworkInterface, ReentrancyGuard {

    uint public negligibleRateDiff = 10; // basic rate steps will be in 0.01%
    ReserveInterface[] public reserves;
    mapping(address=>bool) public isReserve;
    WhiteListInterface public whiteListContract;
    ExpectedRateInterface public expectedRateContract;
    address               public networkProxyContract;
    uint                  public maxGasPriceValue = 25 * 1000 * 1000 * 1000; // 25 gwei, currently 100x default gas price of 0.25 gwei
    bool                  public isEnabled = false; // network is enabled
    mapping(bytes32=>uint) public infoFields; // this is only a UI field for external app.
    mapping(address=>address[]) public reservesPerTokenSrc; //reserves supporting token to Tomo
    mapping(address=>address[]) public reservesPerTokenDest; //reserves support Tomo to token
    /* a reserve for a token to pay for fee */
    // only 1 reserve for a token
    mapping(address=>address) public reservePerTokenFee;
    mapping(address=>uint) public feeForReserve;
    FeeSharingInterface public feeSharing;

    constructor(address _admin) public {
        require(_admin != address(0));
        admin = _admin;
    }

    event EtherReceival(address indexed sender, uint amount);

    /* solhint-disable no-complex-fallback */
    // To avoid users trying to swap tokens using default payable function. We added this short code
    //  to verify Tomos will be received only from reserves if transferred without a specific function call.
    function() public payable {
        require(isReserve[msg.sender]);
        emit EtherReceival(msg.sender, msg.value);
    }
    /* solhint-enable no-complex-fallback */

    struct TradeInput {
        address trader;
        TRC20 src;
        uint srcAmount;
        TRC20 dest;
        address destAddress;
        uint maxDestAmount;
        uint minConversionRate;
        address walletId;
    }

    function swap(
        address trader,
        TRC20 src,
        uint srcAmount,
        TRC20 dest,
        address destAddress,
        uint maxDestAmount,
        uint minConversionRate,
        address walletId
    )
        public
        nonReentrant
        payable
        returns(uint)
    {
        require(msg.sender == networkProxyContract);

        TradeInput memory tradeInput;

        tradeInput.trader = trader;
        tradeInput.src = src;
        tradeInput.srcAmount = srcAmount;
        tradeInput.dest = dest;
        tradeInput.destAddress = destAddress;
        tradeInput.maxDestAmount = maxDestAmount;
        tradeInput.minConversionRate = minConversionRate;
        tradeInput.walletId = walletId;

        return trade(tradeInput);
    }

    function payTxFee(
        address trader,
        TRC20 src,
        uint srcAmount,
        address destAddress,
        uint maxDestAmount,
        uint minConversionRate
    )
        public
        nonReentrant
        payable
        returns(uint)
    {
        require(msg.sender == networkProxyContract);

        TradeInput memory tradeInput;

        tradeInput.trader = trader;
        tradeInput.src = src;
        tradeInput.srcAmount = srcAmount;
        tradeInput.dest = TOMO_TOKEN_ADDRESS;
        tradeInput.destAddress = destAddress;
        tradeInput.maxDestAmount = maxDestAmount;
        tradeInput.minConversionRate = minConversionRate;
        tradeInput.walletId = address(0);

        return tradeFee(tradeInput);
    }

    event AddReserveToNetwork(ReserveInterface reserve, bool add);

    /// @notice can be called only by admin
    /// @dev add or deletes a reserve to/from the network.
    /// @param reserve The reserve address.
    /// @param add If true, the add reserve. Otherwise delete reserve.
    function addReserve(ReserveInterface reserve, bool add) public onlyAdmin {

        if (add) {
            require(!isReserve[reserve]);
            reserves.push(reserve);
            isReserve[reserve] = true;
            feeForReserve[reserve] = 25; // default fee for reserve is 0.25% for each tx
            emit AddReserveToNetwork(reserve, true);
        } else {
            isReserve[reserve] = false;
            // will have trouble if more than 50k reserves...
            for (uint i = 0; i < reserves.length; i++) {
                if (reserves[i] == reserve) {
                    reserves[i] = reserves[reserves.length - 1];
                    reserves.length--;
                    emit AddReserveToNetwork(reserve, false);
                    break;
                }
            }
        }
    }

    // @notice can be called only by admin
    // @dev add or delete a reserve for fee to/from the network
    // @dev will need to call separately function addReserve
    // @dev this reserve must list pair (Tomo, token) to support trade from Tomo -> token
    // @param reserve: The reserve address, if reserve is 0 then remove reserve for the token
    // @param token: token to map with the reserve

    event AddFeeReserveToNetwork(ReserveInterface reserve, TRC20 token);
    function addFeeReserve(ReserveInterface reserve, TRC20 token) public onlyAdmin {
      require(token != address(0), "Token can not be address 0x0");
      require(isReserve[reserve] == true, "Reserve is not an added reserve");
      address[] memory reserveArr = reservesPerTokenDest[token];
      bool isReserveAdded = false;
      for(uint i = 0; i < reserveArr.length; i++) {
        if (reserveArr[i] == address(reserve)) {
          isReserveAdded = true;
        }
      }
      require(isReserveAdded, "Must add this reserve to general reserve first");
      reservePerTokenFee[token] = reserve;
      emit AddFeeReserveToNetwork(reserve, token);
    }

    event ListReservePairs(address reserve, TRC20 src, TRC20 dest, bool add);

    /// @notice can be called only by admin
    /// @dev allow or prevent a specific reserve to trade a pair of tokens
    /// @param reserve The reserve address.
    /// @param token token address
    /// @param tomoToToken will it support ether to token trade
    /// @param tokenToTomo will it support token to ether trade
    /// @param add If true then list this pair, otherwise unlist it.
    function listPairForReserve(address reserve, TRC20 token, bool tomoToToken, bool tokenToTomo, bool add)
        public onlyAdmin
    {
        require(isReserve[reserve]);

        if (tomoToToken) {
            listPairs(reserve, token, false, add);

            emit ListReservePairs(reserve, TOMO_TOKEN_ADDRESS, token, add);
        }

        if (tokenToTomo) {
            listPairs(reserve, token, true, add);
            if (add) {
                require(token.approve(reserve, 2**255)); // approve infinity
            } else {
              require(token.approve(reserve, 0));
            }

            emit ListReservePairs(reserve, token, TOMO_TOKEN_ADDRESS, add);
        }

        setDecimals(token);
    }

    event FeeSharingSet(address fee, address sender);
    function setFeeSharing(FeeSharingInterface _feeSharing) public onlyAdmin {
      require(_feeSharing != address(0));
      feeSharing = _feeSharing;
      emit FeeSharingSet(_feeSharing, msg.sender);
    }

    function setWhiteList(WhiteListInterface whiteList) public onlyAdmin {
        whiteListContract = whiteList;
    }

    function setExpectedRate(ExpectedRateInterface expectedRate) public onlyAdmin {
        require(expectedRate != address(0));
        expectedRateContract = expectedRate;
    }

    function setParams(
        uint                  _maxGasPrice,
        uint                  _negligibleRateDiff
    )
        public
        onlyAdmin
    {
        require(_negligibleRateDiff <= 100 * 100); // at most 100%

        maxGasPriceValue = _maxGasPrice;
        negligibleRateDiff = _negligibleRateDiff;
    }

    function setEnable(bool _enable) public onlyAdmin {
        if (_enable) {
            require(expectedRateContract != address(0));
            require(networkProxyContract != address(0));
        }
        isEnabled = _enable;
    }

    function setInfo(bytes32 field, uint value) public onlyOperator {
        infoFields[field] = value;
    }

    event NetworkProxySet(address proxy, address sender);

    function setNetworkProxy(address networkProxy) public onlyAdmin {
        require(networkProxy != address(0));
        networkProxyContract = networkProxy;
        emit NetworkProxySet(networkProxy, msg.sender);
    }

    /// @dev returns number of reserves
    /// @return number of reserves
    function getNumReserves() public view returns(uint) {
        return reserves.length;
    }

    event FeeForReserveSet(address reserve, uint percent);
    function setFeePercent(address reserve, uint newPercent) public onlyAdmin {
      require(isReserve[reserve]);
      feeForReserve[reserve] = newPercent;
      emit FeeForReserveSet(reserve, newPercent);
    }

    /// @notice should be called off chain with as much gas as needed
    /// @dev get an array of all reserves
    /// @return An array of all reserves
    function getReserves() public view returns(ReserveInterface[] memory) {
        return reserves;
    }

    function maxGasPrice() public view returns(uint) {
        return maxGasPriceValue;
    }

    function getExpectedRate(TRC20 src, TRC20 dest, uint srcQty)
        public view
        returns(uint expectedRate, uint slippageRate)
    {
        require(expectedRateContract != address(0));
        return expectedRateContract.getExpectedRate(src, dest, srcQty);
    }

    function getExpectedFeeRate(TRC20 token, uint srcQty)
      public
      view
      returns(uint expectedRate, uint slippageRate)
    {
        require(expectedRateContract != address(0));
        return expectedRateContract.getExpectedFeeRate(token, srcQty);
    }

    function getUserCapInWei(address user) public view returns(uint) {
        if (whiteListContract == address(0)) { return 2**255; }
        return whiteListContract.getUserCapInWei(user);
    }

    function getUserCapInTokenWei(address user, TRC20 token) public view returns(uint) {
        //future feature
        user;
        token;
        require(false);
    }

    function getReservesPerTokenSrcCount(TRC20 token) public view returns(uint) {
      address[] memory reserveArr = reservesPerTokenSrc[token];
      return reserveArr.length;
    }

    function getReservesPerTokenDestCount(TRC20 token) public view returns(uint) {
      address[] memory reserveArr = reservesPerTokenDest[token];
      return reserveArr.length;
    }

    struct BestRateResult {
        uint rate;
        address reserve1;
        address reserve2;
        uint weiAmount;
        uint rateSrcToTomo;
        uint rateTomoToDest;
        uint destAmount;
    }

    /// @notice use token address TOMO_TOKEN_ADDRESS for Tomo
    /// @dev best conversion rate for a pair of tokens, if number of reserves have small differences. randomize
    /// @param src Src token
    /// @param dest Destination token
    /// @return obsolete - used to return best reserve index. not relevant anymore for this API.
    function findBestRate(TRC20 src, TRC20 dest, uint srcAmount) public view returns(uint obsolete, uint rate) {
        BestRateResult memory result = findBestRateTokenToToken(src, dest, srcAmount);
        return(0, result.rate);
    }

    // @dev find best rate for paying fee
    // @param: token: src TRC20 token
    // @param: srcQty: src quantity
    function findBestFeeRate(TRC20 token, uint srcAmount) public view returns(uint rate) {
      address reserve = reservePerTokenFee[token];
      if (reserve == address(0)) { return 0; }
      return ReserveInterface(reserve).getConversionRate(token, TOMO_TOKEN_ADDRESS, srcAmount, block.number);
    }

    function enabled() public view returns(bool) {
        return isEnabled;
    }

    function info(bytes32 field) public view returns(uint) {
        return infoFields[field];
    }

    /* solhint-disable code-complexity */
    // Not sure how solhing defines complexity. Anyway, from our point of view, below code follows the required
    //  algorithm to choose a reserve, it has been tested, reviewed and found to be clear enough.
    //@dev this function always src or dest are ether. can't do token to token
    function searchBestRate(TRC20 src, TRC20 dest, uint srcAmount) public view returns(address, uint) {
        uint bestRate = 0;
        uint bestReserve = 0;
        uint numRelevantReserves = 0;

        //return 1 for Tomo to Tomo
        if (src == dest) return (reserves[bestReserve], PRECISION);

        address[] memory reserveArr;

        if (src == TOMO_TOKEN_ADDRESS) {
            reserveArr = reservesPerTokenDest[dest];
        } else {
            reserveArr = reservesPerTokenSrc[src];
        }

        if (reserveArr.length == 0) return (reserves[bestReserve], bestRate);

        uint[] memory rates = new uint[](reserveArr.length);
        uint[] memory reserveCandidates = new uint[](reserveArr.length);

        for (uint i = 0; i < reserveArr.length; i++) {
            //list all reserves that have this token.
            rates[i] = (ReserveInterface(reserveArr[i])).getConversionRate(src, dest, srcAmount, block.number);

            if (rates[i] > bestRate) {
                //best rate is highest rate
                bestRate = rates[i];
            }
        }

        if (bestRate > 0) {
            uint random = 0;
            uint smallestRelevantRate = (bestRate * 10000) / (10000 + negligibleRateDiff);

            for (i = 0; i < reserveArr.length; i++) {
                if (rates[i] >= smallestRelevantRate) {
                    reserveCandidates[numRelevantReserves++] = i;
                }
            }

            if (numRelevantReserves > 1) {
                //when encountering small rate diff from bestRate. draw from relevant reserves
                random = uint(blockhash(block.number-1)) % numRelevantReserves;
            }

            bestReserve = reserveCandidates[random];
            bestRate = rates[bestReserve];
        }

        return (reserveArr[bestReserve], bestRate);
    }
    /* solhint-enable code-complexity */

    function findBestRateTokenToToken(TRC20 src, TRC20 dest, uint srcAmount) internal view
        returns(BestRateResult memory result)
    {
        (result.reserve1, result.rateSrcToTomo) = searchBestRate(src, TOMO_TOKEN_ADDRESS, srcAmount);
        result.weiAmount = calcDestAmount(src, TOMO_TOKEN_ADDRESS, srcAmount, result.rateSrcToTomo);

        (result.reserve2, result.rateTomoToDest) = searchBestRate(TOMO_TOKEN_ADDRESS, dest, result.weiAmount);
        result.destAmount = calcDestAmount(TOMO_TOKEN_ADDRESS, dest, result.weiAmount, result.rateTomoToDest);

        result.rate = calcRateFromQty(srcAmount, result.destAmount, getDecimals(src), getDecimals(dest));
    }

    function listPairs(address reserve, TRC20 token, bool isTokenToEth, bool add) internal {
        uint i;
        address[] storage reserveArr = reservesPerTokenDest[token];

        if (isTokenToEth) {
            reserveArr = reservesPerTokenSrc[token];
        }

        for (i = 0; i < reserveArr.length; i++) {
            if (reserve == reserveArr[i]) {
                if (add) {
                    break; //already added
                } else {
                    //remove
                    reserveArr[i] = reserveArr[reserveArr.length - 1];
                    reserveArr.length--;
                }
            }
        }

        if (add && i == reserveArr.length) {
            //if reserve wasn't found add it
            reserveArr.push(reserve);
        }
    }

    event Trade(address srcAddress, TRC20 srcToken, uint srcAmount, address destAddress, TRC20 destToken,
        uint destAmount);
    /* solhint-disable function-max-lines */
    // Most of the lins here are functions calls spread over multiple lines. We find this function readable enough
    //  and keep its size as is.
    /// @notice use token address TOMO_TOKEN_ADDRESS for ether
    /// @dev trade api for kyber network.
    /// @param tradeInput structure of trade inputs
    function trade(TradeInput memory tradeInput) internal returns(uint) {
        require(isEnabled);
        require(tx.gasprice <= maxGasPriceValue);
        require(validateTradeInput(tradeInput.src, tradeInput.srcAmount, tradeInput.dest, tradeInput.destAddress, false));

        BestRateResult memory rateResult =
        findBestRateTokenToToken(tradeInput.src, tradeInput.dest, tradeInput.srcAmount);

        require(rateResult.rate > 0);
        require(rateResult.rate < MAX_RATE);
        require(rateResult.rate >= tradeInput.minConversionRate);

        uint actualDestAmount;
        uint weiAmount;
        uint actualSrcAmount;

        (actualSrcAmount, weiAmount, actualDestAmount) = calcActualAmounts(tradeInput.src,
            tradeInput.dest,
            tradeInput.srcAmount,
            tradeInput.maxDestAmount,
            rateResult);

        if (actualSrcAmount < tradeInput.srcAmount) {
            //if there is "change" send back to trader
            if (tradeInput.src == TOMO_TOKEN_ADDRESS) {
                tradeInput.trader.transfer(tradeInput.srcAmount - actualSrcAmount);
            } else {
                require(tradeInput.src.transfer(tradeInput.trader, (tradeInput.srcAmount - actualSrcAmount)));
            }
        }

        // verify trade size is smaller than user cap
        require(weiAmount <= getUserCapInWei(tradeInput.trader));

        //do the trade
        //src to ETH

        require(doReserveTrade(
                tradeInput.src,
                actualSrcAmount,
                TOMO_TOKEN_ADDRESS,
                this,
                weiAmount,
                ReserveInterface(rateResult.reserve1),
                rateResult.rateSrcToTomo,
                true,
                tradeInput.walletId));

        //Eth to dest
        require(doReserveTrade(
                TOMO_TOKEN_ADDRESS,
                weiAmount,
                tradeInput.dest,
                tradeInput.destAddress,
                actualDestAmount,
                ReserveInterface(rateResult.reserve2),
                rateResult.rateTomoToDest,
                true,
                tradeInput.walletId));

        emit Trade(tradeInput.trader, tradeInput.src, actualSrcAmount, tradeInput.destAddress, tradeInput.dest,
            actualDestAmount);

        return actualDestAmount;
    }
    /* solhint-enable function-max-lines */

    event TradeFee(address trader, address src, uint actualSrcAmount, address destAddress, address dest,
        uint actualDestAmount);
    // @dev trade to pay for gas fee
    function tradeFee(TradeInput memory tradeInput) internal returns(uint) {
      require(isEnabled, "Network is not enabled");
      require(validateTradeInput(tradeInput.src, tradeInput.srcAmount, tradeInput.dest, tradeInput.destAddress, true), "Failed to validate trade input");

      // User pays gas fee with Tomo, just a simple transfer
      if (tradeInput.src == TOMO_TOKEN_ADDRESS) {
        uint amount = tradeInput.srcAmount;
        if (amount > tradeInput.maxDestAmount) {
          amount = tradeInput.maxDestAmount;
        }
        tradeInput.destAddress.transfer(amount);
        if (tradeInput.srcAmount > amount) {
          // return "change" if needed
          tradeInput.trader.transfer(tradeInput.srcAmount - amount);
        }
        return amount;
      }

      address reserve = reservePerTokenFee[tradeInput.src];
      require(reserve != address(0), "Reserve for token must be set");
      uint expectedRate;
      (expectedRate, ) = getExpectedFeeRate(tradeInput.src, tradeInput.srcAmount);

      require(expectedRate > 0, "expectedRate == 0");
      require(expectedRate < MAX_RATE, "expectedRate >= MAX_RATE");
      require(expectedRate >= tradeInput.minConversionRate, "expectedRate < minConversionRate");

      uint actualSrcAmount;
      uint actualDestAmount;

      (actualSrcAmount, actualDestAmount) = calcActualFeeAmounts(tradeInput.src,
          tradeInput.dest,
          tradeInput.srcAmount,
          tradeInput.maxDestAmount,
          expectedRate);

      if (actualSrcAmount < tradeInput.srcAmount) {
          // if there is "change" send back to trader
          tradeInput.src.transfer(tradeInput.trader, (tradeInput.srcAmount - actualSrcAmount));
      }

      // verify trade size is smaller than user cap, dest is always TOMO
      require(actualDestAmount <= getUserCapInWei(tradeInput.trader), "max user cap reached");

      // do the trade src to Tomo
      require(doReserveTrade(
              tradeInput.src,
              actualSrcAmount,
              TOMO_TOKEN_ADDRESS,
              tradeInput.destAddress,
              actualDestAmount,
              ReserveInterface(reserve),
              expectedRate,
              true,
              tradeInput.walletId));

      emit TradeFee(tradeInput.trader, tradeInput.src, actualSrcAmount, tradeInput.destAddress, tradeInput.dest,
          actualDestAmount);

      return actualDestAmount;
    }

    function calcActualAmounts (TRC20 src, TRC20 dest, uint srcAmount, uint maxDestAmount, BestRateResult memory rateResult)
        internal view returns(uint actualSrcAmount, uint weiAmount, uint actualDestAmount)
    {
        if (rateResult.destAmount > maxDestAmount) {
            actualDestAmount = maxDestAmount;
            weiAmount = calcSrcAmount(TOMO_TOKEN_ADDRESS, dest, actualDestAmount, rateResult.rateTomoToDest);
            actualSrcAmount = calcSrcAmount(src, TOMO_TOKEN_ADDRESS, weiAmount, rateResult.rateSrcToTomo);
            require(actualSrcAmount <= srcAmount);
        } else {
            actualDestAmount = rateResult.destAmount;
            actualSrcAmount = srcAmount;
            weiAmount = rateResult.weiAmount;
        }
    }

    function calcActualFeeAmounts (TRC20 src, TRC20 dest, uint srcAmount, uint maxDestAmount, uint rate)
        internal view returns(uint actualSrcAmount, uint actualDestAmount)
    {
        uint destAmount = calcDestAmount(src, dest, srcAmount, rate);
        if (destAmount > maxDestAmount) {
            actualDestAmount = maxDestAmount;
            actualSrcAmount = calcSrcAmount(src, dest, actualDestAmount, rate);
            require(actualSrcAmount <= srcAmount);
        } else {
            actualSrcAmount = srcAmount;
            actualDestAmount = destAmount;
        }
    }

    /// @notice use token address TOMO_TOKEN_ADDRESS for ether
    /// @dev do one trade with a reserve
    /// @param src Src token
    /// @param amount amount of src tokens
    /// @param dest   Destination token
    /// @param destAddress Address to send tokens to
    /// @param reserve Reserve to use
    /// @param validate If true, additional validations are applicable
    /// @return true if trade is successful
    function doReserveTrade(
        TRC20 src,
        uint amount,
        TRC20 dest,
        address destAddress,
        uint expectedDestAmount,
        ReserveInterface reserve,
        uint conversionRate,
        bool validate,
        address walletId
    )
        internal
        returns(bool)
    {
        uint callValue = 0;

        if (src == dest) {
            //this is for a "fake" trade when both src and dest are ethers.
            if (destAddress != (address(this)))
                destAddress.transfer(amount);
            return true;
        }

        if (src == TOMO_TOKEN_ADDRESS) {
            callValue = amount;
        }

        // calculate expected fee for this transaction based on amount of Tomo
        uint feeInWei = src == TOMO_TOKEN_ADDRESS ? callValue : expectedDestAmount;
        feeInWei = feeInWei * feeForReserve[reserve] / 10000; // feePercent = 25 -> fee = 25/10000 = 0.25%

        uint expectedTomoBal = address(this).balance;
        if (src == TOMO_TOKEN_ADDRESS) {
          // callValue amount of Tomo will be transfered to reserve
          require(expectedTomoBal >= callValue);
          expectedTomoBal -= callValue;
        }
        if (address(this) == destAddress && dest == TOMO_TOKEN_ADDRESS) {
          // expectedDestAmount of Tomo will be transfered to destAdress
          expectedTomoBal += expectedDestAmount;
        }

        // receive feeInWei amount of Tomo as fee
        expectedTomoBal += feeInWei;

        // reserve sends tokens/eth to network. network sends it to destination
        require(reserve.trade.value(callValue)(src, amount, dest, this, conversionRate, feeInWei, validate), "doReserveTrade: reserve trade failed");

        if (destAddress != address(this)) {
            //for token to token dest address is network. and Ether / token already here...
            if (dest == TOMO_TOKEN_ADDRESS) {
                destAddress.transfer(expectedDestAmount);
            } else {
                require(dest.transfer(destAddress, expectedDestAmount), "doReserveTrade: transfer token failed");
            }
        }

        // Expected to receive exact amount fee in TOMO
        require(address(this).balance == expectedTomoBal);

        if (feeSharing != address(0) && feeInWei > 0) {
          require(address(this).balance >= feeInWei);
          // transfer fee to feeSharing
          require(feeSharing.handleFees.value(feeInWei)(walletId));
        }

        return true;
    }

    /// @notice use token address TOMO_TOKEN_ADDRESS for tomo
    /// @dev checks that user sent tomo/tokens to contract before trade
    /// @param src Src token
    /// @param srcAmount amount of src tokens
    /// @return true if tradeInput is valid
    function validateTradeInput(TRC20 src, uint srcAmount, TRC20 dest, address destAddress, bool isPayingFee)
        internal
        view
        returns(bool)
    {
        require(srcAmount <= MAX_QTY, "validateTradeInput: srcAmount > MAX_QTY");
        require(srcAmount != 0, "validateTradeInput: srcAmount == 0");
        require(destAddress != address(0), "validateTradeInput: destAddress == 0x0");
        if (!isPayingFee) {
          // for pay fee, it is always src -> TOMO. Allow src to be Tomo
          require(src != dest, "validateTradeInput: src must be different from dest");
        }

        if (src == TOMO_TOKEN_ADDRESS) {
            require(msg.value == srcAmount);
        } else {
            require(msg.value == 0);
            //funds should have been moved to this contract already.
            require(src.balanceOf(this) >= srcAmount, "validateTradeInput: funds not move to contract yet");
        }

        return true;
    }
}
