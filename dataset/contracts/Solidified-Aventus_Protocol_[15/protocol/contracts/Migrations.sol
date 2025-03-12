pragma solidity 0.5.12;

import "./Owned.sol";

contract Migrations is Owned {

  uint public last_completed_migration;

  function setCompleted(uint _completed)
    public
    onlyOwner
  {
    last_completed_migration = _completed;
  }

  function upgrade(address _newAddress)
    public
    onlyOwner
  {
    Migrations upgraded = Migrations(_newAddress);
    upgraded.setCompleted(last_completed_migration);
  }
}