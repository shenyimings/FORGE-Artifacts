// SPDX-License-Identifier: BSD Protection License
pragma solidity ^0.8.17;

import './IBEP20.sol';
import './ReentrancyGuard.sol';
import './Vesting.sol';

contract Owned {
  address private owner;
  
  constructor () {
    owner = msg.sender;
  }

  function withdrawCoinBalance () external onlyOwner {
    payable(owner).transfer(address(this).balance);
  }

  modifier onlyOwner () {
    require(msg.sender == owner); _;
  }
}

contract TimeDependent is Owned {
  uint public openedAt;
  uint public closedAt;

  function setStartAndEnd (uint _openingAt, uint _closingAt) public onlyOwner {
    require(_openingAt > block.timestamp, 'Cannot set start timestamp in the past');
    require(_closingAt > _openingAt, 'Cannot set end timestamp earlier than start');
    require(openedAt < block.timestamp, 'Cannot set start time due to pass');

    openedAt = _openingAt;
    closedAt = _closingAt;
  }

  function prolong (uint duration) public onlyOwner {
    closedAt += duration;
  }

  function started () public view returns (bool) {
    return block.timestamp >= openedAt;
  }

  function active () public view returns (bool) {
    return block.timestamp >= openedAt && block.timestamp <= closedAt;
  }

  function ended () public view returns (bool) {
    return block.timestamp >= closedAt;
  }

  modifier onlyWhileActive () {
    require(active(), 'Round unavailable for actions');
    _;
  }
}

contract VestingCrowdsale {
  TwoMatchVesting immutable vesting;

  constructor (address _vesting) {
    vesting = TwoMatchVesting(_vesting);
  }
}

abstract contract BasicCrowdsale is ReentrancyGuard {
  IBEP20 public immutable saleToken;
  IBEP20 public immutable raiseToken;

  address immutable wallet;

  uint public raised;
  uint public sold;

  event TokenPurchase (address indexed buyer, uint raised, uint sold);

  constructor (address _wallet, address _saleToken, address _raiseToken) {
    wallet = _wallet;
    saleToken = IBEP20(_saleToken);
    raiseToken = IBEP20(_raiseToken);
  }

  function reserve () public view returns (uint) {
    return saleToken.balanceOf(address(this));
  }
  
  function proccessPurchase (uint sell, uint raise) internal nonReentrant {
    require(sell % 100 == 0, 'Purchase amount must be divisible by 100');

    raised += raise;
    sold += sell;
    
    bool deposited = raiseToken.transferFrom(msg.sender, wallet, raise);

    if (deposited) {
      bool transfered = saleToken.transfer(msg.sender, sell);
      
      if (transfered) {        
        emit TokenPurchase(msg.sender, raise, sell);
      }
    }
  }

  modifier preValidatePurchase (uint amount) {
    require(amount > 0, 'Purchase tokens amount must be specified');
    require(sold + amount <= reserve(), 'Purchase amount exceeds sale token reserves');
    _;
  }
}

contract TwoMatchPreSeedSale is BasicCrowdsale, TimeDependent, VestingCrowdsale {
  uint public constant releasePercentPerInterval = 10;
  uint public constant releaseInterval = 30 days;
  uint public constant rate = 10;

  constructor (address _saleToken, address _raiseToken, address _wallet, address _vesting)
    BasicCrowdsale(_wallet, _saleToken, _raiseToken) 
    VestingCrowdsale(_vesting)
  {}

  function purchase (uint amount) public preValidatePurchase(amount) onlyWhileActive {
    super.proccessPurchase(amount, (amount * rate) / 100);

    vesting.schedule(msg.sender, rate, amount, 30 days, releasePercentPerInterval, releaseInterval);
  }
}

contract TwoMatchSeedSale is BasicCrowdsale, TimeDependent, VestingCrowdsale {
  uint public constant releasePercentPerInterval = 10;
  uint public constant releaseInterval = 30 days;
  uint public constant cliff = 9 * 30 days;
  uint public constant rate = 20;

  constructor (address _saleToken, address _raiseToken, address _wallet, address _vesting)
    BasicCrowdsale(_wallet, _saleToken, _raiseToken) 
    VestingCrowdsale(_vesting)
  {}

  function purchase (uint amount) public preValidatePurchase(amount) onlyWhileActive {    
    super.proccessPurchase(amount, (amount * rate) / 100);

    vesting.schedule(msg.sender, rate, amount, cliff, releasePercentPerInterval, releaseInterval);
  }
}

contract TwoMatchPrivateSale is BasicCrowdsale, TimeDependent, VestingCrowdsale {
  uint public constant releaseInterval = 30 days;
  
  enum Rate { TIER1, TIER2, TIER3 }

  mapping (Rate => uint) rates;
  mapping (Rate => uint) cliffs;
  mapping (Rate => uint) percents; 
  
  constructor (address _saleToken, address _raiseToken, address _wallet, address _vesting)
    BasicCrowdsale(_wallet, _saleToken, _raiseToken) 
    VestingCrowdsale(_vesting)
  {
    rates[Rate.TIER1] = 36; cliffs[Rate.TIER1] = 12 * 30 days; percents[Rate.TIER1] = 10;
    rates[Rate.TIER2] = 40; cliffs[Rate.TIER2] = 9  * 30 days; percents[Rate.TIER2] = 10;
    rates[Rate.TIER3] = 44; cliffs[Rate.TIER3] = 2  * 30 days; percents[Rate.TIER3] = 10;
  }
  
  function purchase (uint amount, Rate selected) public preValidatePurchase(amount) onlyWhileActive  {
    super.proccessPurchase(amount, (amount * rates[selected]) / 100);

    vesting.schedule(msg.sender, rates[selected], amount, cliffs[selected], percents[selected], releaseInterval);
  }
}

// contract TwoMatchPublicSale is BasicCrowdsale, TimeDependent, VestingCrowdsale {
//   uint public constant rate = 60;

//   constructor (address _saleToken, address _raiseToken, address _wallet, address _vesting)
//     BasicCrowdsale(_wallet, _saleToken, _raiseToken)
//     VestingCrowdsale(_vesting)
//   {}
  
//   function purchase (uint amount) public preValidatePurchase(amount) onlyWhileActive  {
//     super.proccessPurchase(amount, (amount * rate) / 100);

//     if (vesting.releaseStartedAt() <= 0)
//       vesting.tokenGenerationEvent();
//   }
// }