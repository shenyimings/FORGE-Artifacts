pragma solidity >=0.5.0 <0.6.0;
import "./IERC20Token.sol";

contract ISovrynSwapX {
	function token() public view returns (IERC20Token) {
		this;
	}

	function xTransfer(
		bytes32 _toBlockchain,
		bytes32 _to,
		uint256 _amount,
		uint256 _id
	) public;

	function getXTransferAmount(uint256 _xTransferId, address _for) public view returns (uint256);
}
