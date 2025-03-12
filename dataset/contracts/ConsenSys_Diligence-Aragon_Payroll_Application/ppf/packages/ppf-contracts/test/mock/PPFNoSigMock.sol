pragma solidity 0.4.24;

import "../../contracts/PPF.sol";

contract PPFNoSigMock is PPF {
	// Set operator to address(0) so invalid signatures can pass
	constructor () PPF(address(0), msg.sender) public {}

	function _setOperator(address _operator) internal {
		// Remove check for null operator
        // require(_operator != address(0)); 
        operator = _operator;
        emit SetOperator(_operator);
    } 
}