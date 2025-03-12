// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

struct CreateBattleParams {
    address collateralToken;
    string underlying;
    uint256 expiries;
    uint256 strikeValue;
}
