// SPDX-License-Identifier: MIT
//.
pragma solidity ^0.8.0;
import "./BEP20Detailed.sol";
import "./BEP20.sol";


contract EmovesEMV is BEP20Detailed, BEP20 {
  
  mapping(address => bool) private isLocklist;
  mapping(address => bool) private liquidityPool;
  mapping(address => bool) private whitelistTax;
  mapping(address => uint256) private lastTrade;

  uint8 private Taxbuying;
  uint8 private Taxselling;
  uint8 private tradeCooldown;  
  uint8 private transferTax;
  uint256 private AmountTax;
  
  address private marketingPool;

  event updateLocklist(address _wallet, bool status);
  event updateCooldown(uint8 tradeCooldown);
  event updateTax(uint8 _Taxselling, uint8 _Taxbuying, uint8 _transferTax);
  event updateLiquidityPoolStatus(address lpAddress, bool status);
  event updateMarketingPool(address marketingPool);
  event updateWhitelistTax(address _address, bool status);   
 
  constructor() BEP20Detailed("Emoves", "EMV", 18) {
    uint256 totalTokens = 360000000 * 10**uint256(decimals());
    _mint(msg.sender, totalTokens);
    Taxselling = 0;
    Taxbuying = 0;
    transferTax = 0;
    tradeCooldown = 15;
    marketingPool = 0x0D52E8D75AFAE14B5D61713F47e3720fc2ddaD81;
  }

   
 
  function setLocklist(address _wallet, bool _status) external onlyOwner {
    isLocklist[_wallet]= _status;
    emit updateLocklist(_wallet, _status);
  }  

  function setCooldownForTrades(uint8 _tradeCooldown) external onlyOwner {
    tradeCooldown = _tradeCooldown;
    emit updateCooldown(_tradeCooldown);
  }

  function setLiquidityPoolStatus(address _lpAddress, bool _status) external onlyOwner {
    liquidityPool[_lpAddress] = _status;
    emit updateLiquidityPoolStatus(_lpAddress, _status);
  }

  function setMarketingPool(address _marketingPool) external onlyOwner {
    marketingPool = _marketingPool;
    emit updateMarketingPool(_marketingPool);
  }  

  function setTaxes(uint8 _Taxselling, uint8 _Taxbuying, uint8 _transferTax) external onlyOwner {
    require(_Taxselling < 9);
    require(_Taxbuying < 8);
    require(_transferTax < 8);
    Taxselling = _Taxselling;
    Taxbuying = _Taxbuying;
    transferTax = _transferTax;
    emit updateTax(_Taxselling,_Taxbuying,_transferTax);
  }

  function getTaxes() external view returns (uint8 _Taxselling, uint8 _Taxbuying, uint8 _transferTax) {
    return (Taxselling, Taxbuying, transferTax);
  }  

  function setWhitelist(address _address, bool _status) external onlyOwner {
    whitelistTax[_address] = _status;
    emit updateWhitelistTax(_address, _status);
  }

  

  function _transfer(address sender, address receiver, uint256 amount) internal virtual override {
    require(receiver != address(this), string("No transfers to contract allowed."));
    require(!isLocklist[sender],"User Locklisted");
    if(liquidityPool[sender] == true) {
      //It's an LP Pair and it's a buy
      AmountTax = (amount * Taxbuying) / 100;
    } else if(liquidityPool[receiver] == true) {      
      //It's an LP Pair and it's a sell
      AmountTax = (amount * Taxselling) / 100;

      require(lastTrade[sender] < (block.timestamp - tradeCooldown), string("No consecutive sells allowed. Please wait."));
      lastTrade[sender] = block.timestamp;

    } else if(whitelistTax[sender] || whitelistTax[receiver] || sender == marketingPool || receiver == marketingPool) {
      AmountTax = 0;
    } else {
      AmountTax = (amount * transferTax) / 100;
    }
    
    if(AmountTax > 0) {
      super._transfer(sender, marketingPool, AmountTax);
    }    
    super._transfer(sender, receiver, amount - AmountTax);
  }

  
}