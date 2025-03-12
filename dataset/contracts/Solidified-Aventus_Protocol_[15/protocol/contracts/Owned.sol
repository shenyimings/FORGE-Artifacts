pragma solidity 0.5.12;

contract Owned {
  
  address public owner = msg.sender;

  modifier onlyOwner {
    require(msg.sender == owner, "Sender must be owner");
    _;
  }

  function setOwner(address _owner)
    public
    onlyOwner
  {
    require(_owner != address(0), "Owner cannot be zero address");
    owner = _owner;
  }
}