pragma solidity >=0.5.0 <0.6.0;

import "./IERC20Token.sol";
import "./IConverterAnchor.sol";
import "./IOwned.sol";

/*
    Smart Token interface
*/
contract ISmartToken is IConverterAnchor, IERC20Token {
	function disableTransfers(bool _disable) public;

	function issue(address _to, uint256 _amount) public;

	function destroy(address _from, uint256 _amount) public;
}
