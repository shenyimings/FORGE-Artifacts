// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./libs/IBEP20.sol";

contract Presale is ReentrancyGuard {
  using SafeMath for uint256;
  // Maps user to the number of tokens owned
  mapping (address => uint256) public tokensOwned;
  // The block when the user claimed tokens prevously
  mapping (address => uint256) public lastTokensClaimed;
  // The number of times the user has claimed tokens;
  mapping (address => uint256) public numClaims;
  // The number of unclaimed tokens the user has
  mapping (address => uint256) public tokensUnclaimed;

  // Cosmic token
  IBEP20 cosmic;
  // Sale ended
  bool isSaleActive;
  // Starting timestamp normal
  uint256 startingTimeStamp;
  uint256 totalTokensSold = 0;
  uint256 tokensPerBNB = 50;
  uint256 bnbReceived = 0;
  
  address payable owner;
  
  modifier onlyOwner(){
    require(msg.sender == owner, "You are not the owner");
    _;
  }
  
  event TokenBuy(address user, uint256 tokens);
  event TokenClaim(address user, uint256 tokens);

  constructor (address _cosmicAddress, uint256 _startingTimestamp) public {
    cosmic = IBEP20(_cosmicAddress);
    isSaleActive = true;
    owner = msg.sender;
    startingTimeStamp = _startingTimestamp;
  }

  receive() external payable {
    buy (msg.sender);
  }
  
  
  function buy (address beneficiary) public payable nonReentrant {
    require(isSaleActive, "Sale is not active yet");
      
    address _buyer = beneficiary;
    uint256 _bnbSent = msg.value;
    uint256 tokens = _bnbSent.mul(tokensPerBNB);
    
    
    require (_bnbSent >= 0.2 ether, "BNB is lesser than min value");
    require (_bnbSent <= 7 ether, "BNB is greater than max value");
    require (bnbReceived <= 1200 ether, "Hardcap reached");
    require(block.timestamp >= startingTimeStamp, "Presale has not started");
    
    tokensOwned[_buyer] = tokensOwned[_buyer].add(tokens);
    tokensUnclaimed[_buyer] = tokensUnclaimed[_buyer].add(tokens);
    totalTokensSold = totalTokensSold.add(tokens);
    bnbReceived = bnbReceived.add(msg.value);
    emit TokenBuy(beneficiary, tokens);
  }
  
  function setSaleActive(bool _isSaleActive) external onlyOwner {
      isSaleActive = _isSaleActive;
  }

  function getTokensOwned () external view returns (uint256) {
    return tokensOwned[msg.sender];
  }

  function getTokensUnclaimed () external view returns (uint256) {
    return tokensUnclaimed[msg.sender];
  }

  function getLastTokensClaimed () external view returns (uint256) {
    return lastTokensClaimed[msg.sender];
  }

  function getCosmicTokensLeft () external view returns (uint256) {
    return cosmic.balanceOf(address(this));
  }
  
  function getNumClaims () external view returns (uint256) {
      return numClaims[msg.sender];
  }
  
  function claimTokens () external {
    require (isSaleActive == false, "Sale is still active");
    require (tokensOwned[msg.sender] > 0, "User should own some cosmic tokens");
    require (tokensUnclaimed[msg.sender] > 0, "User should have unclaimed cosmic tokens");
    require (cosmic.balanceOf(address(this)) >= tokensOwned[msg.sender], "There are not enough cosmic tokens to transfer");
    require (block.number.sub(lastTokensClaimed[msg.sender]) >= 28800, "Hasn't been 28,800 blocks since last claim"); 
    require (numClaims[msg.sender] < 5, "Only 5 claims can be made to the smart contract");

    tokensUnclaimed[msg.sender] = tokensUnclaimed[msg.sender].sub(tokensOwned[msg.sender].div(5));
    lastTokensClaimed[msg.sender] = block.number;
    numClaims[msg.sender] = numClaims[msg.sender].add(1);
    
    cosmic.transfer(msg.sender, tokensOwned[msg.sender].div(5));
    emit TokenClaim(msg.sender, tokensOwned[msg.sender].div(5));
  }

  function withdrawFunds () external onlyOwner {
    owner.transfer(address(this).balance);
  }
  
  function withdrawUnsoldCosmic() external onlyOwner {
      cosmic.transfer(msg.sender, cosmic.balanceOf(address(this)));
  }
}