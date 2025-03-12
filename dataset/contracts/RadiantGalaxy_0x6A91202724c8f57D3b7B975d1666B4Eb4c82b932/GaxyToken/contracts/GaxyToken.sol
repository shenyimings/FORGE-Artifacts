// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
/**
   ____    _    __  ____   __
  / ___|  / \   \ \/ /\ \ / /
 | |  _  / _ \   \  /  \ V / 
 | |_| |/ ___ \  /  \   | |  
  \____/_/   \_\/_/\_\  |_|  
 */
contract GaxyToken is ERC20, ERC20Burnable, Ownable, Pausable {
    
    using SafeMath for uint;

    uint256 private totalTokens;

    constructor() ERC20("Radiant Galaxy", "GAXY") {
        totalTokens = 1 * 10 ** 9 * 10 ** uint256(decimals()); 
        _mint(owner(), totalTokens);  
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override(ERC20)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function getBurnedAmountTotal() external view returns (uint256 _amount) {
        return totalTokens.sub(totalSupply());
    }
}