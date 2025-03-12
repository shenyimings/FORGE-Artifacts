// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @dev Interface for ForTube Bank
 */
interface IForTubeBank {

    function deposit(address _token, uint256 _amount) external;

    function withdraw(address _token, uint256 _amount) external;
}
