// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

/**
 * @title TestContractMock contract
 * @dev Simple mock contract for test purposes.
 */
contract TestContractMock {
    /// @dev The state of the contract.
    bool private _disabled;

    /// @dev Emitted when `testFunction` function is executed.
    event TestEvent(address sender, uint256 value, uint256 amount);

    /// @dev A test error with some message
    error TestError(string message);

    /**
     * @dev Test function.
     * Emits a {TestEvent} event.
     * Reverts when the contract is disabled.
     */
    function testFunction(uint256 amount) external payable {
        emit TestEvent(msg.sender, msg.value, amount);
        if (_disabled) {
            revert TestError("Contract is disabled");
        }
    }

    /**
     * @dev Changes the state of the contract to disabled.
     */
    function disable() external {
        _disabled = true;
    }
}
