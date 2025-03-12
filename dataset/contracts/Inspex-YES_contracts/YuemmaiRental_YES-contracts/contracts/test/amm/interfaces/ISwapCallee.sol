pragma solidity >=0.5.0 < 0.6.7;

interface ISwapCallee {
    function blockSwapCall(address sender, uint amount0, uint amount1, bytes calldata data) external;
}