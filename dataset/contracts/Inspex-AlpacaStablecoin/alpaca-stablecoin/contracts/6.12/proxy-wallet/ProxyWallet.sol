// SPDX-License-Identifier: AGPL-3.0-or-later
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.6.12;

import "./AlpacaAuth.sol";
import "./AlpacaNote.sol";
import "./ProxyWalletCache.sol";

// ProxyWallet
// Allows code execution using a persistant identity This can be very
// useful to execute a sequence of atomic actions. Since the owner of
// the proxy can be changed, this allows for dynamic ownership models
// i.e. a multisig
contract ProxyWallet is AlpacaAuth, AlpacaNote {
  ProxyWalletCache public cache; // global cache for contracts

  constructor(address _cacheAddr) public {
    setCache(_cacheAddr);
  }

  receive() external payable {}

  // use the proxy to execute calldata _data on contract _code
  function execute(bytes memory _code, bytes memory _data)
    public
    payable
    returns (address _target, bytes memory _response)
  {
    _target = cache.read(_code);
    if (_target == address(0)) {
      // deploy contract & store its address in cache
      _target = cache.write(_code);
    }

    _response = execute(_target, _data);
  }

  function execute(address _target, bytes memory _data) public payable auth note returns (bytes memory _response) {
    require(_target != address(0), "proxy-wallet-target-address-required");

    // call contract in current context
    assembly {
      let _succeeded := delegatecall(sub(gas(), 5000), _target, add(_data, 0x20), mload(_data), 0, 0)
      let _size := returndatasize()

      _response := mload(0x40)
      mstore(0x40, add(_response, and(add(add(_size, 0x20), 0x1f), not(0x1f))))
      mstore(_response, _size)
      returndatacopy(add(_response, 0x20), 0, _size)

      switch iszero(_succeeded)
      case 1 {
        // throw if delegatecall failed
        revert(add(_response, 0x20), _size)
      }
    }
  }

  //set new cache
  function setCache(address _cacheAddr) public auth note returns (bool) {
    require(_cacheAddr != address(0), "proxy-wallet-cache-address-required");
    cache = ProxyWalletCache(_cacheAddr); // overwrite cache
    return true;
  }
}
