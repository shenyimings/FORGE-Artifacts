pragma solidity ^0.8.0;

/**
 * @dev Interface of gamejam .
 */
interface IOracle {
    function GetRate(address tokenAddress) external view returns (uint256);
    function setRate(address[] memory tokenAddrs, uint256[] memory rate) external;
}
