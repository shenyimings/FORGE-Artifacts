// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ICurvePool} from "../../../src/interfaces/curve/ICurvePool.sol";
import {MockStETH} from "../lido/MockStETH.sol";

contract MockCurvePool is ICurvePool {
    using FixedPointMathLib for uint256;

    MockStETH public stEth;
    uint256 slippagePct = 1e18; // no slippage

    constructor(MockStETH _stEth) {
        stEth = _stEth;
    }

    function setSlippage(uint256 _slippagePct) external {
        require(_slippagePct <= 1e18, "MockCurvePool: INVALID_SLIPPAGE");
        slippagePct = _slippagePct;
    }

    function exchange(int128 i, int128, uint256 dx, uint256 min_dy) external payable override returns (uint256) {
        require(dx.mulWadUp(slippagePct) >= min_dy, "MockCurvePool: INSUFFICIENT_TOKEN_OUT_AMOUNT");

        if (i == 0) {
            require(stEth.balanceOf(address(this)) >= dx, "MockCurvePool: INSUFFICIENT_TOKEN_OUT_BALANCE");
            require(dx == msg.value, "MockCurvePool: INVALID_ETH_AMOUNT");

            stEth.transfer(msg.sender, dx.mulWadDown(slippagePct));
        } else {
            require(stEth.allowance(msg.sender, address(this)) >= dx, "MockCurvePool: INSUFFICIENT_TOKEN_IN_ALLOWANCE");

            stEth.transferFrom(msg.sender, address(this), dx);
            payable(msg.sender).transfer(dx.mulWadDown(slippagePct));
        }

        return dx;
    }
}
