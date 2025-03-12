// SPDX-License-Identifier: MIT
pragma solidity =0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract JamonShare is ERC20, ERC20Burnable, Ownable, ERC20Permit, ERC20Votes {
    
    using EnumerableSet for EnumerableSet.AddressSet;  
    using SafeMath for uint256;

    EnumerableSet.AddressSet private taxExent;

    constructor() ERC20("JamonShare", "J-SHARE") ERC20Permit("JamonShare") {
        _mint(msg.sender, 2000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function setExent(address exent, bool set) external onlyOwner {
        require(exent != address(0x0), "Invalid address");
        if(set){
            taxExent.add(exent);
        } else {
            taxExent.remove(exent);
        }
    }

    // The following functions are overrides required by Solidity.
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        if(!taxExent.contains(_msgSender())) {
            uint256 toBurn = amount.mul(50).div(10000); // 0.5% tax burn
            _burn(_msgSender(), toBurn);
            amount -= toBurn;
        }
        _transfer(_msgSender(), recipient, amount);
        return true;
    } 

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}