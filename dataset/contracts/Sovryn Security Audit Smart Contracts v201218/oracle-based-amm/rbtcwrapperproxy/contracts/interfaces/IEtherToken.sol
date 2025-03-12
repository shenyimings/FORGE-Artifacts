pragma solidity >=0.5.0 <0.6.0;
import "./IERC20Token.sol";

/*
    Ether Token interface
*/
contract IEtherToken is IERC20Token {
	function deposit() public payable;

	function withdraw(uint256 _amount) public;

	function depositTo(address _to) public payable;

	function withdrawTo(address _to, uint256 _amount) public;
}
