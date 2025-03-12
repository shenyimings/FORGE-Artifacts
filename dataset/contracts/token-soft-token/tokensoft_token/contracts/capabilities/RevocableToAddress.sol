pragma solidity 0.6.12;

import "../@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "../roles/RevokerRole.sol";

contract RevocableToAddress is ERC20, RevokerRole {

  event RevokeToAddress(address indexed revoker, address indexed from, address indexed to, uint256 amount);

  function _revokeToAddress(
    address _from,
    address _to,
    uint256 _amount
  )
    internal
    returns (bool)
  {
    ERC20._transfer(_from, _to, _amount);
    emit RevokeToAddress(msg.sender, _from, _to, _amount);
    return true;
  }

  /**
  Allow Admins to revoke tokens from any address to any destination
    */
  function revokeToAddress(address from, address to, uint256 amount) public onlyRevoker returns (bool) {
      return _revokeToAddress(from, to, amount);
  }
}