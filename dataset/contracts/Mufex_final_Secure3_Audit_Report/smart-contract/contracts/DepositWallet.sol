// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./interfaces/IERC20.sol";
import "./interfaces/IDepositWallet.sol";
import "./libraries/TransferHelper.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract DepositWallet is IDepositWallet, Initializable {
    address public override factory;
    address public override account;
    address public override treasury;

    receive() external payable {
        TransferHelper.safeTransferETH(treasury, msg.value);
        emit EtherCollected(treasury, msg.value, "");
    }

    constructor() {
        factory = msg.sender;
    }

    function initialize(address account_, address treasury_) external override initializer {
        require(msg.sender == factory, "forbidden");
        require(account_ != address(0), "zero account address");
        account = account_;
        treasury = treasury_;
    }

    function updateAccount(address newAccount) external override {
        require(msg.sender == account, "forbidden");
        require(newAccount != address(0), "zero address");
        emit AccountUpdated(account, newAccount);
        account = newAccount;
    }

    function collectETH(string calldata requestId) external override {
        uint256 balance = address(this).balance;
        TransferHelper.safeTransferETH(treasury, balance);
        emit EtherCollected(treasury, balance, requestId);
    }

    function collectTokens(address[] calldata tokens, string[] calldata requestIds) external override {
        require(tokens.length == requestIds.length, "length not the same");
        uint256 balance_;
        for (uint256 i = 0; i < tokens.length; i++) {
            balance_ = IERC20(tokens[i]).balanceOf(address(this));
            if (balance_ > 0) {
                TransferHelper.safeTransfer(tokens[i], treasury, balance_);
                emit TokenCollected(treasury, tokens[i], balance_, requestIds[i]);
            }
        }
    }
}