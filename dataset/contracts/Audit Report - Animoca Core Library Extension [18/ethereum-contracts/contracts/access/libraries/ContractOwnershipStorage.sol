// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {NotContractOwner, NotTargetContractOwner} from "./../errors/ContractOwnershipErrors.sol";
import {TargetIsNotAContract} from "./../errors/Common.sol";
import {IERC173Events} from "./../events/IERC173Events.sol";
import {IERC173} from "./../interfaces/IERC173.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ProxyInitialization} from "./../../proxy/libraries/ProxyInitialization.sol";
import {InterfaceDetectionStorage} from "./../../introspection/libraries/InterfaceDetectionStorage.sol";

library ContractOwnershipStorage {
    using Address for address;
    using ContractOwnershipStorage for ContractOwnershipStorage.Layout;
    using InterfaceDetectionStorage for InterfaceDetectionStorage.Layout;

    struct Layout {
        address contractOwner;
    }

    bytes32 internal constant LAYOUT_STORAGE_SLOT = bytes32(uint256(keccak256("animoca.core.access.ContractOwnership.storage")) - 1);
    bytes32 internal constant PROXY_INIT_PHASE_SLOT = bytes32(uint256(keccak256("animoca.core.access.ContractOwnership.phase")) - 1);

    /// @notice Initializes the storage with an initial contract owner (immutable version).
    /// @notice Marks the following ERC165 interface(s) as supported: ERC173.
    /// @dev Note: This function should be called ONLY in the constructor of an immutable (non-proxied) contract.
    /// @dev Emits an {OwnershipTransferred} if `initialOwner` is not the zero address.
    /// @param initialOwner The initial contract owner.
    function constructorInit(Layout storage s, address initialOwner) internal {
        if (initialOwner != address(0)) {
            s.contractOwner = initialOwner;
            emit IERC173Events.OwnershipTransferred(address(0), initialOwner);
        }
        InterfaceDetectionStorage.layout().setSupportedInterface(type(IERC173).interfaceId, true);
    }

    /// @notice Initializes the storage with an initial contract owner (proxied version).
    /// @notice Sets the proxy initialization phase to `1`.
    /// @notice Marks the following ERC165 interface(s) as supported: ERC173.
    /// @dev Note: This function should be called ONLY in the init function of a proxied contract.
    /// @dev Reverts with {InitializationPhaseAlreadyReached} if the proxy initialization phase is set to `1` or above.
    /// @dev Emits an {OwnershipTransferred} if `initialOwner` is not the zero address.
    /// @param initialOwner The initial contract owner.
    function proxyInit(Layout storage s, address initialOwner) internal {
        ProxyInitialization.setPhase(PROXY_INIT_PHASE_SLOT, 1);
        s.constructorInit(initialOwner);
    }

    /// @notice Sets the address of the new contract owner.
    /// @dev Reverts with {NotContractOwner} if `sender` is not the contract owner.
    /// @dev Emits an {OwnershipTransferred} event if `newOwner` is different from the current contract owner.
    /// @param newOwner The address of the new contract owner. Using the zero address means renouncing ownership.
    function transferOwnership(Layout storage s, address sender, address newOwner) internal {
        address previousOwner = s.contractOwner;
        if (sender != previousOwner) revert NotContractOwner(sender);
        if (previousOwner != newOwner) {
            s.contractOwner = newOwner;
            emit IERC173Events.OwnershipTransferred(previousOwner, newOwner);
        }
    }

    /// @notice Gets the address of the contract owner.
    /// @return contractOwner The address of the contract owner.
    function owner(Layout storage s) internal view returns (address contractOwner) {
        return s.contractOwner;
    }

    /// @notice Checks whether an account is the owner of a target contract.
    /// @param targetContract The contract to check.
    /// @param account The account to check.
    /// @return isTargetContractOwner_ Whether `account` is the owner of `targetContract`.
    function isTargetContractOwner(address targetContract, address account) internal view returns (bool isTargetContractOwner_) {
        if (!targetContract.isContract()) revert TargetIsNotAContract(targetContract);
        return IERC173(targetContract).owner() == account;
    }

    /// @notice Ensures that an account is the contract owner.
    /// @dev Reverts with {NotContractOwner} if `account` is not the contract owner.
    /// @param account The account.
    function enforceIsContractOwner(Layout storage s, address account) internal view {
        if (account != s.contractOwner) revert NotContractOwner(account);
    }

    /// @notice Enforces that an account is the owner of a target contract.
    /// @dev Reverts with {NotTheTargetContractOwner} if the account is not the owner.
    /// @param targetContract The contract to check.
    /// @param account The account to check.
    function enforceIsTargetContractOwner(address targetContract, address account) internal view {
        if (!isTargetContractOwner(targetContract, account)) revert NotTargetContractOwner(targetContract, account);
    }

    function layout() internal pure returns (Layout storage s) {
        bytes32 position = LAYOUT_STORAGE_SLOT;
        assembly {
            s.slot := position
        }
    }
}
