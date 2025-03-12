// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

interface IBeanBag {
  // BEAN specific functions
  function safeLatteTransfer(address _account, uint256 _amount) external;
  function mint(address _to, uint256 _amount) external;
  function burn(address _from, uint256 _amount) external;
}