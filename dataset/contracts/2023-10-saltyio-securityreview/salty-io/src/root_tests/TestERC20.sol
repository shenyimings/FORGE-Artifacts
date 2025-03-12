// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";


contract TestERC20 is ERC20
    {
    uint8 private _decimals;

	uint256 public INITIAL_SUPPLY;



	constructor( string memory name, uint256 __decimals )
		ERC20( name, name )
		{
		_decimals = uint8(__decimals);

		// 1 trillion initial supply
		INITIAL_SUPPLY = 1000 * 1000000000 * 10 ** _decimals;
		_mint( msg.sender, INITIAL_SUPPLY );
        }


    function decimals() public view override returns (uint8)
    	{
        return _decimals;
    	}
	}

