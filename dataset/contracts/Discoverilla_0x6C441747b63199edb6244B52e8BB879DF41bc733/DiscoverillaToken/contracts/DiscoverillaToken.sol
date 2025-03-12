// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DiscoverillaToken is Context, ERC20, Ownable {
  using SafeMath for uint256;
  using Address for address;

  // 'taxEnabled' will be turned after token is launched. It will be also managed by voting.  
  bool public taxEnabled;
  
  // To reduce transaction gas fee, all fees will be processed manually by team.
  uint256 public buyBackFee = 200;
  uint256 public marketingFee = 350;
  uint256 public liquidityFee = 250;
  address public buyBackFeeAddress;
  address public marketingFeeAddress;
  address public liquidityFeeAddress;
  
  mapping(address => bool) public _isSellLimitExempt;

  bool public enableDisableAntiWhale = false;  //true -> enable

  uint256 public txLimit = 3;

  struct user {
    uint256 lastTradeTime;
    uint256 tradeAmount;
  }

  uint256 public TwentyFourhours = 86400;  //initally 24 hrs

  mapping(address => user) public tradeData;
  
  // The contract addresses for extra function like staking contract has to be excluded from the tax fee.
  mapping (address => bool) private _isExcludedFromFee;

  // LP addresses to check Buy or Sell transaction. Only owner who have dev skill has to manage this.
  mapping (address => bool) public automatedMarketMakerPairs;

  constructor() ERC20("Discoverilla Token", "DISCOVER") {
      _isExcludedFromFee[owner()] = true;
      
      _isSellLimitExempt[owner()] = true;
      _isSellLimitExempt[address(this)] = true;

      _mint(address(this), 1000 * (10 ** 6) * (10 ** uint256(decimals())));
      _approve(address(this), _msgSender(), totalSupply());
      _transfer(address(this), _msgSender(), totalSupply());
  }
  
  function ActivateAntiWhale(address from,uint amount) private {

      uint blkTime = block.timestamp;
          
      uint256 whalePercent = balanceOf(from).mul(txLimit).div(100); //Should use variable
      require(amount <= whalePercent, "Discoverilla: Can't sell more than taxlimit");
                
      if( blkTime > tradeData[from].lastTradeTime + TwentyFourhours) {
        tradeData[from].lastTradeTime = blkTime;
        tradeData[from].tradeAmount = amount;
      }
      else if( (blkTime < tradeData[from].lastTradeTime + TwentyFourhours) && (( blkTime > tradeData[from].lastTradeTime)) ){
        require(tradeData[from].tradeAmount + amount <= whalePercent, "Discoverilla: Can't sell more than taxlimit in One day");
        tradeData[from].tradeAmount = tradeData[from].tradeAmount + amount;
      }
  }

  function setIsSellLimitExempt(address holder,bool _value) public onlyOwner{
      _isSellLimitExempt[holder] = _value;
  }

  function setSellTxLimit(uint _value) external onlyOwner {
      require(_value >= 1, "Discoverilla: unacceptable sell limit.");
      txLimit = _value;
  }

  function setTwentyFourhours(uint256 _time) external onlyOwner {
      TwentyFourhours = _time;
  }

  function enableDisableWhale(bool _value) external onlyOwner {
      enableDisableAntiWhale = _value;
  }

  function isExcludedFromFee(address _account) public view returns (bool) {
      return _isExcludedFromFee[_account];
  }

  // smart contract addresses of dApps like Platform, Utility must be removed from fee
  function setExcludeFromFee(address _account, bool _enable) external onlyOwner() {
      require(_isExcludedFromFee[_account] != _enable, "Discoverilla: Duplicate Process of excludeFromFee.");
      _isExcludedFromFee[_account] = _enable;
  }

  function setTaxEnable(bool _enable) external onlyOwner() {
      require(taxEnabled != _enable, "Discoverilla: Duplicate Process of setTaxEnable.");
      taxEnabled = _enable;
  }
  
  function setFeeValues(uint256 _buyBackFee, uint256 _marketingFee, uint256 _liquidityFee) external onlyOwner() {
      require(_buyBackFee <= 1000, "Discoverilla: buyBackFee cannot exceed 10%.");
      require(_marketingFee <= 1000, "Discoverilla: marketingFee cannot exceed 10%.");
      require(_liquidityFee <= 1000, "Discoverilla: liquidityFee cannot exceed 10%.");

      buyBackFee = _buyBackFee;
      marketingFee = _marketingFee;
      liquidityFee = _liquidityFee;
  }

  function setFeeAddresses(address _buyBackAddress, address _marketingAddress, address _liquidityAddress) external onlyOwner() {
      require(_buyBackAddress != address(0), "Discoverilla: Fee address can not be the zero address");
      require(_marketingAddress != address(0), "Discoverilla: Fee address can not be the zero address");
      require(_liquidityAddress != address(0), "Discoverilla: Fee address can not be the zero address");

      buyBackFeeAddress = _buyBackAddress;
      marketingFeeAddress = _marketingAddress;
      liquidityFeeAddress = _liquidityAddress;
  }

  function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner() {
      require(automatedMarketMakerPairs[pair] != value, "Discoverilla: Automated market maker pair is already set to that value");
      automatedMarketMakerPairs[pair] = value;
  }

  function recoverContractBalance(address _account) external onlyOwner() {
      uint256 recoverBalance = address(this).balance;
      payable(_account).transfer(recoverBalance);
  }

  function recoverERC20(IERC20 recoverToken, uint256 tokenAmount, address _recoveryAddress) external onlyOwner() {
      recoverToken.transfer(_recoveryAddress, tokenAmount);
  }

  function _transfer(address from, address to, uint256 amount ) internal virtual override {
      require(from != address(0), "Discoverilla: transfer from the zero address");
      require(to != address(0), "Discoverilla: transfer to the zero address");
      require(amount > 0, "Discoverilla: Transfer amount must be greater than zero");

      bool _isTax = taxEnabled;
      if (_isTax && (_isExcludedFromFee[from] || _isExcludedFromFee[to]))
          _isTax = false;
      
      // on sell transaction
      if (_isTax && automatedMarketMakerPairs[to]){
          uint256 buyBackAmount = amount.mul(buyBackFee).div(10000);
          uint256 marketingAmount = amount.mul(marketingFee).mul(2).div(10000);
          uint256 liquidityAmount = amount.mul(liquidityFee).mul(2).div(10000);

          uint256 sendAmount = amount.sub(buyBackAmount).sub(marketingAmount).sub(liquidityAmount);

          if(!_isSellLimitExempt[from] && enableDisableAntiWhale){
            ActivateAntiWhale(from,amount);
          }

          super._transfer(from, to, sendAmount);
          super._transfer(from, buyBackFeeAddress, buyBackAmount);
          super._transfer(from, marketingFeeAddress, marketingAmount);
          super._transfer(from, liquidityFeeAddress, liquidityAmount);

      // on buy transaction
      }else if(_isTax && automatedMarketMakerPairs[from]){
          uint256 buyBackAmount = amount.mul(buyBackFee).div(10000);
          uint256 marketingAmount = amount.mul(marketingFee).div(10000);
          uint256 liquidityAmount = amount.mul(liquidityFee).div(10000);

          uint256 sendAmount = amount.sub(buyBackAmount).sub(marketingAmount).sub(liquidityAmount);
          super._transfer(from, to, sendAmount);
          super._transfer(from, buyBackFeeAddress, buyBackAmount);
          super._transfer(from, marketingFeeAddress, marketingAmount);
          super._transfer(from, liquidityFeeAddress, liquidityAmount);
      } else {
          super._transfer(from, to, amount); 
      }
  }
}