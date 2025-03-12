// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface ITreasury {
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event EthDeposited(address indexed sender, uint256 amount);
    event TokenDeposited(address indexed token, address indexed sender, uint256 amount);
    event EthWithdrawn(address indexed operator, address indexed recipient, uint256 amount, string requestId);
    event TokenWithdrawn(address indexed token, address indexed operator, address indexed recipient, uint256 amount, string requestId);

    function isOperator(address) external view returns (bool);

    function addOperator(address operator) external;

    function removeOperator(address operator) external;

    function depositETH() external payable;

    function depositToken(address token, uint256 amount) external;

    function withdrawETH(address recipient, uint256 amount, string memory requestId) external;

    function withdrawToken(address token, address recipient, uint256 amount, string memory requestId) external;

    function batchWithdrawETH(address[] calldata recipients, uint256[] calldata amounts, string[] calldata requestIds) external;

    function batchWithdrawToken(address[] calldata tokens, address[] calldata recipients, uint256[] calldata amounts, string[] calldata requestIds) external;
}