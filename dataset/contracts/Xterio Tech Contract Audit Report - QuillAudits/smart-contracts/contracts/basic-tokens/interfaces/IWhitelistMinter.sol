// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWhitelistMinter {
    function mintWithSig(
        address recipient,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 limit,
        address paymentTokenAddress,
        uint256 paymentTokenAmount,
        bytes calldata sig
    ) external;
}
