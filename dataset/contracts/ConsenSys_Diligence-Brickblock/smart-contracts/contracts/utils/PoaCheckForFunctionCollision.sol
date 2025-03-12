pragma solidity 0.4.24;

import "../PoaCrowdsale.sol";
import "../PoaToken.sol";


/**
  @title This contract is never deployed; we are letting the compiler tell us if there is ever a
         function signature collision between PoaCrowdsale and PoaToken.

         To understand more about what this means, this article does a good job explaining it
         https://medium.com/nomic-labs-blog/malicious-backdoors-in-ethereum-proxies-62629adf3357

         An example of a failing contract is

pragma solidity "0.4.25";

contract M1 {
    function clash550254402() public { }
}

contract M2 {
    function proxyOwner() public { }
}

contract Child is M1, M2 { }

*/

contract PoaCheckForFunctionCollision is PoaCrowdsale, PoaToken {
  constructor() public {
    // here so solium doesn't complain about an empty contract
  }
}
