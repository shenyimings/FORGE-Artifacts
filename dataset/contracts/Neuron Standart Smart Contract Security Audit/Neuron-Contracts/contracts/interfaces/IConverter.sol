pragma solidity 0.8.9;

interface IConverter {
    function convert(address) external returns (uint256);
}
