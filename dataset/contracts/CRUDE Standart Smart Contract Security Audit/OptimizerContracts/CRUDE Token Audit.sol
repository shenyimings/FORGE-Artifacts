
pragma solidity ^0.6.2;
contract CrudeToken is ERC20 {
    address public owner;
    mapping(address=>bool) public minters;
    constructor () public ERC20("CrudeToken", "CRUDE") {
        _mint(msg.sender, 15000 * (10 ** uint256(decimals())));
        owner = msg.sender;
    }
    
    function mint(address _user, uint256 _amount) external{
        require(minters[msg.sender]==true,"Only minter function");
        _mint(_user,_amount);
    }
    
    function addMinter(address _minter) external{
         require(msg.sender==owner,"Only owner function");
         minters[_minter] = true;
    }


    function removeMinter(address _minter) external{
         require(msg.sender==owner,"Only owner function");
         minters[_minter] = false;
    }

    function burn(uint256 _amount) external{
        _burn(msg.sender,_amount);
    }
}