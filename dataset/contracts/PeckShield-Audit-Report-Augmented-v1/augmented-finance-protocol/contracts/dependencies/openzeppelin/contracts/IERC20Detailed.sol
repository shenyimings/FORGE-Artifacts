// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IERC20} from './IERC20.sol';
import {IERC20Details} from './IERC20Details.sol';

interface IERC20Detailed is IERC20, IERC20Details {}
