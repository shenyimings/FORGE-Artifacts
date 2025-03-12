pragma solidity ^0.8.0;


contract UniswapV2PoolMock {

    uint112 _reserve0;
    uint112 _reserve1;


    constructor(uint112 reserve0, uint112 reserve1) {
        _reserve0 = reserve0 * 10 ** 18;
        _reserve1 = reserve1 * 10 ** 18;
    }

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        blockTimestampLast = uint32(block.timestamp);
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }
}