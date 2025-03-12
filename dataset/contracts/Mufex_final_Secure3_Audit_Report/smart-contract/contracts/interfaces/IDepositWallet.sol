// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface IDepositWallet {
    event EtherCollected(address indexed treasury, uint256 amount, string requestId);
    event TokenCollected(address indexed treasury, address indexed token, uint256 amount, string requestId);
    event AccountUpdated(address indexed oldAccount, address indexed newAccount);

    function factory() external view returns (address);

    function account() external view returns (address);

    function treasury() external view returns (address);

    function initialize(address account_, address treasury_) external;

    function updateAccount(address newAccount) external;

    function collectETH(string calldata requestId) external;

    function collectTokens(address[] calldata tokens, string[] calldata requestIds) external;
}