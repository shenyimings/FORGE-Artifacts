pragma solidity 0.4.25;

import "./TRC20Interface.sol";


/// @title simple interface for Network
interface SimpleNetworkInterface {
    function swapTokenToToken(TRC20 src, uint srcAmount, TRC20 dest, uint minConversionRate) external returns(uint);
    function swapTomoToToken(TRC20 token, uint minConversionRate) external payable returns(uint);
    function swapTokenToTomo(TRC20 token, uint srcAmount, uint minConversionRate) external returns(uint);
}
