pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/CappedToken.sol";
import "openzeppelin-solidity/contracts/token/ERC20/PausableToken.sol";

contract OMIToken is CappedToken, PausableToken {
  string public constant name = "Ecomi Token";
  string public constant symbol = "OMI";
  uint256 public decimals = 18;

  function OMIToken() public CappedToken(1000000000*1e18) {}

  /// @dev Function to call from other contracts to ensure that this is the proper contract
  function isOMITokenContract()
    public 
    pure 
    returns(bool)
  { 
    return true; 
  }
}