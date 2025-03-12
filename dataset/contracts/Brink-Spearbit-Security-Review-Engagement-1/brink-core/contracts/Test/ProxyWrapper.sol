// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;
pragma abicoder v1;

import "../Proxy/Proxy.sol";

contract ProxyWrapper is Proxy {
  function accountImplementation() external pure returns (address) {
    return ACCOUNT_IMPLEMENTATION;
  }

  function proxyOwner() external pure returns (address) {
    return OWNER;
  }
}
