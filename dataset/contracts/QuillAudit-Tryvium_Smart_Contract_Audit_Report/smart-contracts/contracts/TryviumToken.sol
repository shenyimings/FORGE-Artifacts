// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

import "./token-vaults/TokenVault.sol";
import "./token-vaults/BountyVault.sol";

/**
 * @notice This is the definition of the Tryvium ERC20 token.
 * @author Alessandro Sanino (@saniales)
 */
contract TryviumToken is ERC20, ERC20Burnable, ERC20Capped, Ownable {
    /**
     * @notice The current supply of the TRYV token.
     */
    uint256 private _tokenSupply;

    /**
     * @notice The address in which the Team reserved funds are sent.
     * They correspond to the % of the supply specified in the whitepaper.
     */
    TokenVault immutable public TEAM_VAULT;

    /**
     * @notice The address in which the Bounty reserved funds are sent.
     * They correspond to the % of the supply specified in the whitepaper.
     */
    BountyVault immutable public BOUNTY_VAULT;

    /**
     * @notice The address in which the various Token Sales reserved
     * funds are sent.
     * They correspond to the % of the supply specified in the whitepaper.
     */
    TokenVault immutable public SALES_VAULT;

    /**
     * @notice The address in which the funds reserved for future
     * developments are sent.
     * They correspond to the % of the supply specified in the whitepaper.
     */
    TokenVault immutable public RESERVED_FUNDS_VAULT;

    /**
     * @notice Creates a new instance of the Tryvium ERC20 Token contract and
     *      performs the minting of the tokens to the vaults specified in
     *      the whitepaper.
     * @param _maxSupply The token max supply.
     * @param _teamVault The address of the vault which will contain the
     *      tokens reserved to the Tryvium team.
     * @param _bountyVault The address of the vault which will contain the
     *      tokens reserved to the Tryvium bounties and airdrops.
     * @param _salesVault The address of the vault which will contain the
     *      tokens reserved to the Tryvium various token sales.
     * @param _reservedFundsVault The address of the vault which will contain the
     *      tokens reserved to the Tryvium project future developments.
     */
    constructor(
        uint256 _maxSupply,
        TokenVault _teamVault,
        BountyVault _bountyVault,
        TokenVault _salesVault,
        TokenVault _reservedFundsVault
    ) ERC20("Tryvium Token", "TRYV") ERC20Capped(_maxSupply) {
        _tokenSupply = _maxSupply;
        TEAM_VAULT = _teamVault;
        BOUNTY_VAULT = _bountyVault;
        SALES_VAULT = _salesVault;
        RESERVED_FUNDS_VAULT = _reservedFundsVault;

        ERC20._mint(address(_teamVault), _maxSupply * 10 / 100);
        ERC20._mint(address(_bountyVault), _maxSupply * 10 / 100);
        ERC20._mint(address(_salesVault), _maxSupply * 60 / 100);
        ERC20._mint(address(_reservedFundsVault), _maxSupply * 20 / 100);
    }

    /**
     * @notice Gets the current balance of the team vault.
     * @return The current balance of the team vault.
     */
    function getTeamVaultBalance() external view returns (uint256) {
        return this.balanceOf(address(TEAM_VAULT));
    }

    /**
     * @notice Gets the current balance of the bounty vault.
     * @return The current balance of the bounty vault.
     */
    function getBountyVaultBalance() external view returns (uint256) {
        return this.balanceOf(address(BOUNTY_VAULT));
    }

    /**
     * @notice Gets the current balance of the reserved funds vault.
     * @return The current balance of the reserved funds vault.
     */
    function getReservedFundsVaultBalance() external view returns (uint256) {
        return this.balanceOf(address(RESERVED_FUNDS_VAULT));
    }

    /**
     * @notice Gets the current balance of the sales vault.
     * @return The current balance of the sales vault.
     */
    function getSalesVaultBalance() external view returns (uint256) {
        return this.balanceOf(address(SALES_VAULT));
    }

    /** @notice Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - Cannot increase over the max supply.
     */
    function _mint(address account, uint256 amount) internal override (ERC20, ERC20Capped) {
        ERC20Capped._mint(account, amount);
    }

    /** @notice Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - Cannot increase over the max supply.
     */
    function mint(address account, uint256 amount) onlyOwner external {
        _mint(account, amount);
    }
}
