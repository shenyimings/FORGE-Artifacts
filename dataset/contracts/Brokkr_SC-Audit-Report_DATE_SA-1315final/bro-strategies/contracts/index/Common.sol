// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IIndexToken } from "./interfaces/IIndexToken.sol";
import { SwapAdapter } from "./libraries/SwapAdapter.sol";

struct MintingData {
    uint256 amountIndex;
    uint256 amountWNATIVETotal;
    uint256[] amountWNATIVEs;
    address[] bestRouters;
    uint256[] amountComponents;
}

struct MintParams {
    address token;
    uint256 amountTokenMax;
    uint256 amountIndexMin;
    address recipient;
    address msgSender;
    address wNATIVE;
    address[] components;
    IIndexToken indexToken;
}

struct BurnParams {
    address token;
    uint256 amountTokenMin;
    uint256 amountIndex;
    address recipient;
    address msgSender;
    address wNATIVE;
    address[] components;
    IIndexToken indexToken;
}

struct ManagementParams {
    address wNATIVE;
    address[] components;
    IIndexToken indexToken;
    uint256[] targetWeights;
}
