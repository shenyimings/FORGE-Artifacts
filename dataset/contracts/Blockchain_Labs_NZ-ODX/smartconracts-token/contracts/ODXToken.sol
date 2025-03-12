pragma solidity ^0.4.23;

import "./CappedMintableToken.sol";
import "./StandardBurnableToken.sol";

/**
 * @title ODXToken
 * @dev Simple ERC20 Token,   
 * Tokens are mintable and burnable.
 * No initial token upon creation
 * Added max token supply
 */
contract ODXToken is CappedMintableToken, StandardBurnableToken {

  string public name; 
  string public symbol; 
  uint8 public decimals; 

  /**
   * @dev set totalSupply_ = 0;
   */
  constructor(
      string _name, 
      string _symbol, 
      uint8 _decimals, 
      uint256 _maxTokens
  ) 
    public 
    CappedMintableToken(_maxTokens) 
  {
    name = _name;
    symbol = _symbol;
    decimals = _decimals;
    totalSupply_ = 0;
  }
  
  function () payable public {
      revert();
  }

}
