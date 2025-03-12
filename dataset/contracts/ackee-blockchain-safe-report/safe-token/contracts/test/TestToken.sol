// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20, Pausable, Ownable {
    constructor() ERC20("TestToken", "TT") {
        _mint(msg.sender, 1_000_000_000e18);
    }

    function setOwner(address owner) external {
        _transferOwnership(owner);
    }

    function pause() external {
        _pause();
    }

    function unpause() external {
        _unpause();
    }

    /// @dev See {ERC20-_beforeTokenTransfer}
    /// Requirements: the contract must not be paused OR transfer must be initiated by owner
    /// @param from The account that is sending the tokens
    /// @param to The account that should receive the tokens
    /// @param amount Amount of tokens that should be transferred
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        // Token transfers are only possible if the contract is not paused
        // OR if triggered by the owner of the contract
        require(!paused() || owner() == _msgSender(), "SafeToken: token transfer while paused");
    }
}
