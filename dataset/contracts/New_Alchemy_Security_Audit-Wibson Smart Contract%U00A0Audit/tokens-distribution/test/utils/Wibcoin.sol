pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";


/**
 * @title Wibcoin
 * @author Wibson Development Team <developers@wibson.org>
 * @notice Wibson Oficial Token, this is an ERC20 standard compliant token.
 * @dev Wibcoin token has an initial supply of 9 billion tokens with 9 decimals.
 */
contract Wibcoin is StandardToken {
  string public constant name = "Wibcoin"; // solium-disable-line uppercase
  string public constant symbol = "WIB"; // solium-disable-line uppercase
  uint8 public constant decimals = 9; // solium-disable-line uppercase

  // solium-disable-next-line zeppelin/no-arithmetic-operations
  uint256 public constant INITIAL_SUPPLY = 9000000000 * (10 ** uint256(decimals));

  constructor() public {
    totalSupply_ = INITIAL_SUPPLY;
    balances[msg.sender] = INITIAL_SUPPLY;
    emit Transfer(address(0), msg.sender, INITIAL_SUPPLY);
  }
}
