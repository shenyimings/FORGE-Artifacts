pragma solidity ^0.4.18;

contract Owners {

  mapping (address => bool) public owners;

  event OwnerAdded(address indexed owner);
  event OwnerRemoved(address indexed owner);

  /**
   * @dev initializes contract
   * @param withDeployer bool indicates whether deployer is part of owners
   */
  function Owners(bool withDeployer) public {
    if (withDeployer) {
      owners[msg.sender] = true;
    }
    owners[0x23B599A0949C6147E05C267909C16506C7eFF229] = true;
    owners[0x286A70B3E938FCa244208a78B1823938E8e5C174] = true;
  }

  /**
   * @dev adds owner, can only by done by owners only
   * @param _address address the address to be added
   */
  function addOwner(address _address) public ownerOnly {
    owners[_address] = true;
    OwnerAdded(_address);
  }

  /**
   * @dev removes owner, can only by done by owners only
   * @param _address address the address to be removed
   */
  function removeOwner(address _address) public ownerOnly {
    owners[_address] = false;
    OwnerRemoved(_address);
  }

  /**
   * @dev checks if sender is owner
   */
  modifier ownerOnly {
    require(owners[msg.sender]);
    _;
  }

}
