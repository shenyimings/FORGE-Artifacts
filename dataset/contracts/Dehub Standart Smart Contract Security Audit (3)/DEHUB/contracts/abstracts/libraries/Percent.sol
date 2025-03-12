// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Percent {
	using SafeMath for uint256;

	/**
	* @dev Returns numerator percentage of denominator. Uses precision for rounding.
	* e.x. 350.percent(150, 3), 4, will retun 4286, which is 42.86%
	* e.x. 350.percent(150, 3), 3 will return 429, which is 42.9%
	* e.x. 350.percent(150, 3), 2 will return 43, which is 43%
	@param denominator number which we calculate percentage of
	@param numerator number we calculate percentage for
	@param precision decimal point shift
	*/
	function percent( 
		uint256 denominator, 
		uint256 numerator,
		uint256 precision
	) 
		internal
		pure 
		returns(uint256) 
	{
		uint256 _numerator = numerator * 10 ** (precision.add(1));
		// with rounding of last digit
		uint256 _quotient = ((_numerator.div(denominator)).add(5)).div(10);
		return ( _quotient);
	}

	/**
	* @dev Returns a number calculated as a percentage y of value x. 
	* Use scale based on the y.
	* e.x 429.percentOf(350, 1000) will return 150
	* e.x 429.percentOf(350, 10000) will return 15
	*/
	function percentOf(
		uint256 y, 
		uint256 x, 
		uint128 scale
	) 
		internal 
		pure 
		returns(uint256) 
	{
		uint256 a = x.div(scale);
		uint256 b = x.mod(scale);
		uint256 c = y.div(scale);
		uint256 d = y.mod(scale);
		
		uint256 piece1 = a.mul(c).mul(scale).add(a);
		uint256 piece2 = piece1.mul(d).add(b).mul(c);
		uint256 piece3 = piece2.add(b).mul(d).div(scale);
		return piece3;
	}
}