// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

interface IPool {
  function init(address registry_, bytes32 domain_) external returns (bool);
}
