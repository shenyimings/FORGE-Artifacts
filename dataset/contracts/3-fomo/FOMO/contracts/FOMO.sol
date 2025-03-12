/*
       █████                                                                                                                     
       █████                                                                                                                     
   ██████████████      ██████████████████████          ███████████          ████████               ████████          ███████████     
 █████████████████     ██████████████████████        ███████████████        █████████             █████████        ███████████████   
██████████████████     ██████████████████████      ███████████████████      ██████████           ██████████      ███████████████████ 
██████       █████     ██████████████████████     █████████████████████     ███████████         ███████████     █████████████████████
██████                   ███████       ██████     ████████     ████████     ████████████       ████████████     ████████     ████████
██████                   ███████                  ███████       ███████     █████████████     █████████████     ███████       ███████
███████████████          █████████████████        ███████       ███████     ██████████████   ██████████████     ███████       ███████
 ████████████████        █████████████████        ███████       ███████     ████████ ██████ ██████ ████████     ███████       ███████
   ███████████████       █████████████████        ███████       ███████     ████████  ███████████  ████████     ███████       ███████
            ██████       █████████████████        ███████       ███████     ████████   █████████   ████████     ███████       ███████
            ██████       ███████                  ███████       ███████     ████████    ███████    ████████     ███████       ███████
█████       ██████       ███████                  ████████     ████████     ████████     █████     ████████     ████████     ████████
██████████████████     ███████████                █████████████████████     ████████               ████████     █████████████████████
█████████████████      ███████████                 ███████████████████      ████████               ████████      ███████████████████ 
 ██████████████        ███████████                   ███████████████        ████████               ████████        ███████████████   
      █████            ███████████                     ███████████          ████████               ████████          ███████████     
      █████                                                                                                                      
                                                                                                                                 
  
  Don't be a jeet ser
 */  
 
// SPDX-License-Identifier: MIT

pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
	function addLiquidityETH(address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
}

