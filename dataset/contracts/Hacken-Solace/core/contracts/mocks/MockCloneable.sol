// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.6;

import "./../utils/Cloneable.sol";
import "./../utils/GovernableInitializable.sol";


/**
 * @title Mock Cloneable
 * @author solace.fi
 * @notice Mock Cloneable is only used to test Cloneable.
 */
contract MockCloneable is Cloneable, GovernableInitializable {

    string public message;

    /***************************************
    INITIALIZER
    ***************************************/

    /**
     * @notice Creates a new `MockCloneable`. The new instance will be a minimal proxy to this instance.
     * @param message_ The new instance's message.
     * @param governance_ The new instance's [governor](/docs/protocol/governance).
     * @return newInstance The address of the new instance.
     */
    function clone(string calldata message_, address governance_) external returns (address newInstance) {
        newInstance = _deployMinimalProxy();
        MockCloneable(newInstance).initialize(message_, governance_);
        return newInstance;
    }

    /**
     * @notice Creates a new `MockCloneable`. The new instance will be a minimal proxy to this instance.
     * @param message_ The new instance's message.
     * @param governance_ The new instance's [governor](/docs/protocol/governance).
     * @param salt_ Input for deterministic address calculation.
     * @return newInstance The address of the new instance.
     */
    function clone2(string calldata message_, address governance_, bytes32 salt_) external returns (address newInstance) {
        newInstance = _deployMinimalProxy(salt_);
        MockCloneable(newInstance).initialize(message_, governance_);
        return newInstance;
    }

    /**
     * @notice Initializes the MockCloneable.
     * @param message_ The instance's message.
     * @param governance_ The instance's [governor](/docs/protocol/governance).
     */
    function initialize(string calldata message_, address governance_) external initializer {
        __Governable_init(governance_);
        message = message_;
    }

    function setMessage(string calldata message_) external onlyGovernance {
        message = message_;
    }
}
