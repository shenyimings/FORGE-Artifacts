// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum BRIDGE_OP {
    DEPLOY,
    DEPOSIT
}

function encodeMigrate(address rootToken, string memory name, string memory symbol, string memory xname, string memory xsymbol) pure returns (bytes memory) {
    return abi.encode(BRIDGE_OP.DEPLOY, abi.encode(rootToken, name, symbol, xname, xsymbol));
}

function decodeMigrateData(bytes memory data) pure returns (address, string memory, string memory, string memory, string memory) {
    return abi.decode(data, (address, string, string, string, string));
}

function encodeDeposit(address rootToken, address to, uint256 amount) pure returns (bytes memory) {
    return abi.encode(BRIDGE_OP.DEPOSIT, abi.encode(rootToken, to, amount));
}

function decodeDepositData(bytes memory data) pure returns (address, address, uint256) {
    return abi.decode(data, (address, address, uint256));
}
