// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

import {DSMath} from "./math.sol";
import {Basic} from "./basic.sol";

import "./interface.sol";

abstract contract Helpers is DSMath, Basic {
    // Mainnet
    IERC20Upgradeable public constant maticToken =
        IERC20Upgradeable(0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0);
    StMaticProxy public constant stMaticProxy =
        StMaticProxy(0x9ee91F9f426fA633d227f7a9b000E28b9dfd8599);

    RootchainManagerProxy public constant rootChainManagerProxy =
        RootchainManagerProxy(0xA0c68C638235ee32657e8f720a23ceC1bFc77C77);

    address public constant mintableERC20Proxy =
        address(0x40ec5B33f54e0E8A33A975908C5BA1c14e5BbbDf);

    /**
     * @dev 1Inch Address
     */
    address internal constant oneInchAddr =
        0x1111111254fb6c44bAC0beD2854e76F90643097d;

    uint256 public constant FEE_DENOMINATOR = 10000;
}
