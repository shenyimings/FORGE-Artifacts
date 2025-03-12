// SPDX-License-Identifier: ISC
//** Vapor Token */
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title Official Vapor Token
/// @author VaporWallet - info@vaporwallet.co
/// @dev A token based on OpenZeppelin's principles

contract VPRToken is ERC20Burnable {
    /// @notice A constructor that mint the tokens
    constructor() ERC20("Vapor Token", "VPR") {
        _mint(msg.sender, 1_000_000_000 * 10 ** decimals());
    }
}
