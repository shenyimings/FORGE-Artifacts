// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./ICollateral.sol";
import "../../pools/interfaces/IPools.sol";
import "../../dao/interfaces/IDAO.sol";
import "../../interfaces/IExchangeConfig.sol";


interface IUSDS is IERC20
	{
	function setContracts( ICollateral _collateral, IPools _pools, IExchangeConfig _exchangeConfig ) external;

	function mintTo( address wallet, uint256 amount ) external;
	function shouldBurnMoreUSDS( uint256 usdsToBurn ) external;
	function performUpkeep() external;
	}

