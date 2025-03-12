pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IPools.sol";
import "./PoolUtils.sol";

/*
	=== DERIVATION ===
	// User will zap z0 of token0 and z1 of token1 into the pool
    // Initial reserves: r0 and r1
    // Assuming z0 in excess

    // Initial k
    k = r0 * r1

    // Swap s0 of token0 for s1 of token1
    s1 = r1 - k / (r0 + s0)

    // Substituting k
    s1 = r1 - r0 * r1 / (r0 + s0)

    // Updated reserves ratio after swap
    (r0 + s0) / ( r1 - s1)

    // Adjusted addLiquidity zap amounts after the swap
    a0 = z0 - s0
    a1 = z1 + s1

    // Adjusted addLiquidity amounts need to have the token ratio of the current reserves
    a0 / a1 = (r0 + s0) / ( r1 - s1)

    // Substitute in a0 and a1 from above
    (z0 - s0) / ( z1 + s1) = (r0 + s0) / ( r1 - s1)

    // Substitute
    x = s0         y = s1
    a = r0         b = r1
    c = z0         d = z1

    (c-x)/(d+y) = (a+x)/(b-y)

    // From s1 = r1 - r0 * r1 / (r0 + s0)
    y = b - ab/(a+x)

    // Solve for x
    (c-x)/(d+y) = (a+x)/(b-y)

    // Cross multiply
    (c-x)(b-y) = (a+x)(d+y)

    // Multiply binomials on both sides
    bc - cy - bx + xy = ad + ay + dx + xy

    // Cancel xy both sides
    bc - cy - bx = ad + ay + dx

    // Multiply both sides by -1
    - bc + cy + bx = - ad - ay - dx

    // Gather x and y on the left
    bx + dx + ay + cy = bc - ad

    // Factor x and y
    x(b+d) + y(a+c) = bc - ad

    // Substitute y = b - ab/(a+x)
    x(b+d) + b(a+c) - ab(a+c)/(a+x) = bc - ad

    // Multiply by (a+x)
    x(b+d)(a+x) + b(a+c)(a+x) - ab(a+c) = (bc - ad)(a+x)

    // Multiply all binomials
    x(ab+bx+ad+dx) + b(aa+ax+ac+cx) - aab - abc = abc+bcx-aad-adx

    // Distribute x and b
    abx+bxx+adx+dxx + aab+abx+abc+bcx - aab - abc = abc+bcx-aad-adx

    // Cancel abc (on left), bcx, aab
    abx + bxx + adx + dxx + abx = abc - aad - adx

    // Gather x on the left
    bxx + dxx + abx + abx + adx + adx = abc - aad

    // Factor xx and x
    xx(b+d) + x(2ab + 2ad) = abc - aad

    // Quadratic equation
    xx(b+d) + x(2ab + 2ad) + (aad-abc) = 0

    xxA + xB + C = 0

    A = b + d
    B = 2a(b+d)
    C = a(ad - bc)

    // Substitute back
    a = r0         b = r1
    c = z0         d = z1

    A = r1 + z1
    B = 2r0(r1 + z1)
    C = r0(r0z1 - r1z0)

    x = [-B + sqrt(B^2 - 4AC)] / 2A
*/

