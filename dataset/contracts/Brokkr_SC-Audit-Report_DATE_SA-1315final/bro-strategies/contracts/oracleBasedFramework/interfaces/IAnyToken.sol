// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { NameValuePair } from "../Common.sol";
import { IInvestable } from "./IInvestable.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

interface IAnyToken {
    function depositAnyToken(
        IERC20Upgradeable convertableToken,
        uint256 convertableTokenAmountIn,
        uint256 minimumDepositTokenAmountOut,
        address investmentTokenReceiver,
        NameValuePair[] calldata params
    ) external;

    function withdrawAnyToken(
        IERC20Upgradeable convertableToken,
        uint256 investmentTokenAmountIn,
        uint256 minimumDepositTokenAmountOut,
        address depositTokenReceiver,
        NameValuePair[] calldata params
    ) external;
}
