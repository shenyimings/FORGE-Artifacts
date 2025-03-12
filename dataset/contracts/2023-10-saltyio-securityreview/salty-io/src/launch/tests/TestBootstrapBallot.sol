// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../interfaces/IExchangeConfig.sol";
import "../../pools/PoolUtils.sol";
import "../BootstrapBallot.sol";


contract TestBootstrapBallot is BootstrapBallot
    {
	constructor( IExchangeConfig _exchangeConfig, IAirdrop _airdrop, uint256 ballotDuration )
	BootstrapBallot(_exchangeConfig, _airdrop, ballotDuration)
		{
		}


	function startExchangeApproved() public pure override returns (bool)
		{
		return true;
		}
	}

