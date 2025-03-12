pragma solidity ^0.4.18;

import './BurnableToken.sol';

contract REIDAOBurnableToken is BurnableToken {

  mapping (address => bool) public hostedWallets;

  /**
   * @dev burns tokens, can only be done by hosted wallets
   * @param _value uint256 the amount of tokens to be burned
   */
  function burn(uint256 _value) public hostedWalletsOnly {
    return super.burn(_value);
  }

  /**
   * @dev adds hosted wallet
   * @param _wallet address the address to be added
   */
  function addHostedWallet(address _wallet) public {
    hostedWallets[_wallet] = true;
  }

  /**
   * @dev removes hosted wallet
   * @param _wallet address the address to be removed
   */
  function removeHostedWallet(address _wallet) public {
    hostedWallets[_wallet] = false;
  }

  /**
   * @dev checks if sender is hosted wallets
   */
  modifier hostedWalletsOnly {
    require(hostedWallets[msg.sender]==true);
    _;
  }
}
