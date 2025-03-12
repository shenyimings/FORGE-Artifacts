// SPDX-License-Identifier: MIT

// Ecobonus.io | The bridge between people and recycling companies
// Total supply is 8 billion tokens, one for each person on the planet 

pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Ecobonus is Ownable, ERC20 {

    constructor() ERC20("Ecobonus", "ECB") {
        _mint(msg.sender, 8_000_000_000 * 1e18);
    }

    // Withdraw ERC20 tokens that are potentially stuck in Contract
    function recoverTokensFromContract(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(0), "Cannot provide the zero address as parameter");

        bool success = IERC20(tokenAddress).transfer(owner(), amount);
        require(success, "Transfer failed");
    }

    function burn(uint256 value) external {
        _burn(msg.sender, value);
    }
}