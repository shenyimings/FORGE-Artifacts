// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface IFlashLoanReceiver {
    function executeOperation(address _reserve, uint256 _amount, uint256 _fee, bytes calldata _params) external;
}
