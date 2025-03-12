//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "./interfaces/IAllowlist.1.sol";
import "./interfaces/IProtocolVersion.sol";

import "./libraries/LibAllowlistMasks.sol";
import "./Initializable.sol";
import "./Administrable.sol";

import "./state/allowlist/AllowerAddress.sol";
import "./state/allowlist/DenierAddress.sol";
import "./state/allowlist/Allowlist.sol";

/// @title Allowlist (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract handles the list of allowed recipients.
/// @notice All accounts have an uint256 value associated with their addresses where
/// @notice each bit represents a right in the system. The DENY_MASK defined the mask
/// @notice used to identify if the denied bit is on, preventing users from interacting
/// @notice with the system
contract AllowlistV1 is IAllowlistV1, Initializable, Administrable, IProtocolVersion {
    /// @inheritdoc IAllowlistV1
    function initAllowlistV1(address _admin, address _allower) external init(0) {
        _setAdmin(_admin);
        AllowerAddress.set(_allower);
        emit SetAllower(_allower);
    }

    function initAllowlistV1_1(address _denier) external init(1) {
        DenierAddress.set(_denier);
        emit SetDenier(_denier);
    }

    /// @inheritdoc IAllowlistV1
    function getAllower() external view returns (address) {
        return AllowerAddress.get();
    }

    /// @inheritdoc IAllowlistV1
    function getDenier() external view returns (address) {
        return DenierAddress.get();
    }

    /// @inheritdoc IAllowlistV1
    function isAllowed(address _account, uint256 _mask) external view returns (bool) {
        uint256 userPermissions = Allowlist.get(_account);
        if (userPermissions & LibAllowlistMasks.DENY_MASK == LibAllowlistMasks.DENY_MASK) {
            return false;
        }
        return userPermissions & _mask == _mask;
    }

    /// @inheritdoc IAllowlistV1
    function isDenied(address _account) external view returns (bool) {
        return Allowlist.get(_account) & LibAllowlistMasks.DENY_MASK == LibAllowlistMasks.DENY_MASK;
    }

    /// @inheritdoc IAllowlistV1
    function hasPermission(address _account, uint256 _mask) external view returns (bool) {
        return Allowlist.get(_account) & _mask == _mask;
    }

    /// @inheritdoc IAllowlistV1
    function getPermissions(address _account) external view returns (uint256) {
        return Allowlist.get(_account);
    }

    /// @inheritdoc IAllowlistV1
    function onlyAllowed(address _account, uint256 _mask) external view {
        uint256 userPermissions = Allowlist.get(_account);
        if (userPermissions & LibAllowlistMasks.DENY_MASK == LibAllowlistMasks.DENY_MASK) {
            revert Denied(_account);
        }
        if (userPermissions & _mask != _mask) {
            revert LibErrors.Unauthorized(_account);
        }
    }

    /// @inheritdoc IAllowlistV1
    function setAllower(address _newAllowerAddress) external onlyAdmin {
        AllowerAddress.set(_newAllowerAddress);
        emit SetAllower(_newAllowerAddress);
    }

    /// @inheritdoc IAllowlistV1
    function setDenier(address _newDenierAddress) external onlyAdmin {
        DenierAddress.set(_newDenierAddress);
        emit SetDenier(_newDenierAddress);
    }

    /// @inheritdoc IAllowlistV1
    function setAllowPermissions(address[] calldata _accounts, uint256[] calldata _permissions) external {
        if (msg.sender != AllowerAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }

        uint256 accountsLength = _accounts.length;

        if (accountsLength == 0) {
            revert InvalidCount();
        }

        if (accountsLength != _permissions.length) {
            revert MismatchedArrayLengths();
        }

        for (uint256 i = 0; i < accountsLength;) {
            LibSanitize._notZeroAddress(_accounts[i]);

            // Check if account is already denied
            if (Allowlist.get(_accounts[i]) & LibAllowlistMasks.DENY_MASK == LibAllowlistMasks.DENY_MASK) {
                revert AttemptToRemoveDenyPermission();
            }

            // Check if DENY permission is present in new permission
            if (_permissions[i] & LibAllowlistMasks.DENY_MASK == LibAllowlistMasks.DENY_MASK) {
                revert AttemptToSetDenyPermission();
            }

            Allowlist.set(_accounts[i], _permissions[i]);
            unchecked {
                ++i;
            }
        }

        emit SetAllowlistPermissions(_accounts, _permissions);
    }

    /// @inheritdoc IAllowlistV1
    function setDenyPermissions(address[] calldata _accounts, uint256[] calldata _permissions) external {
        if (msg.sender != DenierAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }

        uint256 accountsLength = _accounts.length;

        if (accountsLength == 0) {
            revert InvalidCount();
        }

        if (accountsLength != _permissions.length) {
            revert MismatchedArrayLengths();
        }

        for (uint256 i = 0; i < accountsLength;) {
            LibSanitize._notZeroAddress(_accounts[i]);
            if (_permissions[i] & LibAllowlistMasks.DENY_MASK == LibAllowlistMasks.DENY_MASK) {
                // Apply deny mask
                Allowlist.set(_accounts[i], LibAllowlistMasks.DENY_MASK);
            } else {
                // Remove deny mask
                Allowlist.set(_accounts[i], 0);
            }
            unchecked {
                ++i;
            }
        }

        emit SetAllowlistPermissions(_accounts, _permissions);
    }

    function version() external pure returns (string memory) {
        return "1.2.1";
    }
}
