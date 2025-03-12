// File: contracts\interfaces\IWETH.sol

pragma solidity >=0.5.0 < 0.6.7;

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}