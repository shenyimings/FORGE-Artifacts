// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {QUIDD, IForwarderRegistry, UsingUniversalForwarding, ManagedIdentity} from "../../../token/ERC20/QUIDD.sol";

/**
 * @title QUIDD
 * A mintable ERC20 token contract implementation.
 */
contract QUIDDMock is QUIDD {
    /**
     * Constructor.
     * @dev Reverts if `values` and `recipients` have different lengths.
     * @dev Reverts if one of `recipients` is the zero address.
     * @dev Emits an {IERC20-Transfer} event for each transfer with `from` set to the zero address.
     * @param recipients the accounts to deliver the tokens to.
     * @param values the amounts of tokens to mint to each of `recipients`.
     * @param forwarderRegistry Registry of approved meta-transaction forwarders.
     * @param universalForwarder Universal meta-transaction forwarder.
     */
    constructor(
        address[] memory recipients,
        uint256[] memory values,
        IForwarderRegistry forwarderRegistry,
        address universalForwarder
    ) QUIDD(recipients, values, forwarderRegistry, universalForwarder) {}

    /**
     * Mints `amount` tokens and assigns them to `account`, increasing the total supply.
     * @dev Reverts if `account` is the zero address.
     * @dev Emits a {IERC20-Transfer} event with `from` set to the zero address.
     * @param to the account to deliver the tokens to.
     * @param value the amount of tokens to mint.
     */
    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function msgData() external view returns (bytes memory ret) {
        return _msgData();
    }
}
