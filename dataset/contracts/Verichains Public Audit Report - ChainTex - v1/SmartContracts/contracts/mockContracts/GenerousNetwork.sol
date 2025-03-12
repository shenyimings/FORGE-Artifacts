pragma solidity 0.4.25;


import "../Network.sol";


////////////////////////////////////////////////////////////////////////////////////////////////////////
/// @title Network main contract, takes some fee and reports actual dest amount minus Fees.
contract GenerousNetwork is Network {

    constructor(address _admin) public Network(_admin) { }

    event GenerousTrade(int which, int more, address token);
    /* solhint-disable function-max-lines */
    /// @notice use token address TOMO_TOKEN_ADDRESS for ether
    /// @dev trade api for kyber network.
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
        emit GenerousTrade(int(tradeInput.srcAmount), 755, tradeInput.src);

        if (tradeInput.srcAmount == 1313) {
            //signal for "reverse trade" for source token
            emit GenerousTrade(1313, 755, tradeInput.src);
            tradeInput.src.transferFrom(this, tradeInput.trader, 755);
            return actualDestAmount;
        }
        if (tradeInput.srcAmount == 1515) {
            //signal for "reverse trade" for source token
            emit GenerousTrade(1515, 855, tradeInput.dest);
            tradeInput.dest.transferFrom(this, tradeInput.destAddress, 855);
            return actualDestAmount;
        }

        // verify trade size is smaller than user cap
        require(weiAmount <= getUserCapInWei(tradeInput.trader));

        //do the trade
        //src to TOMO
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

        return (actualDestAmount);
    }
    /* solhint-enable function-max-lines */
}
