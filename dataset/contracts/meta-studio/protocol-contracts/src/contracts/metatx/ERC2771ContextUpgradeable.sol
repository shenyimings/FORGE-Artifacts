// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "./IERC2771Upgradeable.sol";

/// @title Implementation of ERC2771 standard
/// @notice `Meta Transactions` implementation
/// @dev Implementing an updatable `trusted forwarder`
contract ERC2771ContextUpgradeable is Initializable, ContextUpgradeable, IERC2771Upgradeable {
    address private _trustedForwarder;

    /// @notice Emitted when the trusted forwarder has been successfully changed
    /// @param oldTF previous trusted forwader
    /// @param newTF new registered trusted forwarder
    event TrustedForwarderChanged(address oldTF, address newTF);

    // solhint-disable-next-line func-name-mixedcase
    function __ERC2771_init(address forwarder) internal onlyInitializing {
        if (forwarder != address(0)) {
            _setTrustedForwarder(forwarder);
        }
    }

    /// @notice Checks if the address is the current trusted forwarder.
    /// @dev ERC2771 implementation
    /// @param forwarder address to check
    /// @return true if it's the trusted forwarder
    function isTrustedForwarder(address forwarder) public view virtual override returns (bool) {
        return forwarder == _trustedForwarder;
    }

    function _setTrustedForwarder(address forwarder) internal {
        address currentTrustedForwarder = _trustedForwarder;
        _trustedForwarder = forwarder;
        emit TrustedForwarderChanged(currentTrustedForwarder, forwarder);
    }

    function _msgSender() internal view virtual override(ContextUpgradeable) returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            // solhint-disable-next-line no-inline-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
            return sender;
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view virtual override(ContextUpgradeable) returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
