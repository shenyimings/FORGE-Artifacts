pragma solidity 0.5.16;

interface ITokenPermission {
    function getRefuelTokenPermission() external view returns (address);
    function getRefuelTokenAmount() external view returns (uint256);
    function getTerminateTokenPermission() external view returns (address);
    function getTerminateTokenAmount() external view returns (uint256);
}