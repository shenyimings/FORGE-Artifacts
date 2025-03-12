// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {MathUtils} from './MathUtils.sol';
import {SafeMath} from '../../dependencies/openzeppelin/contracts/SafeMath.sol';
import {WadRayMath} from './WadRayMath.sol';
import 'hardhat/console.sol';
import './BitUtils.sol';

contract LibTestUtils {
  using BitUtils for uint256;
  using SafeMath for uint256;
  using WadRayMath for uint256;

  function TestLinearInterest(uint256 rate, uint256 ts) public view returns (uint256) {
    // console.log('block ts:', ts);
    uint256 res = MathUtils.calculateLinearInterest(rate, uint40(ts));
    return res;
  }
}
