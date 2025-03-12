//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./libraries/Errors.sol";
import "./interfaces/IFirewall.sol";

/// @title Firewall
/// @author Figment
/// @notice This contract accepts calls to admin-level functions of an underlying contract, and
///         ensures the caller holds an appropriate role for calling that function. There are two roles:
///          - A Governor can call anything
///          - An Executor can call specific functions specified at construction
///         Random callers cannot call anything through this contract, even if the underlying function
///         is unpermissioned in the underlying contract.
///         Calls to non-admin functions should be called at the underlying contract directly.
contract Firewall is IFirewall {
    mapping(bytes4 => bool) internal executorCanCall;

    address public governor;
    address public executor;
    address internal destination;

    // governor_ should be the most trustworthy entity in the underlying protocol - often, a DAO governor
    // executor_ should be a trustworthy entity that takes care of time-sensitive actions in the underlying protocol
    constructor(
        address governor_,
        address executor_,
        address destination_,
        bytes4[] memory executorCallableSelectors_
    ) {
        governor = governor_;
        executor = executor_;
        destination = destination_;
        for (uint256 i; i < executorCallableSelectors_.length;) {
            executorCanCall[executorCallableSelectors_[i]] = true;
            unchecked {
                ++i;
            }
        }
    }

    modifier ifGovernor() {
        if (msg.sender == governor) {
            _;
        } else {
            revert Errors.Unauthorized(msg.sender);
        }
    }

    modifier ifGovernorOrExecutor() {
        if (msg.sender == governor || msg.sender == executor) {
            _;
        } else {
            revert Errors.Unauthorized(msg.sender);
        }
    }

    /// @dev Change the governor
    function setGovernor(address newGovernor) external ifGovernor {
        governor = newGovernor;
    }

    /// @dev Change the executor
    function setExecutor(address newExecutor) external ifGovernorOrExecutor {
        executor = newExecutor;
    }

    /// @dev make a function either only callable by the governor, or callable by gov and executor.
    function allowExecutor(bytes4 functionSelector, bool executorCanCall_) external ifGovernor {
        executorCanCall[functionSelector] = executorCanCall_;
    }

    /// @dev Validate that the caller is allowed to make the call in msg.sig
    function _checkCallerRole() internal view {
        if (msg.sender == governor || (executorCanCall[msg.sig] && msg.sender == executor)) {
            return;
        }
        revert Errors.Unauthorized(msg.sender);
    }

    /// @dev Forwards the current call to `destination`.
    ///      This function does not return to its internal call site, it will return directly to the external caller.
    function _forward(address destination_, uint256 value) internal {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the destination.
            // out and outsize are 0 because we don't know the size yet.
            let result := call(gas(), destination_, value, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // call returns 0 on error.
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _fallback() internal virtual {
        _checkCallerRole();
        _forward(destination, msg.value);
    }

    fallback() external payable virtual {
        _fallback();
    }

    receive() external payable virtual {
        _fallback();
    }
}
