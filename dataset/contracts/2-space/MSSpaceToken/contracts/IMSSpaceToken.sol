// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMSSpaceToken {
    function msIsApprove(address owner, address spender) external view returns(bool);
    function msMint(address recipient, uint256 amount) external returns (bool);
    function msBurn(address _who,uint256 _amount) external;
    function msGetBalanceOf(address ofuser_)  view external returns(uint256);
    function msTransfer(address recipient, uint256 amount) external returns (bool);
    function msTransferFrom(address sender,address recipient, uint256 amount) external returns (bool);
}