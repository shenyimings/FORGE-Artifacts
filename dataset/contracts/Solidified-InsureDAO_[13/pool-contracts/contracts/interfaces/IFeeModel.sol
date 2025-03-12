pragma solidity ^0.6.0;

interface IFeeModel {
    function getFee(uint256 _premium) external view returns (uint256);
}
