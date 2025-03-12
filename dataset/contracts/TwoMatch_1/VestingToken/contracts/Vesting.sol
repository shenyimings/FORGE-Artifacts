// SPDX-License-Identifier: BSD Protection License
pragma solidity ^0.8.17;

import './IBEP20.sol';
import './ReentrancyGuard.sol';
import './Presales.sol';
import './TwoMatchPublicSale.sol';

/**
 * @title TwoMatch Vesting Wallet
 * @dev Vesting Contract is a contract which is used to lock and release user tokens,
 * when certain conditions are met. Typically users purchase vested tokens with crowdsale rasing token.
 * This contract provides this functionality, according to the Technical Specification.
 */
contract TwoMatchVesting is ReentrancyGuard {
  // TGE (Public Sale) Indicator 
  uint public releaseStartedAt;
  address immutable private owner;

  TwoMatchPreSeedSale immutable preSeedSale;
  TwoMatchSeedSale    immutable seedSale;
  TwoMatchPrivateSale immutable privateSale;

  TwoMatchPublicSale publicSale;

  IBEP20 immutable token;
  IBEP20 immutable vestingToken;

  struct Contribution {
    uint cliff;
    uint locked;
    uint lockedAt;
    uint released;
    uint lastReleaseAt;
    uint releaseInterval;
    uint releaseIntervalCount;
    uint releasePercentPerInterval;
  }

  event Release (address indexed contributor, uint amount);

  mapping (address => mapping(uint => bool)) userContributionRateExist;
  mapping (address => uint[]) public userContributionRates;

  // Contributor Address -> Purchase Rate -> Vesting Info
  mapping (address => mapping(uint => Contribution)) contributions;
  
  constructor (address _token, address _vestingToken, address _preseed, address _seed, address _privateSale, address _publicSale) {
    owner = msg.sender;
    privateSale = TwoMatchPrivateSale(_privateSale);
    publicSale = TwoMatchPublicSale(_publicSale);
    preSeedSale = TwoMatchPreSeedSale(_preseed);
    seedSale = TwoMatchSeedSale(_seed);

    token = IBEP20(_token);
    vestingToken = IBEP20(_vestingToken);
  }

  function changePublicSaleAddress (address publicSaleAddress) public {
    require(msg.sender == owner, 'Only owner execute this method');

    publicSale = TwoMatchPublicSale(publicSaleAddress);
  }

  function tokenGenerationEvent () public nonReentrant {
    require(releaseStartedAt <= 0, 'TGE is already emitted');
    require(msg.sender == address(publicSale), 'Only public sale is able to emit TGE');

    releaseStartedAt = block.timestamp;
  }

  function schedule (address beneficiary, uint rate, uint amount, uint cliff, uint percentPerInterval, uint interval) public onlyPresaleOrToken {
    Contribution storage contribution = contributions[beneficiary][rate];

    if (!userContributionRateExist[beneficiary][rate]) {
      userContributionRateExist[beneficiary][rate] = true;
      uint[] storage crates = userContributionRates[beneficiary];
      crates.push(rate);
    }

    if (contribution.lockedAt == 0) {
      contributions[beneficiary][rate] = Contribution({
        cliff: cliff,
        locked: 0,
        lockedAt: block.timestamp,
        released: 0,
        lastReleaseAt: 0,
        releaseInterval: interval == 0 ? 1 : interval,
        releaseIntervalCount: 100 / percentPerInterval,
        releasePercentPerInterval: percentPerInterval
      });
    }

    contribution.locked += amount;
  }

  function getContribution (address contributor, uint rate) public view returns (Contribution memory) {
    return contributions[contributor][rate];
  }

  function getReleasableAmount (address contributor) public view returns (uint amount) {
    if (releaseStartedAt <= 0) return 0;

    uint[] memory rates = userContributionRates[contributor];

    for (uint i = 0; i < rates.length; i++) {
      Contribution memory contribution = contributions[contributor][rates[i]];
      uint startOfRelease = contribution.cliff + releaseStartedAt;
      
      if (contribution.released == contribution.locked)
        continue;

      if (block.timestamp < startOfRelease + contribution.lastReleaseAt) 
        continue;

      uint timePassed = block.timestamp - startOfRelease - contribution.lastReleaseAt;

      uint releasePerInterval = contribution.releasePercentPerInterval <= 100 ? 
        contribution.locked * contribution.releasePercentPerInterval / 100 :
        contribution.locked * contribution.releasePercentPerInterval / 10000;
      
      uint intervalsPassed = timePassed / contribution.releaseInterval;

      if (intervalsPassed * contribution.releasePercentPerInterval >= 100)
        amount += contribution.locked - contribution.released;
      else
        amount += releasePerInterval * intervalsPassed;
    }

    return amount;
  }

  function release () public nonReentrant {
    uint amount = getReleasableAmount(msg.sender);

    require(amount > 0, 'Insufficient releasable amount');
    require(vestingToken.balanceOf(msg.sender) >= amount, 'Insufficient vesting token balance');
    require(token.balanceOf(address(this)) >= amount, 'Insufficient contract token balance');

    bool deposited = vestingToken.transferFrom(msg.sender, address(this), amount);

    if (deposited) {
      bool transfered = token.transfer(msg.sender, amount);

      if (transfered) {
        emit Release(msg.sender, amount);
      }
    }
  }

  modifier onlyPresaleOrToken () {
    require(
      msg.sender == address(preSeedSale) ||
      msg.sender == address(seedSale)    ||
      msg.sender == address(privateSale) ||
      msg.sender == address(publicSale) ||
      msg.sender == address(vestingToken),
      'Only presale contract or airdroper can schedule new vestings'
    ); _;
  }
}