// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IBlacklist {

  event AddBlacklist(address indexed account, address indexed caller);
  event RevokeBlacklist(address indexed account, address indexed caller);

  function blacklist(address account) external view returns (bool);

  function addBlacklist(address account) external;

  function revokeBlacklist(address account) external;
}