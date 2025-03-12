pragma solidity 0.4.25;


import "../Network.sol";


////////////////////////////////////////////////////////////////////////////////////////////////////////
/// @title Network main contract that doesn't check max dest amount. so we can test it on proxy
contract NetworkNoMaxDest is Network {

    constructor(address _admin) public Network(_admin) { }

    function calcActualAmounts (TRC20 src, TRC20 dest, uint srcAmount, uint maxDestAmount, BestRateResult rateResult)
        internal view returns(uint actualSrcAmount, uint weiAmount, uint actualDestAmount)
    {
        src;
        dest;
        maxDestAmount;

        actualDestAmount = rateResult.destAmount;
        actualSrcAmount = srcAmount;
        weiAmount = rateResult.weiAmount;
    }
}
