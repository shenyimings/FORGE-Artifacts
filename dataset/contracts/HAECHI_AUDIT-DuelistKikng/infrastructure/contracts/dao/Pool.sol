// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '../libraries/RegistryUser.sol';
import '../interfaces/IPool.sol';

/**
 * Profit Pool
 * Name: Pool
 * Domain: DKDAO, *
 */
contract Pool is RegistryUser, Ownable, IPool {
  // Use address lib for address
  using Address for address;

  function init(address registry_, bytes32 domain_) external override returns (bool) {
    _registryUserInit(registry_, domain_);
    return true;
  }

  /*******************************************************
   * Same domain section
   ********************************************************/

  // Transfer native token to target address
  function transferValue(address payable target, uint256 value) external onlyAllowSameDomain('DAO') returns (bool) {
    target.transfer(value);
    return true;
  }

  // Safe call to a target address with a given payload
  function safeCall(
    address target,
    uint256 value,
    bytes memory data
  ) external onlyAllowSameDomain('DAO') returns (bool) {
    target.functionCallWithValue(data, value);
    return true;
  }

  // Delegatecall to a target address with given payload
  function safeDelegateCall(address target, bytes calldata data) external onlyAllowSameDomain('DAO') returns (bool) {
    target.functionDelegateCall(data);
    return true;
  }
}
