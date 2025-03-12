pragma solidity 0.4.25;

import "./TRC20Interface.sol";


/// @title Kyber Network interface
interface NetworkInterface {
    function maxGasPrice() external view returns(uint);
    function getUserCapInWei(address user) external view returns(uint);
    function getUserCapInTokenWei(address user, TRC20 token) external view returns(uint);
    function enabled() external view returns(bool);
    function info(bytes32 id) external view returns(uint);

    function getExpectedRate(TRC20 src, TRC20 dest, uint srcQty) external view
        returns (uint expectedRate, uint slippageRate);
    function getExpectedFeeRate(TRC20 token, uint srcQty) external view
        returns (uint expectedRate, uint slippageRate);

    function swap(address trader, TRC20 src, uint srcAmount, TRC20 dest, address destAddress,
        uint maxDestAmount, uint minConversionRate, address walletId) external payable returns(uint);
    function payTxFee(address trader, TRC20 src, uint srcAmount, address destAddress,
      uint maxDestAmount, uint minConversionRate) external payable returns(uint);
}
