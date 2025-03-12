// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20, ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/camelot/IAlgebraSwapCallback.sol";

contract CamelotPoolMock {
    using SafeERC20 for IERC20;
    address rdnt;
    address esRDNT;
    address esRDNTHelper;

    constructor(address _rdnt, address _esRDNT) {
        rdnt = _rdnt;
        esRDNT = _esRDNT;
    }

    function swap(
        address receiver,
        bool isEsRDNT,
        int256 amountToSwap,
        uint160 minAmount,
        bytes memory data
    ) external returns (int256 amount0, int256 amount1) {
        if (isEsRDNT) {
            IAlgebraSwapCallback(esRDNTHelper).algebraSwapCallback(amountToSwap, 0, data);
            IERC20(rdnt).safeTransfer(receiver, uint256(amountToSwap));
            amount1 = -amountToSwap;
        } else {
            IAlgebraSwapCallback(esRDNTHelper).algebraSwapCallback(0, amountToSwap, data);
            IERC20(esRDNT).safeTransfer(receiver, uint256(amountToSwap));
            amount0 = -amountToSwap;
        }
    }

    function setEsRDNTHelper(address _esRDNThelper) public {
        esRDNTHelper = _esRDNThelper;
    }
}
