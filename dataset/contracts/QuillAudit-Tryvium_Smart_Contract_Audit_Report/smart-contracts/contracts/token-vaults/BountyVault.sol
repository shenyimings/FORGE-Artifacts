// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./TokenVault.sol";

/**
 * @title The Tryvium Token Vault contract for bounties.
 * @notice This contract allows to hold tokens and provide
 * a reason about all transfers, to inform the community about 
 * each token transfer from the vault in a verifiable and 
 * trusted way, along with a mechanism to support airdrops.
 */
contract BountyVault is TokenVault {
    constructor() TokenVault() {}

    /**
     * @notice Allows to airdrop specified tokens to a group of addresses.
     * @param _token The ERC20 token to transfer.
     * @param _amount The amount to transfer.
     * @param _to The destination addresses.
     * @param _reason The reason of the transfer.
     */
    function airdropTokens(
        IERC20 _token,
        uint256 _amount,
        address[] calldata _to,
        string calldata _reason
    ) onlyOwner nonReentrant external {
        for (uint256 i = 0; i < _to.length; i++) {
            super._vaultTokenTransfer(_token, _amount, _to[i], _reason);
        }
    }
}