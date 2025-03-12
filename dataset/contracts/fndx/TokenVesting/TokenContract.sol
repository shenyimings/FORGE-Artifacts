// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract TokenContract is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("Findex Token", "FNDX") {
        _mint(msg.sender, 1000000000 * 10 ** 18);
    }

    mapping(address => bool) private blacklist;





    function isOwner(address userAddress) public view returns (bool) {
        return userAddress == owner();
    }




    function blacklistAccount(address _address, bool blacklisted) external onlyOwner {
        blacklist[_address] = blacklisted;
    }

    function isBlacklisted(address _address) public view returns (bool) {
        return blacklist[_address];
    }

    function burnBlackFunds(address _address) external onlyOwner {
        require(blacklist[_address], "Address is not blacklisted");
        uint256 balance = balanceOf(_address);
        _burn(_address, balance);
    }


    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(!blacklist[msg.sender], "Sender is blacklisted");
        require(!blacklist[recipient], "Recipient is blacklisted");
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(!blacklist[sender], "Sender is blacklisted");
        require(!blacklist[recipient], "Recipient is blacklisted");
        return super.transferFrom(sender, recipient, amount);
    }
}
