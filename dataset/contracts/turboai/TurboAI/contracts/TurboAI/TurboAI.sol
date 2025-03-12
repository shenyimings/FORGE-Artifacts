// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TurboAI is ERC20, ERC20Burnable, Ownable {
    uint256 private constant INITIAL_SUPPLY = 69000000000 * 10 ** 18;

    constructor() ERC20("TurboAI", "TURBOAI") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function distributeTokens(address distributionWallet) external onlyOwner {
        uint256 supply = balanceOf(msg.sender);
        require(supply == INITIAL_SUPPLY, "Tokens already distributed");

        _transfer(msg.sender, distributionWallet, supply);
    }
}
