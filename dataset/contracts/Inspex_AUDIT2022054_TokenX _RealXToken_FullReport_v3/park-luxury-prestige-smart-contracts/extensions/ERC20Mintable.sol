// SPDX-License-Identifier: GPL-2.0-or-later
// TokenX Contracts v1.0.0 (extensions/ERC20Mintable.sol)
pragma solidity 0.8.14;

/**
 * @dev Contract module which allows children to implement an mintable control
 * mechanism that can be called by an authorized account.
 *
 * This module is used through inheritance.
 */
abstract contract ERC20Mintable {
    bool private _mintable = true;

    /**
     * @dev Emitted when mintable has renounced.
     */
    event MintableRenounced();

    /**
     * @dev Throws if called when mintable has renounced.
     */
    modifier whenMintable() {
        require(_mintable, "ERC20Mintable: mintable has renounced");
        _;
    }

    /**
     * @dev Returns the mintable state.
     */
    function mintable() external view returns (bool) {
        return _mintable;
    }

    /**
     * @dev Renonuce mintable of the contract.
     */
    function _renounceMintable() internal virtual {
        _mintable = false;

        emit MintableRenounced();
    }
}