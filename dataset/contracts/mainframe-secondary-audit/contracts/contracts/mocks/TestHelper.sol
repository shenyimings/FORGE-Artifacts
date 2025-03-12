pragma solidity ^0.4.21;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract TestHelper {

  event ShowMessage(string message);
  event Deposited(uint256 value);

  function showMessage(string message) public returns (bool) {
    emit ShowMessage(message);
    return true;
  }

  function deposit(address owner, address token, uint256 amount) public returns (bool) {
    ERC20 tokenContract = ERC20(token);
    tokenContract.transferFrom(owner, this, amount);
    emit Deposited(amount);
    return true;
  }
}
