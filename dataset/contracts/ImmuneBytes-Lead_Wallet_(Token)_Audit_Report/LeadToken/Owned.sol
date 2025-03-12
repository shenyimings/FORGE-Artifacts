pragma solidity >=0.5.0 < 0.6.0;

/**
 * @title Owned
 * Copied from OpenZeppelin/openzeppelin-contracts/blob/master/contracts/ownership/Ownable.sol
 * @dev The Owned contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
  
contract Owned {
    address public owner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

/**
  * @dev The Ownable constructor sets the original `owner` of the contract to the sender
  * account.
  */
  
    constructor() public {
        owner = msg.sender;
    }

/**
  * @dev Throws if called by any account other than the owner.
  */
  
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

/**
 * @dev Allows the current owner to transfer control of the contract to a newOwner.
 * @param _newOwner is the address to transfer ownership to.
 */
 
    function transferOwnership(address _newOwner) public onlyOwner {
        owner = _newOwner;
        emit OwnershipTransferred(owner, _newOwner); 
    }
}
