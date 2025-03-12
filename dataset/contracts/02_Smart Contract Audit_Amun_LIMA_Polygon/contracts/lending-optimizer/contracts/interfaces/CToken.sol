pragma solidity ^0.6.12;

interface CToken {
    function exchangeRateStored() external view returns (uint256);
}
