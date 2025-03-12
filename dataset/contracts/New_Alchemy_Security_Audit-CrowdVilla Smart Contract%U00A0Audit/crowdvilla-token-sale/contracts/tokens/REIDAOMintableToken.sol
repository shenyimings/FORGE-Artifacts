pragma solidity ^0.4.18;

import './MintableToken.sol';

contract REIDAOMintableToken is MintableToken {

  uint public decimals = 8;

  bool public tradingStarted = false;

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint _value) public canTrade returns (bool) {
    return super.transfer(_to, _value);
  }

  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint _value) public canTrade returns (bool) {
    return super.transferFrom(_from, _to, _value);
  }

  /**
   * @dev modifier that throws if trading has not started yet
   */
  modifier canTrade() {
    require(tradingStarted);
    _;
  }

  /**
   * @dev Allows the owner to enable the trading. Done only once.
   */
  function startTrading() public ownerOnly {
    tradingStarted = true;
  }
}
