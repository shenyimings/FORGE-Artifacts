pragma solidity ^0.4.18;

import './CommonSale.sol';
import './ValueBonusFeature.sol';
import './StagedCrowdsale.sol';
import './FreezeTokensWallet.sol';

contract ICO is ValueBonusFeature, StagedCrowdsale, CommonSale {

  FreezeTokensWallet public teamTokensWallet;

  address public bountyTokensWallet;

  address public reservedTokensWallet;

  uint public teamTokensPercent;

  uint public bountyTokensPercent;

  uint public reservedTokensPercent;

  function setTeamTokensPercent(uint newTeamTokensPercent) public onlyOwner {
    teamTokensPercent = newTeamTokensPercent;
  }

  function setBountyTokensPercent(uint newBountyTokensPercent) public onlyOwner {
    bountyTokensPercent = newBountyTokensPercent;
  }

  function setReservedTokensPercent(uint newReservedTokensPercent) public onlyOwner {
    reservedTokensPercent = newReservedTokensPercent;
  }

  function setTeamTokensWallet(address newTeamTokensWallet) public onlyOwner {
    teamTokensWallet = FreezeTokensWallet(newTeamTokensWallet);
  }

  function setBountyTokensWallet(address newBountyTokensWallet) public onlyOwner {
    bountyTokensWallet = newBountyTokensWallet;
  }

  function setReservedTokensWallet(address newReservedTokensWallet) public onlyOwner {
    reservedTokensWallet = newReservedTokensWallet;
  }

  function calculateTokens(uint _invested) internal returns(uint) {
    uint milestoneIndex = currentMilestone(start);
    Milestone storage milestone = milestones[milestoneIndex];
    uint tokens = _invested.mul(price).div(1 ether);
    uint valueBonusTokens = getValueBonusTokens(tokens, _invested);
    if(milestone.bonus > 0) {
      tokens = tokens.add(tokens.mul(milestone.bonus).div(percentRate));
    }
    return tokens.add(valueBonusTokens);
  }

  function finish() public onlyOwner {
    uint summaryTokensPercent = bountyTokensPercent.add(teamTokensPercent).add(reservedTokensPercent);
    uint mintedTokens = token.totalSupply();
    uint allTokens = mintedTokens.mul(percentRate).div(percentRate.sub(summaryTokensPercent));
    uint foundersTokens = allTokens.mul(teamTokensPercent).div(percentRate);
    uint bountyTokens = allTokens.mul(bountyTokensPercent).div(percentRate);
    uint reservedTokens = allTokens.mul(reservedTokensPercent).div(percentRate);
    mintTokens(teamTokensWallet, foundersTokens);
    mintTokens(bountyTokensWallet, bountyTokens);
    mintTokens(reservedTokensWallet, reservedTokens);
    token.finishMinting();
    teamTokensWallet.start();
    teamTokensWallet.transferOwnership(owner);
  }

  function endSaleDate() public view returns(uint) {
    return lastSaleDate(start);
  }

}
