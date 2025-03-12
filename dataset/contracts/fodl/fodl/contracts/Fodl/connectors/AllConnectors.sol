// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import './interfaces/ISimplePositionBaseConnector.sol';
import './interfaces/ISimplePositionLendingConnector.sol';
import './interfaces/IClaimRewardsConnector.sol';
import './interfaces/IResetAccountConnector.sol';
import './interfaces/ISimplePositionStopLossConnector.sol';
import './interfaces/ISetTokenURIConnector.sol';
import { IIncreaseWithV3FlashswapMultihopConnector } from './interfaces/IIncreaseWithV3FlashswapMultihopConnector.sol';
import { IDecreaseWithV3FlashswapMultihopConnector } from './interfaces/IDecreaseWithV3FlashswapMultihopConnector.sol';
import { IPNLConnector } from './interfaces/IPNLConnector.sol';

// This SC only exists to generate an ABI with the functions of all connectors.
interface AllConnectors is
    ISimplePositionBaseConnector,
    ISimplePositionLendingConnector,
    ISimplePositionStopLossConnector,
    IClaimRewardsConnector,
    IResetAccountConnector,
    IIncreaseWithV3FlashswapMultihopConnector,
    IDecreaseWithV3FlashswapMultihopConnector,
    IPNLConnector,
    ISetTokenURIConnector
{

}
