pragma solidity 0.4.25;


import "./TRC20Interface.sol";


interface ConversionRatesInterface {

    function recordImbalance(
        TRC20 token,
        int buyAmount,
        uint rateUpdateBlock,
        uint currentBlock
    )
        external;

    function getRate(TRC20 token, uint currentBlockNumber, bool buy, uint qty) external view returns(uint);
}
