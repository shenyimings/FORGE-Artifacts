//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CRUSHToken is ERC20 ("Crush Coin", "CRUSH"), Ownable {

  using SafeMath for uint256;
  // Constants
  uint256 constant public MAX_SUPPLY = 30 * 10 ** 24; //30 million tokens are the max Supply
  
  // Variables
  uint256 public tokensBurned = 0;

  function mint(address _benefactor,uint256 _amount) public onlyOwner {
    uint256 draftSupply = _amount.add( totalSupply() );
    uint256 maxSupply = MAX_SUPPLY.sub( tokensBurned );
    require( draftSupply <= maxSupply, "can't mint more than max." );
    _mint(_benefactor, _amount);
  }

  function burn(uint256 _amount) public {
    tokensBurned = tokensBurned.add( _amount ) ;
    _burn( msg.sender, _amount );
  }

}