// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract Modifier {
    /**
     * @dev Used to prevent using the zero address
     * @param _address Address used
     */
    modifier onlyNotZeroAddress(address _address) {
        require(_address != address(0), "invalid address");
        _;
    }

    /**
     * @dev Used to prevent using a zero amount
     * @param amount Amount used
     */
    modifier onlyStrictlyPositiveAmount(uint256 amount) {
        require(amount > uint256(0), "amount < 0");
        _;
    }
}