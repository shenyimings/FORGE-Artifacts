// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ILpManager {
    function addLiquidity(address _lp, address _token, uint256 _amount, uint256 _minlp) external payable returns (uint256);
    function removeLiquidity(address _lp, uint256 _lpAmount, address _tokenOutOri, uint256 _minOut) external payable returns (uint256);
}