contract FOMO is ERC20, Ownable {
    using SafeMath for uint256;
	
	address public marketing;
	address public team;
	
	bool public saleFeeEnable;
	bool public buyFeeEnable;
	
    bool private swapping;
	uint256 public swapThreshold;
	
	uint256[] public liqudityFee;
	uint256[] public teamFee;
	uint256[] public marketingFee;
	
	uint256 private liquidityFeeTotal;
    uint256 private marketingFeeTotal;
	uint256 private teamFeeTotal;
	
	IDEXRouter public router;
    address public pair;
	
    mapping(address => bool) public isFeeExempt;
	mapping(address => bool) public isLiquidityPair;
	
    event MarketingWalletUpdated(address newWallet);
	event TeamWalletUpdated(address newWallet);
	event LiquidityPairUpdated(address pair, bool value);
	event WalletExemptFromFee(address wallet, bool value);
	event SwapingThresholdUpdated(uint256 amount);
	event SellFeeStatusUpdated(bool status);
	event BuyFeeStatusUpdated(bool status);
	
    constructor(address owner) ERC20("Daily FOMO", "$FOMO") {
	
		router = IDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pair = IDEXFactory(router.factory()).createPair(address(this), router.WETH());
		
        isLiquidityPair[pair] = true;
		
		isFeeExempt[address(this)] = true;
		isFeeExempt[address(owner)] = true;
		
		marketingFee.push(3);
		marketingFee.push(3);
		
		teamFee.push(0);
		teamFee.push(1);
		
		liqudityFee.push(2);
		liqudityFee.push(2);
		
		saleFeeEnable = true;
	    buyFeeEnable = true;
		
		marketing = address(0xf3fC8B47F1af9B7C239361C18E2A4A185eb35099);
		team = address(0x4b09e00484E782b25fbcE484226Cd0d26003E206);
		
		swapThreshold = 10000 * (10**18);
		_mint(address(owner), 1000000000 * (10**18));
		_transferOwnership(address(owner));
    }
	
	receive() external payable {}
	
    function setMarketingWallet(address newWallet) external onlyOwner{
        require(newWallet != address(0), "setMarketingWallet: Zero address");
        
		marketing = newWallet;
        emit MarketingWalletUpdated(newWallet);
    }
	
	function setTeamWallet(address newWallet) external onlyOwner{
        require(newWallet != address(0), "setTeamWallet: Zero address");
		
		team = newWallet;
        emit TeamWalletUpdated(newWallet);
    }
	
    function walletExemptFromFee(address wallet, bool status) external onlyOwner{
        require(wallet != address(0), "walletExemptFromFee: Zero address");
		
		isFeeExempt[wallet] = status;
        emit WalletExemptFromFee(wallet, status);
    }
	
	function setSwapingThreshold(uint256 amount) external onlyOwner {
  	     require(amount <= totalSupply(), "Amount cannot be over the total supply.");
		 require(amount >= (500 * 10**18), "Amount cannot be less than `500` token.");
		 
		 swapThreshold = amount;
		 emit SwapingThresholdUpdated(amount);
  	}
	
    function setLiquidityPair(address newPair, bool value) external onlyOwner {
        require(pair != newPair, "The pair cannot be removed from isLiquidityPair");
		
        isLiquidityPair[newPair] = value;
        emit LiquidityPairUpdated(newPair, value);
    }
	
	function enableBuyFee() external onlyOwner {
	   require(!buyFeeEnable, "Buy fee already enabled");
	   
	   buyFeeEnable = true;
	   emit BuyFeeStatusUpdated(true);
	}
	
	function disableBuyFee() external onlyOwner {
       require(buyFeeEnable, "Buy fee already disabled");
	   
	   buyFeeEnable = false;
	   emit BuyFeeStatusUpdated(false);
	}
	
	function enableSellFee() external onlyOwner {
       require(!saleFeeEnable, "Sell fee already enabled");
	   
	   saleFeeEnable = true;
	   emit SellFeeStatusUpdated(true);
	}
	
	function disableSellFee() external onlyOwner {
	   require(saleFeeEnable, "Sell fee already disabled");
	   
	   saleFeeEnable = false;
	   emit SellFeeStatusUpdated(false);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override(ERC20){      
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
		
		uint256 contractTokenBalance = balanceOf(address(this));
		bool canSwap = contractTokenBalance >= swapThreshold;
		
		if (!swapping && canSwap && isLiquidityPair[recipient]) 
		{
		    uint256 tokenToLiqudity = liquidityFeeTotal.div(2);
			uint256 tokenToMarketing = marketingFeeTotal;
			uint256 tokenToTeam = teamFeeTotal;
			uint256 tokenToSwap = tokenToLiqudity.add(tokenToMarketing).add(tokenToTeam);
			
			if(tokenToSwap >= swapThreshold) 
			{
			    swapping = true;
				swapTokensForBNB(swapThreshold);
				uint256 newBalance = address(this).balance;
				
				uint256 liqudityPart = newBalance.mul(tokenToLiqudity).div(tokenToSwap);
				uint256 marketingPart = newBalance.mul(tokenToMarketing).div(tokenToSwap);
				uint256 teamPart = newBalance.sub(liqudityPart).sub(marketingPart);
				
				if(liqudityPart > 0)
				{
				    uint256 liqudityToken = swapThreshold.mul(tokenToLiqudity).div(tokenToSwap);
					addLiquidity(liqudityToken, liqudityPart);
					liquidityFeeTotal = liquidityFeeTotal.sub(liqudityToken).sub(liqudityToken);
				}
				if(marketingPart > 0) 
				{
				    payable(marketing).transfer(marketingPart);
					marketingFeeTotal = marketingFeeTotal.sub(swapThreshold.mul(tokenToMarketing).div(tokenToSwap));
				}
				if(teamPart > 0) 
				{
				    payable(team).transfer(teamPart);
					teamFeeTotal = teamFeeTotal.sub(swapThreshold.mul(tokenToTeam).div(tokenToSwap));
				}
				swapping = false; 
			}
		}
		
		if(isFeeExempt[sender] || isFeeExempt[recipient]) 
		{
            super._transfer(sender, recipient, amount);
        }
		else 
		{
		    uint256 allFee = collectFee(amount, isLiquidityPair[recipient], isLiquidityPair[sender]);
			if(allFee > 0) 
			{
			   super._transfer(sender, address(this), allFee);
			}
			super._transfer(sender, recipient, amount.sub(allFee));
        }
    }
	
	function collectFee(uint256 amount, bool sell, bool buy) private returns (uint256) {
	    if(sell && saleFeeEnable)
		{
		    uint256 newLiqudityFee = amount.mul(liqudityFee[1]).div(100);
			uint256 newMarketingFee = amount.mul(marketingFee[1]).div(100);
			uint256 newTeamFee = amount.mul(teamFee[1]).div(100);
			
			liquidityFeeTotal += newLiqudityFee;
			marketingFeeTotal += newMarketingFee;
			teamFeeTotal += newTeamFee;
			return (newMarketingFee.add(newTeamFee).add(newLiqudityFee));
		}
		else if(buy && buyFeeEnable)
		{
		   uint256 newLiqudityFee = amount.mul(liqudityFee[0]).div(100);
		   uint256 newMarketingFee = amount.mul(marketingFee[0]).div(100);
		   uint256 newTeamFee = amount.mul(teamFee[0]).div(100);
		   
		   liquidityFeeTotal += newLiqudityFee;
           marketingFeeTotal += newMarketingFee;
	       teamFeeTotal += newTeamFee;
           return (newMarketingFee.add(newTeamFee).add(newLiqudityFee));
		}
		else
		{
		   return 0;
		}
    }
	
	function swapTokensForBNB(uint256 FOMOAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
		
        _approve(address(this), address(router), FOMOAmount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            FOMOAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }
	
	function addLiquidity(uint256 FOMOAmount, uint256 BNB) private {
        _approve(address(this), address(router), FOMOAmount);
        router.addLiquidityETH{value: BNB}(
            address(this),
            FOMOAmount,
            0, 
            0,
            address(this),
            block.timestamp.add(300)
        );
    }
	
	function WenAirdrop(address[] calldata addresses, uint256[] calldata tokens) external onlyOwner {
		require(addresses.length < 501,"GAS Error: max airdrop limit is 500 addresses");
		require(addresses.length == tokens.length,"Mismatch between Address and token count");
		uint256 antibot = 0;
		for(uint i=0; i < addresses.length; i++){
			antibot = antibot + tokens[i];
		}
		require(balanceOf(msg.sender) >= antibot, "Not enough tokens in wallet");
		for(uint i=0; i < addresses.length; i++){
		   _transfer(address(msg.sender), addresses[i], tokens[i]);
		}
	}
}