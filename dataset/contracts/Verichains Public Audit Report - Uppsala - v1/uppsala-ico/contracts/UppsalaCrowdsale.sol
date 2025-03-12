pragma solidity 0.4.23;

import 'zeppelin-solidity/contracts/crowdsale/Crowdsale.sol';
import 'zeppelin-solidity/contracts/crowdsale/validation/CappedCrowdsale.sol';
import 'zeppelin-solidity/contracts/crowdsale/validation/TimedCrowdsale.sol';
import 'zeppelin-solidity/contracts/crowdsale/validation/WhitelistedCrowdsale.sol';
import 'zeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'zeppelin-solidity/contracts/token/ERC20/StandardToken.sol';
import './UppsalaToken.sol';
import './UserMinMaxCrowdsale.sol';


contract UppsalaCrowdsale is WhitelistedCrowdsale, UserMinMaxCrowdsale, CappedCrowdsale,
TimedCrowdsale, Pausable {
  using SafeMath for uint256;

  uint256 public withdrawTime;
  mapping(address => uint256) public balances;
  
  function UppsalaCrowdsale(uint256 rate, 
                            uint256 openTime, 
                            uint256 closeTime, 
                            uint256 totalCap,
                            uint256 userMin,
                            uint256 userMax,
                            uint256 _withdrawTime,
                            address account,
                            StandardToken token)
           Crowdsale(rate, account, token)
           TimedCrowdsale(openTime, closeTime)
           CappedCrowdsale(totalCap)
           UserMinMaxCrowdsale(userMin, userMax) public
  {
    require(_withdrawTime > block.timestamp);
    withdrawTime = _withdrawTime;
  }

  function withdrawTokens(address _beneficiary) public {
    require(block.timestamp > withdrawTime);
    uint256 amount = balances[_beneficiary];
    require(amount > 0);
    balances[_beneficiary] = 0;
    _deliverTokens(_beneficiary, amount);
  }

  function _processPurchase(
    address _beneficiary,
    uint256 _tokenAmount
  )
    internal
  {
    balances[_beneficiary] = balances[_beneficiary].add(_tokenAmount);
  }

  function buyTokens(address beneficiary) public payable whenNotPaused {
    // limiting gas price
    require(tx.gasprice <= 50000000000 wei);
    // limiting gas limt up to around 200000-210000
    require(msg.gas <= 190000);
    super.buyTokens(beneficiary);
  }
}
