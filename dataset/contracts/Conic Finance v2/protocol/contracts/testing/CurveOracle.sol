// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../interfaces/vendor/ICurvePoolV1.sol";

contract CurveOracle {
    function getVirtualPrice(address _curvePool) external view returns (uint256) {
        return ICurvePoolV1(_curvePool).get_virtual_price();
    }
}
