//SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "./Ownable.sol";
import "./ERC20.sol";
contract MoneydefiSwap is ERC20("MoneydefiSwap","MSD"),Ownable{
    mapping(address=>bool)public Minter;
    constructor() public{
        _mint(msg.sender,99999981000000000000000000);

        
    }
    function AddMinter(address _minter)public onlyOwner{
        Minter[_minter]=true;
    }
    function RemoveMinter(address _minter)public onlyOwner{
        Minter[_minter]=false;
    }
    modifier onlyMinter{
        require(Minter[msg.sender]);
        _;
    }
 function mint(address account,uint256 amount) public onlyMinter{
     _mint(account,amount);
 }
 function burn(address account,uint256 amount) public onlyMinter{
     _burn(account,amount);
 }
}