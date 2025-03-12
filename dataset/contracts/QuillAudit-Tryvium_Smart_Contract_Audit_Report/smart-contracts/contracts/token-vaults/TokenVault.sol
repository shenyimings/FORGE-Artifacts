// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title The Tryvium Token Vault contract.
 * @notice This contract allows to hold tokens and provide
 * a reason about all transfers, to inform the community about
 * each token transfer from the vault in a verifiable and
 * trusted way.
 */
contract TokenVault is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /**
     * @notice The event representing a token transfer
     * out of the vault, along with an attached reason
     * (e.g. "Airdrop #1234").
     * @param _token The transfered ERC20 token.
     * @param _amount The transfered amount.
     * @param _to The destination address.
     * @param _reason The reason of the transfer.
     */
    event VaultTokenTransfer(
        IERC20 indexed _token,
        uint256 indexed _amount,
        address indexed _to,
        string _reason
    );

    /**
     * @notice The event representing a transfer out
     * of the vault, along with an attached reason
     * (e.g. "Payment #1234 for reason X").
     * @param _amount The transferred amount.
     * @param _to The destination address.
     * @param _reason The reason of the transfer.
     */
    event VaultTransfer(
        uint256 indexed _amount,
        address indexed _to,
        string _reason
    );

    constructor() ReentrancyGuard() Ownable() {}

    /**
     * @notice transfers specified ERC20 tokens out of the vault.
     * @param _token The ERC20 token to transfer.
     * @param _amount The amount to transfer.
     * @param _to The destination address.
     * @param _reason The reason of the transfer.
     */
    function transferTokens(
        IERC20 _token,
        uint256 _amount,
        address _to,
        string calldata _reason
    ) external onlyOwner nonReentrant {
        _vaultTokenTransfer(_token, _amount, _to, _reason);
    }

    /**
     * @notice Returns the balance of the vault of the given token.
     * @param _token The token whom balance is requested.
     * @return The balance of the vault for the given token.
     */
    function vaultBalance(
        IERC20 _token
    ) external view returns (uint256) {
        return _token.balanceOf(address(this));
    }

    /**
     * @notice transfers specified native currency out of the vault.
     * @param _amount The amount to transfer.
     * @param _to The destination address.
     * @param _reason The reason of the transfer.
     */
    function transfer(
        uint256 _amount,
        address payable _to,
        string calldata _reason
    ) external onlyOwner {
        _vaultTransfer(_amount, _to, _reason);
    }

    /**
     * @notice transfers value out of the vault.
     * @dev For token transfers refert to {_vaultTokenTransfer}.
     * @param _amount The amount to transfer.
     * @param _to The destination address.
     * @param _reason The reason of the transfer.
     */
    function _vaultTransfer(
        uint256 _amount,
        address payable _to,
        string calldata _reason
    ) internal {
        require(bytes(_reason).length > 0, "TokenVault: you must specify a reason for your transfer out of the vault");
        require(_amount > 0, "TokenVault: amount to transfer should be > 0");
        _to.transfer(_amount);
        emit VaultTransfer(_amount, _to, _reason);
    }

    /**
     * @notice Transfers specified ERC20 tokens out of the vault.
     * @dev For pure transfers refer to {_vaultTransfer}.
     * @param _token The ERC20 token to transfer.
     * @param _amount The amount to transfer.
     * @param _to The destination address.
     * @param _reason The reason of the transfer.
     */
    function _vaultTokenTransfer(
        IERC20 _token,
        uint256 _amount,
        address _to,
        string calldata _reason
    ) internal {
        require(bytes(_reason).length > 0, "TokenVault: you must specify a reason for your token transfer out of the vault");
        require(_amount > 0, "TokenVault: token amount to transfer should be > 0");
        _token.safeTransfer(_to, _amount);
        emit VaultTokenTransfer(_token, _amount, _to, _reason);
    }

    /**
     * @dev The vault refuses all pure value transfers. While it accepts token transfers.
     */
    receive() external payable {
        revert("TokenVault: Cannot accept pure value incoming transfers");
    }
}
