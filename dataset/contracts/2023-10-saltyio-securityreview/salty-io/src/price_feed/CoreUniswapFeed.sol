// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "v3-core/interfaces/IUniswapV3Pool.sol";
import "v3-core/libraries/TickMath.sol";
import "v3-core/libraries/FullMath.sol";
import "v3-core/libraries/FixedPoint96.sol";
import "./interfaces/IPriceFeed.sol";


// Returns TWAPs for WBTC and WETH for associated Uniswap v3 pools.
// Prices are returned with 18 decimals.
contract CoreUniswapFeed is IPriceFeed
    {
    // 30 minute TWAP period to resist price manipulation
    uint256 public constant TWAP_PERIOD = 30 minutes;


	// Uniswap v3 pool addresses
    address immutable public UNISWAP_V3_WBTC_WETH;
	address immutable public UNISWAP_V3_WETH_USDC;

	IERC20 immutable public wbtc;
    IERC20 immutable public weth;
    IERC20 immutable public usdc;

    bool immutable public wbtc_wethFlipped;
    bool immutable public weth_usdcFlipped;


	constructor( IERC20 _wbtc, IERC20 _weth, IERC20 _usdc, address _UNISWAP_V3_WBTC_WETH, address _UNISWAP_V3_WETH_USDC )
		{
		require( address(_wbtc) != address(0), "_wbtc cannot be address(0)" );
		require( address(_weth) != address(0), "_weth cannot be address(0)" );
		require( address(_usdc) != address(0), "_usdc cannot be address(0)" );
		require( _UNISWAP_V3_WBTC_WETH != address(0), "_UNISWAP_V3_WBTC_WETH cannot be address(0)" );
		require( _UNISWAP_V3_WETH_USDC != address(0), "_UNISWAP_V3_USDC_WETH cannot be address(0)" );

		UNISWAP_V3_WBTC_WETH = _UNISWAP_V3_WBTC_WETH;
		UNISWAP_V3_WETH_USDC = _UNISWAP_V3_WETH_USDC;

		usdc = _usdc;
		wbtc = _wbtc;
		weth = _weth;

		// Assume WBTC/WETH order
		wbtc_wethFlipped = address(weth) < address(wbtc);

		// Assume WETH/USDC order
		weth_usdcFlipped = address(usdc) < address(weth);
		}


	// Returns amount of token0 * (10**18) given token1
    function _getUniswapTwapWei( address pool, uint256 twapInterval ) public view returns (uint256)
    	{
		IUniswapV3Pool _pool = IUniswapV3Pool( pool );

		uint32[] memory secondsAgo = new uint32[](2);
		secondsAgo[0] = uint32(twapInterval); // from (before)
		secondsAgo[1] = 0; // to (now)

        // Get the historical tick data using the observe() function
         (int56[] memory tickCumulatives, ) = _pool.observe(secondsAgo);

		int24 tick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(twapInterval)));
		uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick( tick );
		uint256 p = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96 );

		uint8 decimals0 = ( ERC20( _pool.token0() ) ).decimals();
		uint8 decimals1 = ( ERC20( _pool.token1() ) ).decimals();

		if ( decimals1 > decimals0 )
			return FullMath.mulDiv( 10 ** ( 18 + decimals1 - decimals0 ), FixedPoint96.Q96, p );

		if ( decimals0 > decimals1 )
			return ( FixedPoint96.Q96 * ( 10 ** 18 ) ) / ( p * ( 10 ** ( decimals0 - decimals1 ) ) );

		return ( FixedPoint96.Q96 * ( 10 ** 18 ) ) / p;
    	}


	// Wrap the _getUniswapTwapWei function in a public function that includes a try/catch.
	// Returns zero on any type of failure.
	// virtual - really just needed for the derived unit tests
    function getUniswapTwapWei( address pool, uint256 twapInterval ) public virtual view returns (uint256)
		{
		// Initialize return value to 0
		uint256 twap = 0;
		try this._getUniswapTwapWei(pool, twapInterval) returns (uint256 result)
			{
			twap = result;
			}
		catch (bytes memory)
			{
			// In case of failure, twap will remain 0
			}

		return twap;
		}


	// Uses WBTC/WETH and WETH/USDC pools because they have much higher TVL than just the Uniswap v3 WBTC/USD pool.
	function getTwapWBTC( uint256 twapInterval ) public virtual view returns (uint256)
		{
    	uint256 uniswapWBTC_WETH = getUniswapTwapWei( UNISWAP_V3_WBTC_WETH, twapInterval );
        uint256 uniswapWETH_USDC = getUniswapTwapWei( UNISWAP_V3_WETH_USDC, twapInterval );

		// Return zero if either is invalid
        if ((uniswapWBTC_WETH == 0) || (uniswapWETH_USDC == 0 ))
	        return 0;

		if ( wbtc_wethFlipped )
			uniswapWBTC_WETH = 10**36 / uniswapWBTC_WETH;

		if ( ! weth_usdcFlipped )
			uniswapWETH_USDC = 10**36 / uniswapWETH_USDC;

		return ( uniswapWETH_USDC * 10**18) / uniswapWBTC_WETH;
		}


	// virtual - really just needed for the derived unit tests
	function getTwapWETH( uint256 twapInterval ) public virtual view returns (uint256)
		{
        uint256 uniswapWETH_USDC = getUniswapTwapWei( UNISWAP_V3_WETH_USDC, twapInterval );

		// Return zero if invalid
        if ( uniswapWETH_USDC == 0 )
	        return 0;

        if ( ! weth_usdcFlipped )
        	return 10**36 / uniswapWETH_USDC;
        else
        	return uniswapWETH_USDC;
		}


	// Returned price is the 30 minutes TWAP by default
	function getPriceBTC() public view returns (uint256)
		{
		return getTwapWBTC( TWAP_PERIOD );
		}


	// Returned price is the 30 minutes TWAP by default.
	// For this to be changed the DAO needs to use a new CoreUniswapFeed contract (or other contract that implements IPriceFeed.sol)
	function getPriceETH() public view returns (uint256)
		{
		return getTwapWETH( TWAP_PERIOD );
		}
    }