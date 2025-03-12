//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title TUPProxy (Transparent Upgradeable Pausable Proxy)
/// @author Kiln
/// @notice This contract extends the Transparent Upgradeable proxy and adds a system wide pause feature.
///         When the system is paused, the fallback will fail no matter what calls are made.
contract TUPProxy is TransparentUpgradeableProxy {
    bytes32 private constant _PAUSE_SLOT = bytes32(uint256(keccak256("eip1967.proxy.pause")) - 1);

    error CallWhenPaused();

    constructor(address _logic, address admin_, bytes memory _data)
        payable
        TransparentUpgradeableProxy(_logic, admin_, _data)
    {}

    /// @dev Retrieves Paused state
    /// @return Paused state
    function isPaused() external ifAdmin returns (bool) {
        return StorageSlot.getBooleanSlot(_PAUSE_SLOT).value;
    }

    /// @dev Pauses system
    function pause() external ifAdmin {
        StorageSlot.getBooleanSlot(_PAUSE_SLOT).value = true;
    }

    /// @dev Unpauses system
    function unpause() external ifAdmin {
        StorageSlot.getBooleanSlot(_PAUSE_SLOT).value = false;
    }

    /// @dev Overrides the fallback method to check if system is not paused before
    /// @dev Address Zero is allowed to perform calls even if system is paused. This allows
    /// view functions to be called when the system is paused as rpc providers can easily
    /// set the sender address to zero.
    function _beforeFallback() internal override {
        if (!StorageSlot.getBooleanSlot(_PAUSE_SLOT).value || msg.sender == address(0)) {
            super._beforeFallback();
        } else {
            revert CallWhenPaused();
        }
    }
}
