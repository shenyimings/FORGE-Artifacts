// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface IDepositWalletFactory {
    event WalletCreated(bytes32 indexed salt, address indexed account, address indexed wallet);
    event BatchWalletsCreated(bytes32[] salts, address[] accounts, address[] wallets);
    event BatchCollectTokens(address[] wallets, address[] tokens, string[] requestIds);
    event BatchCollectETH(address[] wallets, string[] requestIds);

    function treasury() external returns (address);

    function getWallet(bytes32 salt) external returns (address);

    function createWallet(bytes32 salt, address account) external returns (address wallet);

    function batchCreateWallets(bytes32[] calldata salts, address[] calldata accounts) external returns (address[] memory wallets);

    function batchCollectTokens(address[] calldata wallets, address[] calldata tokens, string[] calldata requestIds) external;

    function batchCollectETH(address[] calldata wallets, string[] calldata requestIds) external;
}