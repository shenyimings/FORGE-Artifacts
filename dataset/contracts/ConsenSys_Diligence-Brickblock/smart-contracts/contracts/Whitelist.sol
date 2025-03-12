pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";


contract Whitelist is Pausable {
  uint8 public constant version = 1;

  mapping (address => bool) private whitelistedMap;

  event Whitelisted(address indexed account, bool isWhitelisted);

  function whitelisted(address _address)
    public
    view
    returns (bool)
  {
    if (paused) {
      return false;
    }

    return whitelistedMap[_address];
  }

  function addAddress(address _address)
    public
    onlyOwner
  {
    require(whitelistedMap[_address] != true);
    whitelistedMap[_address] = true;
    emit Whitelisted(_address, true);
  }

  function removeAddress(address _address)
    public
    onlyOwner
  {
    require(whitelistedMap[_address] != false);
    whitelistedMap[_address] = false;
    emit Whitelisted(_address, false);
  }
}
