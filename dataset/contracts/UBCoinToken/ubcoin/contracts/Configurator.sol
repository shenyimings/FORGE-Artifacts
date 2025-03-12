pragma solidity ^0.4.18;

import './ownership/Ownable.sol';
import './MintableToken.sol';
import './UBCoinToken.sol';
import './PreICO.sol';
import './ICO.sol';
import './FreezeTokensWallet.sol';

contract Configurator is Ownable {

  MintableToken public token;

  PreICO public preICO;

  ICO public ico;

  FreezeTokensWallet public teamTokensWallet;

  function deploy() public onlyOwner {

    token = new UBCoinToken();

    preICO = new PreICO();

    preICO.setWallet(0x00EE9d057f66754C7D92550F77Aeb0A87AE34B01);
    preICO.setStart(1520640000); // 10 Mar 2018 00:00:00 GMT
    preICO.setPeriod(22);
    preICO.setPrice(33334000000000000000000);
    preICO.setMinInvestedLimit(100000000000000000);
    preICO.setToken(token);
    preICO.setHardcap(8500000000000000000000);
    token.setSaleAgent(preICO);

    ico = new ICO();

    ico.addMilestone(20, 40);
    ico.addMilestone(20, 20);
    ico.addMilestone(20, 0);
    ico.setMinInvestedLimit(100000000000000000);
    ico.setToken(token);
    ico.setPrice(14286000000000000000000);
    ico.setWallet(0x5FB78D8B8f1161731BC80eF93CBcfccc5783356F);
    ico.setBountyTokensWallet(0xdAA156b6eA6b9737eA20c68Db4040B1182E487B6);
    ico.setReservedTokensWallet(0xE1D1898660469797B22D348Ff67d54643d848295);
    ico.setStart(1522627200); // 02 Apr 2018 00:00:00 GMT
    ico.setHardcap(96000000000000000000000);
    ico.setTeamTokensPercent(12);
    ico.setBountyTokensPercent(4);
    ico.setReservedTokensPercent(34);

    teamTokensWallet = new FreezeTokensWallet();
    teamTokensWallet.setStartLockPeriod(180);
    teamTokensWallet.setPeriod(360);
    teamTokensWallet.setDuration(90);
    teamTokensWallet.setToken(token);
    teamTokensWallet.transferOwnership(ico);

    ico.setTeamTokensWallet(teamTokensWallet);

    preICO.setNextSaleAgent(ico);

    address manager = 0xF1f94bAD54C8827C3B53754ad7dAa0FF5DCD527d;

    token.transferOwnership(manager);
    preICO.transferOwnership(manager);
    ico.transferOwnership(manager);
  }

}

