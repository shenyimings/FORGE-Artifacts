/*
    Copyright 2021 Cook Finance.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/
pragma solidity ^0.6.2;

import {FixedPointMath} from "../lib/FixedPointMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {Pool} from "./Pool.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";

/// @title ReferralPower
///
/// @dev A library which provides the ReferralPower data struct and associated functions.
library ReferralPower {
  using FixedPointMath for FixedPointMath.uq192x64;
  using Pool for Pool.Data;
  using SafeMath for uint256;
  using ReferralPower for ReferralPower.Data;

  struct Data {
    uint256 totalDeposited;
    uint256 totalReferralPower;
    FixedPointMath.uq192x64 lastAccumulatedReferralPower;
  }

  function update(Data storage _self, Pool.Data storage _pool, Pool.Context storage _ctx) internal {
    _self.totalReferralPower = _self.getUpdatedTotalReferralPower(_pool, _ctx);
    _self.lastAccumulatedReferralPower = _pool.getUpdatedAccumulatedReferralWeight(_ctx);
  }

  function getUpdatedTotalReferralPower(Data storage _self, Pool.Data storage _pool, Pool.Context storage _ctx)
    internal view
    returns (uint256)
  {
    FixedPointMath.uq192x64 memory _currentAccumulatedReferralPower = _pool.getUpdatedAccumulatedReferralWeight(_ctx);
    FixedPointMath.uq192x64 memory lastAccumulatedReferralPower = _self.lastAccumulatedReferralPower;

    if (_currentAccumulatedReferralPower.cmp(lastAccumulatedReferralPower) == 0) {
      return _self.totalReferralPower;
    }

    uint256 _distributedAmount = _currentAccumulatedReferralPower
      .sub(lastAccumulatedReferralPower)
      .mul(_self.totalDeposited)
      .decode();

    return _self.totalReferralPower.add(_distributedAmount);
  }
}
