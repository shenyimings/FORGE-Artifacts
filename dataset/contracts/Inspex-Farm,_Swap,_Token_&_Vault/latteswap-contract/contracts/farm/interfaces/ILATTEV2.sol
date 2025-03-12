// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

interface ILATTEV2 {
  // LATTE specific functions
  function lock(address _account, uint256 _amount) external;

  function lockOf(address _account) external view returns (uint256);

  function unlock() external;

  function mint(address _to, uint256 _amount) external;

  function claimLock(
    uint256 _index,
    address _account,
    uint256 _amount,
    bytes32[] calldata _merkleProof
  ) external;

  function redeem(uint256 _amount) external;

  // Generic BEP20 functions
  function totalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

  function allowance(address owner, address spender) external view returns (uint256);

  function approve(address spender, uint256 amount) external returns (bool);

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);

  // Getter functions
  function startReleaseBlock() external returns (uint256);

  function endReleaseBlock() external returns (uint256);

  function isClaimed(uint256 _index) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}
