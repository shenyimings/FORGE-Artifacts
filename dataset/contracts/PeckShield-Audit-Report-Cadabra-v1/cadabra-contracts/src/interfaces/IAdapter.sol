// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import "./IBalancer.sol";

interface IAdapter {

    struct CallInfo {
        address callee;
        bytes data;
    }

    error UnsolvableRatio(uint balance0, uint balance1, uint r0, uint r1);
    error UnsupportedToken(address token);
    error ZeroReserveBalance(uint reserve0, uint reserve1);

    function invest(address dustReceiver) external returns (uint valueBefore, uint valueAfter);
    function redeem(uint lpAmount, address receiver)
        external
        returns (
            address[] memory tokens,
            uint[] memory amounts
        );
    function compound(IBalancer.SwapInfo[] calldata swaps) external returns (uint leqBefore,uint leqAfter);
    function recoverFunds(IBalancer.TransferInfo calldata transfer, address to) external;
    function negotiableTokens() external returns(address[] memory tokens);
    function pendingRewards() external view returns(address[] memory tokens, uint[] memory amounts);
    function depositTokens() external view returns (address[] memory tokens);
    function value()  external view returns (uint estimatedValue, uint lpAmount);
    function ratios() external view returns(address[] memory tokens, uint[] memory ratio);
    function description() external returns (string memory);
    function emergencyCall(CallInfo[] calldata calls) external;

}