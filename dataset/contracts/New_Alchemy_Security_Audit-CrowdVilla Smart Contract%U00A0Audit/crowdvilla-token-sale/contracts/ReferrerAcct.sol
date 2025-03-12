pragma solidity ^0.4.18;

import "./ownership/Owners.sol";

contract ReferrerAcct is Owners(false) {
  bytes32 public code;
  address public referrerWallet;
  address public crowdvillaWallet;

  event ETHReceived(uint amount);
  event ETHSent(address recipient, uint amount);

  /**
   * @dev initializes contract with parameters
   * @param       _code bytes32 the referral code
   * @param       _referrerWallet address the address of referrer wallet
   * @param       _crowdvillaWallet address the address of crowdvilla wallet
   * @constructor
   */
  function ReferrerAcct(bytes32 _code, address _referrerWallet, address _crowdvillaWallet) public {
    code = _code;
    referrerWallet = _referrerWallet;
    crowdvillaWallet = _crowdvillaWallet;
  }

  /**
   * @dev accepts ether and logs an event
   */
  function() public payable {
    ETHReceived(msg.value);
  }

  /**
   * @dev updates Referrer wallet address, can only be called by owners
   * @param _newWallet address new wallet address to be used
   */
  function updateReferrerWallet(address _newWallet) public ownerOnly {
    referrerWallet = _newWallet;
  }

  /**
   * @dev updates Crowdvilla wallet address, can only be called by owners
   * @param _newWallet address new wallet address to be used
   */
  function updateCrowdvillaWallet(address _newWallet) public ownerOnly {
    crowdvillaWallet = _newWallet;
  }

  /**
   * @dev sends specified amount to referrer wallet, can only be called by owners
   * @param _amount uint amount in wei
   */
  function sendToReferrer(uint _amount) public ownerOnly {
    require(_amount <= this.balance);
    referrerWallet.transfer(_amount);
    ETHSent(referrerWallet, _amount);
  }

  /**
   * @dev sends all remaining balance to referrer wallet, can only be called by owners
   */
  function sendAllToReferrer() public ownerOnly {
    require(this.balance>0);
    uint amount = this.balance;
    referrerWallet.transfer(amount);
    ETHSent(referrerWallet, amount);
  }

  /**
   * @dev sends specified amount to Crowdvilla wallet, can only be called by owners
   * @param _amount uint amount in wei
   */
  function sendToCrowdvilla(uint _amount) public ownerOnly {
    require(_amount <= this.balance);
    crowdvillaWallet.transfer(_amount);
    ETHSent(crowdvillaWallet, _amount);
  }

  /**
   * @dev sends all remaining balance to Crowdvilla wallet, can only be called by owners
   */
  function sendAllToCrowdvilla() public ownerOnly {
    require(this.balance>0);
    uint amount = this.balance;
    crowdvillaWallet.transfer(amount);
    ETHSent(crowdvillaWallet, amount);
  }
}
