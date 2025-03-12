// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


interface IPoolStats
	{
	function clearProfitsForPools( bytes32[] memory poolIDs ) external;

	// Views
	function averageReserveRatio( IERC20 tokenA, IERC20 tokenB ) external returns (bytes16 averageRatio);
	function profitsForPools( bytes32[] memory poolIDs ) external returns (uint256[] memory _profits);
	}

