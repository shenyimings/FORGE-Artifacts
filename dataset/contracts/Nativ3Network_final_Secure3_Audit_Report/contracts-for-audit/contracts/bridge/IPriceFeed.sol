pragma solidity ^0.8.0;

interface IPriceFeed {
    
    function latestAnswer() external view returns (int256);

    function decimals() external view returns (uint8);
}
