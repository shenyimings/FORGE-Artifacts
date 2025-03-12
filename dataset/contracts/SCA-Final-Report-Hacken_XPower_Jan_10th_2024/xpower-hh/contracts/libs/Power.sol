// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {UD60x18, ud, pow} from "@prb/math/src/UD60x18.sol";

library Power {
    /**
     * @return n raised to the power of (exp/[root=256])
     */
    function raise(uint256 n, uint256 exp) internal pure returns (uint256) {
        require(exp >= 128, "invalid exponent: too small");
        require(exp <= 512, "invalid exponent: too large");
        UD60x18 p = pow(ud(n * 1e18), ud(exp * 3906250e9));
        return p.intoUint256() / 1e18;
    }
}
