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

import "../interfaces/IAuth.sol";

contract AlpacaAuthEvents {
  event LogSetAuthority(address indexed _authority);
  event LogSetOwner(address indexed _owner);
}

contract AlpacaAuth is AlpacaAuthEvents {
  IAuthority public authority;
  address public owner;

  constructor() public {
    owner = msg.sender;
    emit LogSetOwner(msg.sender);
  }

  function setOwner(address _owner) public auth {
    owner = _owner;
    emit LogSetOwner(owner);
  }

  function setAuthority(IAuthority _authority) public auth {
    authority = _authority;
    emit LogSetAuthority(address(authority));
  }

  modifier auth() {
    require(isAuthorized(msg.sender, msg.sig), "alpaca-auth-unauthorized");
    _;
  }

  function isAuthorized(address _src, bytes4 _sig) internal view returns (bool) {
    if (_src == address(this)) {
      return true;
    } else if (_src == owner) {
      return true;
    } else if (address(authority) == address(0)) {
      return false;
    } else {
      return authority.canCall(_src, address(this), _sig);
    }
  }
}
