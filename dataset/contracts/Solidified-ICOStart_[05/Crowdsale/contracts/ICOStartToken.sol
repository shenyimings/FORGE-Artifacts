pragma solidity ^0.4.21;

import "./zeppelin-solidity/contracts/token/ERC20/BurnableToken.sol";
import "./zeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "./zeppelin-solidity/contracts/token/ERC20/DetailedERC20.sol";
import "./LockableWhitelisted.sol";

contract ICOStartToken is BurnableToken, MintableToken, DetailedERC20, LockableWhitelisted {

  uint256 constant internal DECIMALS = 18;
  uint256 constant internal INITIAL_SUPPLY = 60000000 * 10 ** DECIMALS;

  function ICOStartToken (uint256 _initialSupply) public
    BurnableToken()
    MintableToken()
    DetailedERC20('ICOStart Token', 'ICH', uint8(DECIMALS))
    LockableWhitelisted()
   {
    require(_initialSupply > 0);
    mint(owner, _initialSupply);
    finishMinting();
    addAddressToWhitelist(owner);
    lock();
  }

  function transfer(address _to, uint256 _value) public whenNotLocked(msg.sender) returns (bool) {
    return super.transfer(_to, _value);
  }

  function transferFrom(address _from, address _to, uint256 _value) public whenNotLocked(_from) returns (bool) {
    return super.transferFrom(_from, _to, _value);
  }

  function approve(address _spender, uint256 _value) public whenNotLocked(msg.sender) returns (bool) {
    return super.approve(_spender, _value);
  }

  function increaseApproval(address _spender, uint _addedValue) public whenNotLocked(msg.sender) returns (bool success) {
    return super.increaseApproval(_spender, _addedValue);
  }

  function decreaseApproval(address _spender, uint _subtractedValue) public whenNotLocked(msg.sender) returns (bool success) {
    return super.decreaseApproval(_spender, _subtractedValue);
  }

  function transferOwnership(address _newOwner) public onlyOwner {
    if (owner != _newOwner) {
      addAddressToWhitelist(_newOwner);
      removeAddressFromWhitelist(owner);
    }
    super.transferOwnership(_newOwner);
  }

  /**
  * @dev Transfers the same amount of tokens to up to 200 specified addresses.
  * If the sender runs out of balance then the entire transaction fails.
  * @param _to The addresses to transfer to.
  * @param _value The amount to be transferred to each address.
  */
  function airdrop(address[] _to, uint256 _value) public whenNotLocked(msg.sender)
  {
    require(_to.length <= 200);
    require(balanceOf(msg.sender) >= _value.mul(_to.length));

    for (uint i = 0; i < _to.length; i++)
    {
      if (!transfer(_to[i], _value))
      {
        revert();
      }
    }
  }

  /**
  * @dev Transfers a variable amount of tokens to up to 200 specified addresses.
  * If the sender runs out of balance then the entire transaction fails.
  * For each address a value must be specified.
  * @param _to The addresses to transfer to.
  * @param _values The amounts to be transferred to the addresses.
  */
  function multiTransfer(address[] _to, uint256[] _values) public whenNotLocked(msg.sender)
  {
    require(_to.length <= 200);
    require(_to.length == _values.length);

    for (uint i = 0; i < _to.length; i++)
    {
      if (!transfer(_to[i], _values[i]))
      {
        revert();
      }
    }
  }

}
