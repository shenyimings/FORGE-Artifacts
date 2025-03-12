pragma solidity 0.4.25;


import "./TRC20Interface.sol";

/// @title Reserve contract
interface ReserveInterface {

    function trade(
        TRC20 srcToken,
        uint srcAmount,
        TRC20 destToken,
        address destAddress,
        uint conversionRate,
        uint feeInWei,
        bool validate
    )
        external
        payable
        returns(bool);

    function getConversionRate(TRC20 src, TRC20 dest, uint srcQty, uint blockNumber) external view returns(uint);
}
