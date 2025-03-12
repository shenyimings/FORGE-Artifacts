// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "../governance/LiquidityGauge.sol";

/**
 * @title Liquidity gauge that can update.
 */
contract UpdatableLiquidityGauge is LiquidityGauge {
    
    function setVotingEscrow(address _votingEscrow) external onlyGovernance {
        votingEscrow = _votingEscrow;
    }
}