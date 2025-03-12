//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;

import "./Libraries.sol";
import "./Interfaces.sol";
import "./BaseErc20.sol";

interface IPinkAntiBot {
  function setTokenOwner(address owner) external;
  function onPreTransferCheck(address from, address to, uint256 amount) external;
}

abstract contract AntiSniper is BaseErc20 {
    using SafeMath for uint256;
    
    IPinkAntiBot public pinkAntiBot;
    bool private pinkAntiBotConfigured;

    bool public enableSniperBlocking;
    bool public enableBlockLogProtection;
    bool public enableHighTaxCountdown;
    bool public enablePinkAntiBot;
    //bool public enableHighGasProtection;
    
    uint256 public maxSellPercentage;
    uint256 public maxHoldPercentage;

    uint256 public launchTime;
    uint256 public snipersCaught;
    
    mapping (address => bool) public isSniper;
    mapping (address => bool) public isNeverSniper;
    mapping (address => uint256) public transactionBlockLog;
    
    // Overrides
    
    function launch() override virtual public onlyOwner {
        super.launch();
        launchTime = block.timestamp;
    }
    
    function preTransfer(address from, address to, uint256 value) override virtual internal {
        super.preTransfer(from, to, value);
        require(isSniper[msg.sender] == false || enableSniperBlocking == false, "sniper rejected");
        
        if (launched && isAlwaysExempt(to) == false && from != owner && isNeverSniper[from] == false && isNeverSniper[to] == false) {
            if(enableBlockLogProtection) {
                if (transactionBlockLog[to] == block.number) {
                    isSniper[to] = true;
                    snipersCaught ++;
                }
                if (transactionBlockLog[from] == block.number) {
                    isSniper[from] = true;
                    snipersCaught ++;
                }
                if (isAlwaysExempt(to) == false) {
                    transactionBlockLog[to] = block.number;
                }
                if (isAlwaysExempt(from) == false) {
                    transactionBlockLog[from] = block.number;
                }
            }
            
            if (enablePinkAntiBot) {
                pinkAntiBot.onPreTransferCheck(from, to, value);
            }
            
            if (maxHoldPercentage > 0) {
                require (_balances[to].add(value) <= maxHoldAmount(), "this is over the max hold amount");
            }
            
            if (maxSellPercentage > 0) {
                require (value <= maxSellAmount(), "this is over the max sell amount");
            }
        }
    }
    
    function calculateTransferAmount(address from, address to, uint256 value) internal virtual override returns (uint256) {
        uint256 amountAfterTax = value;
        if (launched && enableHighTaxCountdown) {
            if (isAlwaysExempt(to) == false && from != owner && sniperTax() > 0 && isNeverSniper[from] == false && isNeverSniper[to] == false) {
                uint256 taxAmount = value.mul(sniperTax()).div(10000);
                amountAfterTax = amountAfterTax.sub(taxAmount);
            }
        }
        return super.calculateTransferAmount(from, to, amountAfterTax);
    }
    
    // Public methods
    
    function maxHoldAmount() public view returns (uint256) {
        return totalSupply().mul(maxHoldPercentage).div(10000);
    }
    
    function maxSellAmount() public view returns (uint256) {
         return totalSupply().mul(maxSellPercentage).div(10000);
    }
    
   function sniperTax() public view returns (uint256) {
        if(launched) {
            uint256 timeSinceLaunch = block.timestamp - launchTime;
            if (timeSinceLaunch < 100) {
                return uint256(100).sub(timeSinceLaunch).mul(100);
            }
        }
        return 0;
    }
    
    // Admin methods
    
    function configurePinkAntiBot(address antiBot) internal {
        pinkAntiBot = IPinkAntiBot(antiBot);
        pinkAntiBot.setTokenOwner(owner);
        pinkAntiBotConfigured = true;
        enablePinkAntiBot = true;
    }
    
    function setSniperBlocking(bool enabled) public onlyOwner {
        enableSniperBlocking = enabled;
    }
    
    function setBlockLogProtection(bool enabled) public onlyOwner {
        enableBlockLogProtection = enabled;
    }
    
    function setHighTaxCountdown(bool enabled) public onlyOwner {
        enableHighTaxCountdown = enabled;
    }
    
    function setPinkAntiBot(bool enabled) public onlyOwner {
        require(pinkAntiBotConfigured, "pink anti bot is not configured");
        enablePinkAntiBot = enabled;
    }
    
    function setMaxSellPercentage(uint256 amount) public onlyOwner {
        maxSellPercentage = amount;
    }
    
    function setMaxHoldPercentage(uint256 amount) public onlyOwner {
        maxHoldPercentage = amount;
    }
    
    function setIsSniper(address who, bool enabled) public onlyOwner {
        isSniper[who] = enabled;
    }

    function setNeverSniper(address who, bool enabled) public onlyOwner {
        isNeverSniper[who] = enabled;
    }

    // private methods
}