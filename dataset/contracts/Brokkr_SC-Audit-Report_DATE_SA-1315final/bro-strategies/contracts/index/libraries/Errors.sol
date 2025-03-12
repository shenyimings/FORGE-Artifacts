// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

library Errors {
    // IndexStrategyUpgradeable errors.
    error Index_ComponentAlreadyExists(address component);
    error Index_ComponentHasNonZeroWeight(address component);
    error Index_NotWhitelistedToken(address token);
    error Index_ExceedEquityValuationLimit();
    error Index_AboveMaxAmount();
    error Index_BelowMinAmount();
    error Index_ZeroAddress();
    error Index_SolidlyStableSwapNotSupported();
    error Index_ReceivedNativeTokenDirectly();
    error Index_WrongSwapAmount();
    error Index_WrongPair(address tokenIn, address tokenOut);
    error Index_WrongTargetWeightsLength();
    error Index_WrongTargetWeights();

    // SwapAdapter errors.
    error SwapAdapter_WrongDEX(uint8 dex);
    error SwapAdapter_WrongPair(address tokenIn, address tokenOut);
    error SwapAdapter_WrongPathLength(uint256 wrongLength);

    // IndexOracle errors.
    error Oracle_TokenNotSupported(address token);
    error Oracle_ZeroAddress();
}
