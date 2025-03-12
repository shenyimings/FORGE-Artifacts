pragma solidity ^0.4.18;

import './ownership/Ownable.sol';

contract WalletProvider is Ownable {

  address public wallet;

  function setWallet(address newWallet) public onlyOwner {
    wallet = newWallet;
  }

}

