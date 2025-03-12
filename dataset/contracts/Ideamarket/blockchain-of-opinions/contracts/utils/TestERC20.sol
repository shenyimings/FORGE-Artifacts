// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TestERC20
 * @author Alexander Schlindwein
 *
 * @dev ERC20 token for testing. Supports public minting/burning
 */
contract TestERC20 is ERC20 {

    /**
     * @dev Tokens are always created with 18 decimals
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     */
    constructor (string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    /**
     * @dev Mints a given amount of tokens to an address.
     * @param account The account to receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    /**
     * @dev Burns a given amount of tokens from an address.
     * @param account The account for the tokens to be burned from
     * @param amount The amount of tokens to be burned
     */
    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}