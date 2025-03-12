pragma solidity ^0.4.18;

import './ownership/Ownable.sol';

contract UBCoinToken {
  function setSaleAgent(address newSaleAgent) public;
  function transferOwnership(address newOwner) public;
}

contract PreICO {
  function setWallet(address newWallet) public;
  function setStart(uint newStart) public;
  function setPeriod(uint newPerion) public;
  function setPrice(uint newPrice) public;
  function setMinInvestedLimit(uint newMinInvestedLimit) public;
  function setHardcap(uint newHardcap) public;
  function setNextSaleAgent(address newICO) public;
  function setToken(address newToken) public;
  function transferOwnership(address newOwner) public;
}

contract ICO {
  function addMilestone(uint period, uint bonus) public;
  function setStart(uint newStart) public;
  function setPrice(uint newPrice) public;
  function setMinInvestedLimit(uint newMinInvestedLimit) public;
  function setHardcap(uint newHardcap) public;
  function setWallet(address newWallet) public;
  function setTeamTokensWallet(address newTeamTokensWallet) public;
  function setBountyTokensWallet (address newBountyWallet) public;
  function setReservedTokensWallet (address newReservedTokensWallet) public;
  function setTeamTokensPercent(uint newTeamTokensPercent) public;
  function setBountyTokensPercent(uint newBountyTokensPercent) public;
  function setReservedTokensPercent(uint newReservedTokensPercent) public;
  function setToken(address newToken) public;
  function transferOwnership(address newOwner) public;
}

contract FreezeTokensWallet {
  function setStartLockPeriod(uint newStartLockPeriod) public;
  function setPeriod(uint newPeriod) public;
  function setDuration(uint newDuration) public;
  function setToken(address newToken) public;
  function transferOwnership(address newOwner) public;
}

contract TestConfigurator is Ownable {
  UBCoinToken public token;
  PreICO public preICO;
  ICO public ico;
  FreezeTokensWallet public teamTokensWallet;

  function setToken(address _token) public onlyOwner {
    token = UBCoinToken(_token);
  }

  function setPreICO(address _preICO) public onlyOwner {
    preICO = PreICO(_preICO);
  }

  function setICO(address _ico) public onlyOwner {
    ico = ICO(_ico);
  }

  function setTeamTokensWallet(address _teamTokensWallet) public onlyOwner {
    teamTokensWallet = FreezeTokensWallet(_teamTokensWallet);
  }

  function deploy() public onlyOwner {
    preICO.setWallet(0x8fD94be56237EA9D854B23B78615775121Dd1E82);
    preICO.setStart(1519862400);
    preICO.setPeriod(15);
    preICO.setPrice(33334000000000000000000);
    preICO.setMinInvestedLimit(100000000000000000);
    preICO.setHardcap(3000000000000000000);
    preICO.setToken(token);

    token.setSaleAgent(preICO);
    preICO.setNextSaleAgent(ico);

    ico.setStart(1519862400);
    ico.addMilestone(20, 40);
    ico.addMilestone(20, 20);
    ico.addMilestone(20, 0);
    ico.setPrice(14286000000000000000000);
    ico.setMinInvestedLimit(100000000000000000);
    ico.setHardcap(96000000000000000000000);
    ico.setWallet(0x8fD94be56237EA9D854B23B78615775121Dd1E82);
    ico.setBountyTokensWallet(0x470a2D1105EaE6aAe879623357F615Ab9cbf906E);
    ico.setReservedTokensWallet(0x093A89bDb5CE905fecb6272ff3ac92f53350a79A);
    ico.setTeamTokensPercent(12);
    ico.setBountyTokensPercent(4);
    ico.setReservedTokensPercent(34);
    ico.setToken(token);

    ico.setTeamTokensWallet(teamTokensWallet);

    teamTokensWallet.setStartLockPeriod(180);
    teamTokensWallet.setPeriod(360);
    teamTokensWallet.setDuration(90);
    teamTokensWallet.setToken(token);
    teamTokensWallet.transferOwnership(ico);

    token.transferOwnership(owner);
    preICO.transferOwnership(owner);
    ico.transferOwnership(owner);
  }
}
