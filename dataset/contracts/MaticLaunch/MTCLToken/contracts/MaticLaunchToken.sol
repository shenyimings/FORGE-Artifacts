// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MaticLaunchToken is ERC20Burnable, ERC20Pausable, ERC20Capped, Ownable {
    uint256 constant SUPPLY = 20e6 ether;
    
    constructor() ERC20("MaticLaunch", "MTCL") ERC20Capped(SUPPLY) {
        ERC20._mint(_msgSender(), SUPPLY);
    }

    function togglePause() public onlyOwner {
        paused() ? _unpause() : _pause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        super._mint(account, amount);
    }
}