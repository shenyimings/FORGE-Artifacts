// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./FixedPointMath.sol";
import {IERC20} from "./../interfaces/ERC20.sol";
import {IPriceOracle} from "./../interfaces/IPriceOracle.sol";

library Magister {
    using FixedPointMath for uint256;

    struct Data {
        bool isActive;
        uint256 createdAt;
        address addr;
        uint256 totalIncome;
        uint256[] depositIds;
    }
}
