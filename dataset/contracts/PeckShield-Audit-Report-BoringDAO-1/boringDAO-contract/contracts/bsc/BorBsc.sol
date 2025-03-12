// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BorBSC is ERC20, Ownable{


    address public minter;

    event ToEthereum(address from, address recipient, uint amount);

    constructor(string memory _name, string memory _symbol, address _minter) ERC20(_name, _symbol) public {
        minter = _minter;
    }

    function setMinter(address account) public onlyOwner {
        minter = account;
    }

    function mint(address recepient, uint amount) public {
        require(msg.sender == minter, "BorBSC::mint:only minter can mint");
        _mint(recepient, amount);
    }

    function burnToEthereum(address recipient, uint amount) public {
        _burn(msg.sender, amount);
        emit ToEthereum(msg.sender, recipient, amount);
    }

}