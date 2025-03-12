// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./InitializedProxy.sol";
import "../core/TokenDistributor.sol";

contract TokenDistributorProxyManager is Ownable2StepUpgradeable {
  uint256 public poolCount;

  mapping(uint256 => address) private _pools;
  mapping(address => bool) private _whitelist;

  address public immutable logic;

  event PoolProxyCreated(address creatorAddress, address proxyAddress, uint256 proxyId);

  constructor() {
    _transferOwnership(_msgSender());

    logic = address(new TokenDistributor());
  }

  function getPoolProxy(uint256 proxyId) public view returns(address) {
    return _pools[proxyId];
  }

  function addToWhitelist(address proxyAddress) public onlyOwner returns(bool) {
    _whitelist[proxyAddress] = true;

    return true;
  } 

  function removeFromWhitelist(address proxyAddress) public onlyOwner returns(bool) {
    _whitelist[proxyAddress] = false;
    
    return true;
  }

  function createPoolProxy(
      string memory poolName, 
      address token, 
      uint256 startTime, 
      uint256 endTime, 
      uint256 distributionRate,
      uint256 period
    ) onlyOwner external returns(uint256) {
      bytes memory _initializationCalldata =
        abi.encodeWithSignature(
          "initialize(address,string,address,uint256,uint256,uint256,uint256)",
            _msgSender(),
            poolName,
            token,
            startTime,
            endTime,
            distributionRate,
            period
      );

      address poolProxy = address(
        new InitializedProxy(
          logic,
          _initializationCalldata
        )
      );

      emit PoolProxyCreated(_msgSender(), poolProxy, poolCount);
      _pools[poolCount] = poolProxy;
      poolCount++;

      _whitelist[poolProxy] = true;

      return poolCount - 1;
  }
}