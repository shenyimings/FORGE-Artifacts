pragma solidity ^0.8.9;

import "https://github.com/CandleBets/openzeppelin-contracts/blob/release-v4.4/contracts/token/ERC20/ERC20.sol";

contract OwnersERC20 is
ERC20
{

    // address of the owner
    address private owner;
    
    // checks weather the caller is the owner or not
    modifier isOwner(address _address){
        require(_address == owner, "FinalERC20: Only owner allowed!");
        _;
    }
    
    /* @dev Initializes the total supply and some meta details of the token
    */
    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) ERC20(_name, _symbol)
    {
        owner = msg.sender;    
        _mint(owner, _initialSupply*(10**18));
    }
    
    
    /* @dev mint new tokens in the owners account
    */
    function mint(uint256 _amount)
    public 
    isOwner(msg.sender)
    {
        _mint(msg.sender, _amount);
    }
    
    
    /* @dev burn the tokens from the owners account
    */
    function burn(uint256 _amount)
    public 
    isOwner(msg.sender)
    {
        _burn(msg.sender, _amount);
    }
}
