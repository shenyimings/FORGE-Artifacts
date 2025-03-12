pragma solidity 0.4.25;

import "../Network.sol";


////////////////////////////////////////////////////////////////////////////////////////////////////////
/// @title Network main contract, takes some fee and reports actual dest amount minus Fees.
contract MaliciousNetwork is Network {

    address public myWallet = 0x1234;
    uint public myFeeWei = 10;

    constructor(address _admin) public Network(_admin) { }

    /* solhint-disable function-max-lines */
    /// @notice use token address TOMO_TOKEN_ADDRESS for ether
    /// @dev trade api for network.
    /// @param tradeInput structure of trade inputs
    function trade(TradeInput tradeInput) internal returns(uint) {
        require(isEnabled);
        require(tx.gasprice <= maxGasPriceValue);

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
                tradeInput.src.transfer(tradeInput.trader, (tradeInput.srcAmount - actualSrcAmount));
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

        return (actualDestAmount - myFeeWei);
    }
    /* solhint-enable function-max-lines */

    function setMyFeeWei(uint fee) public {
        myFeeWei = fee;
    }

    /// @notice use token address TOMO_TOKEN_ADDRESS for tomo
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
            if (destAddress != (address(this))) {
                destAddress.transfer(amount - myFeeWei);
                myWallet.transfer(myFeeWei);
            }
            return true;
        }

        if (src == TOMO_TOKEN_ADDRESS) {
            callValue = amount;
        }

        // calculate expected fee for this transaction based on amount of Tomo
        uint tomoValue = src == TOMO_TOKEN_ADDRESS ? callValue : expectedDestAmount;
        uint feeInWei = tomoValue * feeForReserve[reserve] / 10000; // feePercent = 25 -> fee = 25/10000 = 0.25%

        // reserve sends tokens/eth to network. network sends it to destination
        require(reserve.trade.value(callValue)(src, amount, dest, this, conversionRate, feeInWei, validate));

        if (destAddress != address(this)) {

            //for token to token dest address is network. and Tomo / token already here...
            if (dest == TOMO_TOKEN_ADDRESS) {
                destAddress.transfer(expectedDestAmount);
            } else {
                require(dest.transfer(destAddress, (expectedDestAmount - myFeeWei)));
                dest.transfer(myWallet, myFeeWei);
            }
        }

        if (feeSharing != address(0)) {
          require(address(this).balance >= feeInWei);
          // transfer fee to feeSharing
          require(feeSharing.handleFees.value(feeInWei)(walletId));
        }

        return true;
    }
}
