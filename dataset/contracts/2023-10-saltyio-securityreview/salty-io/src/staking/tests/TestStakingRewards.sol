// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../StakingRewards.sol";


// Used for testing to access the private increase and descrease user share functions
contract TestStakingRewards is StakingRewards
    {
   	constructor( IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IStakingConfig _stakingConfig )
   	StakingRewards( _exchangeConfig, _poolsConfig, _stakingConfig )
   		{
   		}


	function externalIncreaseUserShare(address user, bytes32 pool, uint256 amount, bool useCooldown) external {
        _increaseUserShare(user, pool, amount, useCooldown);
    }


	function externalDecreaseUserShare(address user, bytes32 pool, uint256 amount, bool useCooldown) external {
        _decreaseUserShare(user, pool, amount, useCooldown);
    }
    }