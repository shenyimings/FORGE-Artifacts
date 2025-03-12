// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IValidator {
    /**
     * @notice Validate protocol state.
     * @return Is state valid.
     */
    function validate() external view returns(bool);
}
