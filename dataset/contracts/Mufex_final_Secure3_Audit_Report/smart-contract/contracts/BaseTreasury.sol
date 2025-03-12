// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./interfaces/IERC20.sol";
import "./interfaces/ITreasury.sol";
import "./libraries/TransferHelper.sol";
import "./Ownable.sol";

abstract contract BaseTreasury is ITreasury, Ownable {
    mapping(address => bool) public isOperator;

    modifier onlyOperator() {
        require(isOperator[msg.sender], "only operator");
        _;
    }

    receive() external payable {}

    function addOperator(address operator) external override onlyOwner {
        require(!isOperator[operator], "already added");
        isOperator[operator] = true;
        emit OperatorAdded(operator);
    }

    function removeOperator(address operator) external override onlyOwner {
        require(isOperator[operator], "operator not found");
        isOperator[operator] = false;
        emit OperatorRemoved(operator);
    }

    function depositETH() external payable override {
        require(msg.value > 0, "deposit amount is zero");
        emit EthDeposited(msg.sender, msg.value);
    }

    function depositToken(address token, uint256 amount) external override {
        require(token != address(0), "zero address");
        require(amount > 0, "deposit amount is zero");
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);
        emit TokenDeposited(token, msg.sender, amount);
    }

    function withdrawETH(address recipient, uint256 amount, string calldata requestId) external override onlyOperator {
        _withdrawETH(recipient, amount, requestId);
    }

    function withdrawToken(address token, address recipient, uint256 amount, string calldata requestId) external override onlyOperator {
        _withdrawToken(token, recipient, amount, requestId);
    }

    function batchWithdrawETH(
        address[] calldata recipients, 
        uint256[] calldata amounts, 
        string[] calldata requestIds
    ) external override onlyOperator {
        require(
            recipients.length == amounts.length && 
            recipients.length == requestIds.length, "length not the same");
        for (uint256 i = 0; i < recipients.length; i++) {
            _withdrawETH(recipients[i], amounts[i], requestIds[i]);
        }
    }

    function batchWithdrawToken(
        address[] calldata tokens,
        address[] calldata recipients,
        uint256[] calldata amounts,
        string[] calldata requestIds
    ) external override onlyOperator {
        require(
            tokens.length == recipients.length &&
            recipients.length == amounts.length && 
            recipients.length == requestIds.length, "length not the same");
        for (uint256 i = 0; i < recipients.length; i++) {
            _withdrawToken(tokens[i], recipients[i], amounts[i], requestIds[i]);
        }
    }

    function _withdrawETH(address recipient, uint256 amount, string calldata requestId) internal {
        require(recipient != address(0), "recipient is zero address");
        require(amount > 0, "zero amount");
        TransferHelper.safeTransferETH(recipient, amount);
        emit EthWithdrawn(msg.sender, recipient, amount, requestId);
    }

    function _withdrawToken(address token, address recipient, uint256 amount, string calldata requestId) internal {
        require(token != address(0), "token is zero address");
        require(recipient != address(0), "recipient is zero address");
        require(amount > 0, "zero amount");
        require(IERC20(token).balanceOf(address(this)) >= amount, "balance not enough");
        TransferHelper.safeTransfer(token, recipient, amount);
        emit TokenWithdrawn(token, msg.sender, recipient, amount, requestId);
    }
}