// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./FixedPointMath.sol";
import {IERC20} from "./../interfaces/ERC20.sol";
import {IPriceOracle} from "./../interfaces/IPriceOracle.sol";

library Deposit {
    using FixedPointMath for uint256;

    struct Data {
        uint256 id;
        bool isActive;
        address depositor;
        address magister;
        uint256 poolId;
        uint256 principal;
        uint256 depositorTotalAccruedRewards;
        uint256 depositorWithdrawnRewards;
        uint256 magisterTotalAccruedRewards;
        uint256 magisterWithdrawnRewards;
        uint256 createdAt;
        uint256 lastDepositAt;
        uint256 lastInteractionAt;
        uint256 closedAt;
    }
}