library PoolMath
	{
	// The number of decimals that are used in the calculations for zapping in liquidity
	// Note that REDUCED_DECIMALS = 7 was tested with 800 billion and 500 billion 18 decimal pools with 100 billion tokens being
	// zapped in and the calculations did not overflow.  Dropping down to 6 will allow even larger amounts to be used without issue.
	uint256 constant private REDUCED_DECIMALS = 6;


	// Reduce the precision of the decimals to avoid overflow / underflow and convert to int256
	function _reducePrecision( uint256 n, uint8 decimals ) internal pure returns (int256)
		{
		if ( n == 0 )
			return 0;

		// Decimals already at REDUCED_DECIMALS?
		if ( decimals == REDUCED_DECIMALS )
			return int256(n);

		// Decimals less than REDUCED_DECIMALS?
		if ( decimals < REDUCED_DECIMALS )
			return int256( n * 10**(REDUCED_DECIMALS - decimals) );

		// Decimals more than REDUCED_DECIMALS
		return int256( n / 10**(decimals - REDUCED_DECIMALS) );
		}


	// Convert from the reduced precision int back to uint256
	function _restorePrecision( int256 n, uint8 decimals ) internal pure returns (uint256)
		{
		if ( n == 0 )
			return 0;

		// Original decimals already at REDUCED_DECIMALS?
		if ( decimals == REDUCED_DECIMALS )
			return uint256(n);

		// Original decimals less than REDUCED_DECIMALS?
		if ( decimals < REDUCED_DECIMALS )
			return uint256(n) / 10**(REDUCED_DECIMALS - decimals);

		// Original decimals more than REDUCED_DECIMALS
		return uint256(n) * 10**(decimals - REDUCED_DECIMALS);
		}


	// Given initial reserves, and that the user wants to zap specified token amounts into the pool as liquidity,
	// determine how much of token0 needs to be swapped to token1 such that the liquidity added has the same proportion as the reserves in the pool after that swap.
	// Assumes that token0 is in excess (in regards to the current reserve ratio).
    function _zapSwapAmount( uint256 reserve0, uint256 reserve1, uint256 zapAmount0, uint256 zapAmount1, uint8 decimals0, uint8 decimals1 ) internal pure returns (uint256 swapAmount)
    	{
    	// Convert all inputs to int256s with  limited precision so the calculations don't overflow
    	int256 r0 = _reducePrecision( reserve0, decimals0 );
		int256 r1 = _reducePrecision( reserve1, decimals1 );
		int256 z0 = _reducePrecision( zapAmount0, decimals0 );
		int256 z1 = _reducePrecision( zapAmount1, decimals1 );

		// In order to swap and zap, require that the reduced precision reserves and one of the zapAmounts exceed DUST.
		// Otherwise their value was too small and was crushed by the above precision reduction and we should just return swapAmounts of zero so that default addLiquidity will be attempted without a preceding swap.
        if ( r0 < int256(int256(PoolUtils.DUST)) )
        	return 0;

        if ( r1 < int256(PoolUtils.DUST) )
        	return 0;

        if ( z0 < int256(PoolUtils.DUST) )
        if ( z1 < int256(PoolUtils.DUST) )
        	return 0;

        // Components of the above quadratic formula: x = [-B + sqrt(B^2 - 4AC)] / 2A
		int256 A = r1 + z1;
        int256 B = 2 * r0 * ( r1 + z1 );
        int256 C = r0 * ( r0 * z1 - r1 * z0 );

        int256 discriminant = B * B - 4 * A * C;

        // Discriminant needs to be positive to have a real solution to the swapAmount
        if ( discriminant < 0 )
        	return 0; // should never happen - but will default to zapless addLiquidity if it does

        // Compute the square root of the discriminant.
        // It's already been established above that discriminant is positive or zero.
        int256 sqrtDiscriminant = int256( Math.sqrt(uint256(discriminant)) );

		// Prevent negative swap amounts
		if ( B > sqrtDiscriminant )
			return 0; // should never happen - but will default to zapless addLiquidity if it does

        // Only use the positive sqrt of the discriminant from: x = (-B +/- sqrtDiscriminant) / 2A
		swapAmount = _restorePrecision( ( sqrtDiscriminant - B ) / ( 2 * A ), decimals0 );
    	}


	// Determine how much of either token needs to be swapped to give them a ratio equivalent to the reserves
	function _determineZapSwapAmount( IPools pools, IERC20 tokenA, IERC20 tokenB, uint256 zapAmountA, uint256 zapAmountB ) internal view returns (uint256 swapAmountA, uint256 swapAmountB )
		{
		(uint256 reserveA, uint256 reserveB) = pools.getPoolReserves(tokenA, tokenB);

		uint8 decimalsA = ERC20(address(tokenA)).decimals();
		uint8 decimalsB = ERC20(address(tokenB)).decimals();

		// Placed in intermediate variable due to Foundry coverage glitch: https://github.com/foundry-rs/foundry/issues/4305
		uint256 swapAmountA2;
		uint256 swapAmountB2;

		// zapAmountA / zapAmountB exceeds the ratio of reserveA / reserveB? - meaning too much zapAmountA
		if ( zapAmountA * reserveB > reserveA * zapAmountB )
			(swapAmountA2, swapAmountB2) = (_zapSwapAmount( reserveA, reserveB, zapAmountA, zapAmountB, decimalsA, decimalsB ), 0);

		// zapAmountA / zapAmountB is less than the ratio of reserveA / reserveB? - meaning too much zapAmountB
		if ( zapAmountA * reserveB < reserveA * zapAmountB )
			(swapAmountA2, swapAmountB2) = (0, _zapSwapAmount( reserveB, reserveA, zapAmountB, zapAmountA, decimalsB, decimalsA ));

		if ( swapAmountA2 > zapAmountA )
			return (0, 0);

		if ( swapAmountB2 > zapAmountB )
			return (0, 0);

		return (swapAmountA2, swapAmountB2);
		}
	}
