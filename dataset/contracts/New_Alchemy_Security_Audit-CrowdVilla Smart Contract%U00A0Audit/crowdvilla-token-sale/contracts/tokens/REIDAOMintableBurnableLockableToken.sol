pragma solidity ^0.4.18;

import "./REIDAOMintableLockableToken.sol";
import "./REIDAOBurnableToken.sol";

contract REIDAOMintableBurnableLockableToken is REIDAOMintableLockableToken, REIDAOBurnableToken {

  /**
   * @dev adds hosted wallet, can only be done by owners.
   * @param _wallet address the address to be added
   */
  function addHostedWallet(address _wallet) public ownerOnly {
    return super.addHostedWallet(_wallet);
  }

  /**
   * @dev removes hosted wallet, can only be done by owners.
   * @param _wallet address the address to be removed
   */
  function removeHostedWallet(address _wallet) public ownerOnly {
    return super.removeHostedWallet(_wallet);
  }
}
