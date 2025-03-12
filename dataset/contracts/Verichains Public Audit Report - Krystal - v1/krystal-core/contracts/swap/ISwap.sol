// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

interface ISwap {
    struct GetExpectedReturnParams {
        uint256 srcAmount;
        address[] tradePath;
        uint256 feeBps;
        bytes extraArgs;
    }

    function getExpectedReturn(GetExpectedReturnParams calldata params)
        external
        view
        returns (uint256 destAmount);

    struct SwapParams {
        uint256 srcAmount;
        // min return for uni, min conversionrate for kyber, etc.
        uint256 minDestAmount;
        address[] tradePath;
        address recipient;
        uint256 feeBps;
        address payable feeReceiver;
        bytes extraArgs;
    }

    function swap(SwapParams calldata params) external payable returns (uint256 destAmount);
}
