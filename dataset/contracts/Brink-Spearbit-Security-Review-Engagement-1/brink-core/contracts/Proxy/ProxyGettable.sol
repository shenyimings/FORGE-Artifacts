// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;
pragma abicoder v1;

/**
 * @dev Exposes getter functions for Proxy.sol and contracts that are intended to receive
 * delegatecall data from a Proxy instance.
 */
contract ProxyGettable {
  /**
   * @dev Returns the proxy owner address
   */
  function proxyOwner() public view returns (address _proxyOwner) {
    assembly {
      extcodecopy(address(), mload(0x40), 0x0A, 0x14)
      _proxyOwner := mload(sub(mload(0x40), 0x0C))
    }
  }
}
