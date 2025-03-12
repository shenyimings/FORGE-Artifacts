pragma solidity 0.4.23;

import 'zeppelin-solidity/contracts/token/ERC20/MintableToken.sol';
import 'zeppelin-solidity/contracts/token/ERC20/PausableToken.sol';

contract UppsalaToken is MintableToken, PausableToken {
	string public constant name = 'Sentinel Protocol';
	string public constant  symbol = 'UPP';
	uint8 public constant decimals = 18;
}
