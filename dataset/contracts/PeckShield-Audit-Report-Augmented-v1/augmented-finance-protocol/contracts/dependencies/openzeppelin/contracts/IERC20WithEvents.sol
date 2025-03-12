// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IERC20} from './IERC20.sol';
import {ERC20Events} from './ERC20Events.sol';

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20WithEvents is IERC20, ERC20Events {

}
