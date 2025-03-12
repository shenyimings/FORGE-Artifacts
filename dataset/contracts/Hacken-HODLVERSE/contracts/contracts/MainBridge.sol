// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./BasicBridge.sol";

contract MainBridge is BasicBridge {
    using SafeERC20 for IERC20;

    mapping(address => bool) public registeredToken;
    mapping(bytes32 => bool) public filledSideTx;

    event SwapPairRegister(address indexed sponsor, address indexed token);
    event SwapStarted(
        address indexed token,
        address indexed fromAddr,
        uint256 amount,
        uint256 feeAmount
    );

    constructor(uint256 fee) public {
        swapFee = fee;
    }

    function registerSwapPairToSide(address token) external returns (bool) {
        require(
            !registeredToken[token],
            "MainBridge:registerSwapPairToSide:: ALREADY_REGISTERED"
        );

        registeredToken[token] = true;

        emit SwapPairRegister(msg.sender, token);
        return true;
    }

    function fillSideETHSwap(
        bytes32 txnHash,
        address token,
        address toAddress,
        uint256 amount
    ) external onlyOwner returns (bool) {
        require(
            !filledSideTx[txnHash],
            "MainBridge:fillSideETHSwap:: ALREADY_FILLED"
        );
        require(
            registeredToken[token],
            "MainBridge:fillSideETHSwap:: TOKEN_NOT_REGISTERED"
        );

        filledSideTx[txnHash] = true;
        IERC20(token).safeTransfer(toAddress, amount);

        emit SwapFilled(token, txnHash, toAddress, amount);
        return true;
    }

    function swapETH2Side(address token, uint256 amount)
        external
        payable
        returns (bool)
    {
        require(
            registeredToken[token],
            "MainBridge:swapETH2Side:: TOKEN_NOT_REGISTERED"
        );
        require(
            msg.value == swapFee,
            "MainBridge:swapETH2Side:: NOT_ENOUGH_FEE"
        );

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit SwapStarted(token, msg.sender, amount, msg.value);
        return true;
    }
}
