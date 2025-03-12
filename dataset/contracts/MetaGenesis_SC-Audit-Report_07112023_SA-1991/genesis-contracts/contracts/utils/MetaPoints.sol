// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../helpers/RolesHandler.sol";

/**
 * @title MetaPoints
 * @dev A custom ERC20 token contract that implements roles and pausable features.
 */
contract MetaPoints is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable,
    RolesHandler
{
    /// @notice custom errors for prohibited functions
    error BurnDisabled(uint256 amount);
    error TransferDisabled(address to, uint256 amount);
    error TransferFromDisabled(address from, address to, uint256 amount);

    /**
     * @dev Initializes the MetaPoints contract with token name and symbol.
     */
    function initialize() public initializer {
        __ERC20_init("Meta Points", "MP");
        __ERC20Burnable_init();
        __Pausable_init();
    }

    /**
     * @dev Pauses the token transfers, can only be called by an owner.
     */
    function pause() public onlyOwnerRole(_msgSender()) {
        _pause();
    }

    /**
     * @dev Unpauses the token transfers, can only be called by an owner.
     */
    function unpause() public onlyOwnerRole(_msgSender()) {
        _unpause();
    }

    /**
     * @dev Mints new Meta Points and sends them to the specified address, can only be called by a manager.
     * @param to The address to receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(
        address to,
        uint256 amount
    ) public whenNotPaused onlyManagerRole(_msgSender()) {
        _mint(to, amount);
    }

    /**
     * @dev Disables the burn function, preventing token holders from burning their tokens.
     * @param amount The amount of tokens to burn.
     */
    function burn(uint256 amount) public virtual override {
        revert BurnDisabled(amount);
    }

    /**
     * @dev Burns tokens from an account, can only be called by a manager.
     * @param account The address from which to burn tokens.
     * @param amount The amount of tokens to burn.
     */
    function burnFrom(
        address account,
        uint256 amount
    ) public virtual override onlyManagerRole(_msgSender()) {
        _burn(account, amount);
    }

    /**
     * @dev Disables the transfer function, preventing token holders from transferring their tokens.
     * @param to The address to which tokens should be transferred.
     * @param amount The amount of tokens to transfer.
     * @return false
     */
    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        revert TransferDisabled(to, amount);
    }

    /**
     * @dev Approves a spender to spend tokens on behalf of the sender, when not paused.
     * @param spender The address allowed to spend the sender's tokens.
     * @param amount The maximum amount the spender can spend.
     * @return true if the approval is successful.
     */
    function approve(
        address spender,
        uint256 amount
    ) public virtual override whenNotPaused returns (bool) {
        return super.approve(spender, amount);
    }

    /**
     * @dev Disables the transferFrom function, preventing the transfer of tokens between addresses.
     * @param from The address from which tokens would be transferred.
     * @param to The address to which tokens would be transferred.
     * @param amount The amount of tokens to transfer.
     * @return false
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        revert TransferFromDisabled(from, to, amount);
    }

    /**
     * @dev Hook called before any token transfer to ensure that the token is not paused.
     * @param from The address from which tokens are transferred.
     * @param to The address to which tokens are transferred.
     * @param amount The amount of tokens to transfer.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}
