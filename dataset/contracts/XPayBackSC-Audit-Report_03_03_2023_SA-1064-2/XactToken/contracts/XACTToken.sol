// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract XactToken is ERC20Capped, Ownable {
    // Maximum Supply is capped to ten billion
    constructor(address multisigWallet) ERC20("XactToken", "XACT") ERC20Capped(10000000000  * 10 ** decimals()) {
        // Minting 1% of the Max Supply at the time of deployment
        _mint(multisigWallet, 100000000 * 10 ** decimals());
        // Transefferring ownership of contract to team multisig wallet at the time of deployment
        _transferOwnership(multisigWallet);
    }

    // Only the owner of the contract is allowed to mint new tokens
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount * 10 ** decimals());
    }
}
