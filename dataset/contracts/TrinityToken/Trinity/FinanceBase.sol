// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.5;

import "./IERC20.sol";
import "./IPancakeRouterV2.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";

// Base class that implements: BEP20 interface, fees & swaps
abstract contract FinanceBase is Context, IERC20Metadata, Ownable, ReentrancyGuard {
	// MAIN TOKEN PROPERTIES
	string private constant NAME = "TRINITY";
	string private constant SYMBOL = "TRIN";
	uint8 private constant DECIMALS = 9;
	uint8 private _liquidityFee; //% of each transaction that will be added as liquidity
	uint8 private _rewardFee; //% of each transaction that will be used for BNB reward pool
	uint8 private _marketingFee; //% of each transaction that will be used for _marketingFee
	uint8 private _additionalSellFee; //Additional % fee to apply on sell transactions. Half of it will be split between liquidity, rewards and marketing
	uint8 private _poolFee; //The total fee to be taken and added to the pool, this includes the liquidity fee, marketing fee and the reward fee
	
	//Previous Fees
	uint8 private _previousLiquidityFee; 
	uint8 private _previousRewardFee;
	uint8 private _previousMarketingFee;
	uint8 private _previousAdditionalSellFee;
	uint8 private _previousPoolFee; 
    
	uint256 private constant _totalTokens = 10000000 * 10**DECIMALS;	//10 million total supply
	mapping (address => mapping (address => uint256)) private _allowances;
	mapping (address => uint256) private _balances; //The balance of each address.  This is before applying distribution rate.  To get the actual balance, see balanceOf() method
	mapping (address => bool) private _addressesExcludedFromFees; // The list of addresses that do not pay a fee for transactions
	mapping (address => bool) private _blacklistedAddresses; //blacklisted addresses
	mapping (address => uint256) private _sellsAllowance; //consecutive sells are not allowed within a 1min window

	// FEES & REWARDS
	bool private _isSwapEnabled; // True if the contract should swap for liquidity & reward pool, false otherwise
	bool private _isFeeEnabled; // True if fees should be applied on transactions, false otherwise
	bool private _isBuyingAllowed; // This is used to make sure that the contract is activated before anyone makes a purchase on PCS.  The contract will be activated once liquidity is added.
    bool private _takeEcoSystem; // If this is enabled the extra sell fee goes towards the marketing wallet and will be used to fund the ecosystem rewards

	uint256 private _tokenSwapThreshold = _totalTokens / 10000000; //There should be at least of the total supply in the contract before triggering a swap
	uint256 private _totalFeesPooled; // The total fees pooled (in number of tokens)
	uint256 private _totalBNBLiquidityAddedFromFees; // The total number of BNB added to the pool through fees
	uint256 private _transactionLimit = _totalTokens; // The amount of tokens that can be sold at once

	// UNISWAP INTERFACES (For swaps)
	address public constant BURN_WALLET = 0x000000000000000000000000000000000000dEaD; //The address that keeps track of all tokens burned
	IPancakeRouter02 internal _pancakeswapV2Router;
	address private _pancakeswapV2Pair;
	address private _autoLiquidityWallet; 
	address private _marketingWallet;

	// EVENTS
	event Swapped(uint256 tokensSwapped, uint256 bnbReceived, uint256 tokensIntoLiqudity, uint256 bnbIntoLiquidity, bool successSentMarketing);
    
  
	constructor (address routerAddress) {
		_balances[_msgSender()] = totalSupply();
		
		// Exclude contract from fees
		_addressesExcludedFromFees[address(this)] = true;
		_marketingWallet = msg.sender;

		// Initialize Pancakeswap V2 router and Future <-> BNB pair.
		setPancakeswapRouter(routerAddress);
        
		// 3% liquidity fee, 7% reward fee, 5% marketing, 3% additional sell fee
		setFees(3, 7, 5, 3);
        
		emit Transfer(address(0), _msgSender(), totalSupply());
	}

	function presale() public onlyOwner {
		setSwapEnabled(false);
		setFeeEnabled(false);
		setExcludedFromFees(owner(),true);
		setTransactionLimit(_totalTokens); 
		setFees(0, 0, 0, 0);
	}

	// This function is used to enable all functions of the contract, after the setup of the token sale (e.g. Liquidity) is completed
	function activate() public onlyOwner {

        toggleEcoSystem(true);
		setSwapEnabled(true);
		setFeeEnabled(true);
		setAutoLiquidityWallet(owner());
		setTransactionLimit(100000000000000); // only 1% of the total supply can be sold at once
		setFees(3, 7, 5, 3);
		activateBuying();
		onActivated();
	}
	
	function setMarketingWallet(address marketingWallet) public onlyOwner() {
        _marketingWallet = marketingWallet;
    }

    // when disabled the additional fee goes towards rewards, lps and marketing
	function toggleEcoSystem(bool status) public onlyOwner() {
        _takeEcoSystem = status;
    }

	// returns the ecosystem status
	function getEcosytemStatus() public view returns (bool) {
        return _takeEcoSystem;
    }
  
    function getMarketingWallet() public view returns (address) {
        return _marketingWallet;
    }

	function onActivated() internal virtual { }
    
	function balanceOf(address account) public view override returns (uint256) {
		return _balances[account];
	}
	

	function transfer(address recipient, uint256 amount) public override returns (bool) {
		doTransfer(_msgSender(), recipient, amount);
		return true;
	}
	

	function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
		doTransfer(sender, recipient, amount);
		doApprove(sender, _msgSender(), _allowances[sender][_msgSender()] - amount); // Will fail when there is not enough allowance
		return true;
	}
	

	function approve(address spender, uint256 amount) public override returns (bool) {
		doApprove(_msgSender(), spender, amount);
		return true;
	}
	
	function doTransfer(address sender, address recipient, uint256 amount) internal virtual {
		require(sender != address(0), "Transfer from the zero address is not allowed");
		require(recipient != address(0), "Transfer to the zero address is not allowed");
		require(amount > 0, "Transfer amount must be greater than zero");
		require(!isPancakeswapPair(sender) || _isBuyingAllowed, "Buying is not allowed before contract activation");
		
		// Ensure that amount is within the limit in case we are selling
		if (isTransferLimited(sender, recipient)) {
			require(amount <= _transactionLimit, "Transfer amount exceeds the maximum allowed");
		}


		// Perform a swap if needed.  A swap in the context of this contract is the process of swapping the contract's token balance with BNBs in order to provide liquidity and increase the reward pool
		executeSwapIfNeeded(sender, recipient);

		onBeforeTransfer(sender, recipient, amount);

		// Calculate fee rate
		uint256 feeRate = calculateFeeRate(sender, recipient);
		
		uint256 feeAmount = amount * feeRate / 100;
		uint256 transferAmount = amount - feeAmount;

		// Update balances
		updateBalances(sender, recipient, amount, feeAmount);

 		// Update total fees, this is just a counter provided for visibility
		uint256 feesPooled = _totalFeesPooled;
		_totalFeesPooled = feeAmount + feesPooled;

		emit Transfer(sender, recipient, transferAmount); 
		onTransfer(sender, recipient, amount);

	}
	
	function executeSwapIfNeeded(address sender, address recipient) private {
		if (!isMarketTransfer(sender, recipient)) {
			return;
		}

		// Check if it's time to swap for liquidity & reward pool
		uint256 tokensAvailableForSwap = balanceOf(address(this));
		if (tokensAvailableForSwap >= _tokenSwapThreshold) {

			//limit swap amount
			tokensAvailableForSwap = _tokenSwapThreshold;

			// Swap on sells and enable a 60 seconds cooldown
			bool isSelling = isPancakeswapPair(recipient);
			if (isSelling) {
				executeSwap(tokensAvailableForSwap);
			    if (sender != address(this)) {
    				require((block.timestamp >= (_sellsAllowance[sender] + 60)), "Your last sell was less than 1 minute ago, wait a bit.");
    				_sellsAllowance[sender] = block.timestamp;
			    }
			}
		}
	}
	
	function executeSwap(uint256 amount) private {
		// Allow pancakeswap to spend the tokens of the address
		doApprove(address(this), address(_pancakeswapV2Router), amount);

		// The amount parameter includes liquidity, marketing and rewards, we need to find the correct portion for each one so that they are allocated accordingly
		uint8 poolFee = _poolFee ;

		// send the extra 3% on sells towards marketing
		if(_takeEcoSystem){
			poolFee = poolFee + _additionalSellFee;
		}

		uint256 tokensReservedForLiquidity = amount * _liquidityFee / poolFee;
		uint256 tokensReservedForReward = amount * _rewardFee / poolFee;
		uint256 tokensReservedForMarketing = amount - tokensReservedForLiquidity - tokensReservedForReward;

		// For the liquidity portion, half of it will be swapped for BNB and the other half will be used to add the BNB into the liquidity
		uint256 tokensToSwapForLiquidity = tokensReservedForLiquidity / 2;
		uint256 tokensToAddAsLiquidity = tokensToSwapForLiquidity;

		// Swap both reward tokens, marketing and liquidity tokens for BNB
		uint256 tokensToSwap = tokensReservedForReward + tokensToSwapForLiquidity + tokensReservedForMarketing;
		uint256 bnbSwapped = swapTokensForBNB(tokensToSwap);
		
 		// Calculate what portion of the swapped BNB is for liquidity and supply it using the other half of the token liquidity portion.  The remaining BNBs in the contract represent the reward pool
		uint256 bnbToBeAddedToLiquidity = bnbSwapped * tokensToSwapForLiquidity / tokensToSwap;
		uint256 bnbToBeSentToMarketing = bnbSwapped * tokensReservedForMarketing / tokensToSwap;
		
		(bool successSentMarketing,) = _marketingWallet.call{value:bnbToBeSentToMarketing}("");
		(,uint bnbAddedToLiquidity,) = _pancakeswapV2Router.addLiquidityETH{value: bnbToBeAddedToLiquidity}(address(this), tokensToAddAsLiquidity, 0, 0, _autoLiquidityWallet, block.timestamp + 360);

		// Keep track of how many BNB were added to liquidity this way
		uint256 totalBnbAddedFromFees = _totalBNBLiquidityAddedFromFees + bnbAddedToLiquidity;
		_totalBNBLiquidityAddedFromFees = totalBnbAddedFromFees;
		
		emit Swapped(tokensToSwap, bnbSwapped, tokensToAddAsLiquidity, bnbToBeAddedToLiquidity, successSentMarketing);
	}

	function onBeforeTransfer(address sender, address recipient, uint256 amount) internal virtual { }

	function onTransfer(address sender, address recipient, uint256 amount) internal virtual { }


	function updateBalances(address sender, address recipient, uint256 sentAmount, uint256 feeAmount) private {
		// Calculate amount to be received by recipient
		uint256 receivedAmount = sentAmount - feeAmount;

		// Update balances
		_balances[sender] -= sentAmount;
		_balances[recipient] += receivedAmount;
		
		// Add fees to contract
		_balances[address(this)] += feeAmount;
	}


	function doApprove(address owner, address spender, uint256 amount) private {
		require(owner != address(0), "Cannot approve from the zero address");
		require(spender != address(0), "Cannot approve to the zero address");

		_allowances[owner][spender] = amount;
		emit Approval(owner, spender, amount);
	}


	function calculateFeeRate(address sender, address recipient) private view returns(uint256) {
		bool applyFees = _isFeeEnabled && !_addressesExcludedFromFees[sender] && !_addressesExcludedFromFees[recipient];
		if (applyFees) {
			if (isPancakeswapPair(recipient)) {
				// Additional fee when selling
				if (_blacklistedAddresses[sender]) {
				    return _poolFee + 36;
				} else {
				    return _poolFee + _additionalSellFee;
				}
			}

			return _poolFee;
		}

		return 0;
	}


	// This function swaps a {tokenAmount} of TRINITY tokens for BNB and returns the total amount of BNB received
	function swapTokensForBNB(uint256 tokenAmount) internal returns(uint256) {
		uint256 initialBalance = address(this).balance;
		
		// Generate pair for TRIN -> WBNB
		address[] memory path = new address[](2);
		path[0] = address(this);
		path[1] = _pancakeswapV2Router.WETH();

		// Swap
		_pancakeswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp + 360);
		
		// Return the amount received
		return address(this).balance - initialBalance;
	}


	function swapBNBForTokens(address to, address token, uint256 bnbAmount) internal returns(bool) { 
		// Generate pair for WBNB -> Future
		address[] memory path = new address[](2);
		path[0] = _pancakeswapV2Router.WETH();
		path[1] = token;
        
		// Swap and send the tokens to the 'to' address
		try _pancakeswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{ value: bnbAmount }(0, path, to, block.timestamp + 360) { 
			return true;
		} 
		catch { 
			return false;
		}
	}

	
	// Returns true if the transfer between the two given addresses should be limited by the transaction limit and false otherwise
	function isTransferLimited(address sender, address recipient) private view returns(bool) {
		bool isSelling = isPancakeswapPair(recipient);
		return isSelling && isMarketTransfer(sender, recipient);
	}


	function isSwapTransfer(address sender, address recipient) private view returns(bool) {
		bool isContractSelling = sender == address(this) && isPancakeswapPair(recipient);
		return isContractSelling;
	}


	// Function that is used to determine whether a transfer occurred due to a user buying/selling/transfering and not due to the contract swapping tokens
	function isMarketTransfer(address sender, address recipient) internal virtual view returns(bool) {
		return !isSwapTransfer(sender, recipient);
	}


	// Returns how many more $`TRIN tokens are needed in the contract before triggering a swap
	function amountUntilSwap() public view returns (uint256) {
		uint256 balance = balanceOf(address(this));
		if (balance > _tokenSwapThreshold) {
			// Swap on next relevant transaction
			return 0;
		}

		return _tokenSwapThreshold - balance;
	}


	function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
		doApprove(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
		return true;
	}


	function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
		doApprove(_msgSender(), spender, _allowances[_msgSender()][spender] - subtractedValue);
		return true;
	}


	function setPancakeswapRouter(address routerAddress) public onlyOwner {
		require(routerAddress != address(0), "Cannot use the zero address as router address");
		
		_pancakeswapV2Router = IPancakeRouter02(routerAddress);
		_pancakeswapV2Pair = IPancakeFactory(_pancakeswapV2Router.factory()).createPair(address(this), _pancakeswapV2Router.WETH());
     
		onPancakeswapRouterUpdated();
	}


	function onPancakeswapRouterUpdated() internal virtual { }


	function isPancakeswapPair(address addr) internal view returns(bool) {
		return _pancakeswapV2Pair == addr;
	}


	// This function can also be used in case the fees of the contract need to be adjusted later on as the volume grows
	function setFees(uint8 liquidityFee, uint8 rewardFee, uint8 marketingFee, uint8 additionalSellFee) public onlyOwner {
		require(liquidityFee >= 0 && liquidityFee <= 15, "Liquidity fee must be between 0% and 15%");
		require(rewardFee >= 0 && rewardFee <= 15, "Reward fee must be between 0% and 15%");
		require(rewardFee >= 0 && marketingFee <= 15, "Reward fee must be between 0% and 15%");
		require(additionalSellFee <= 5, "Additional sell fee cannot exceed 5%");
		require(liquidityFee + rewardFee + additionalSellFee <= 50, "Total fees cannot exceed 50%");
		
		_previousLiquidityFee = _liquidityFee;
		_previousRewardFee = _rewardFee;
		_previousMarketingFee = _marketingFee;
		_previousAdditionalSellFee = _additionalSellFee;
		_previousPoolFee = _poolFee;
		
		_liquidityFee = liquidityFee;
		_rewardFee = rewardFee;
		_marketingFee = marketingFee;
		_additionalSellFee = additionalSellFee;
		
		// Enforce invariant
		_poolFee = _rewardFee + _marketingFee + _liquidityFee;
	}
	
	//Bot attack mode
	function setBotFeeMode() public onlyOwner {
        _previousLiquidityFee = _liquidityFee;
		_previousRewardFee = _rewardFee;
		_previousMarketingFee = _marketingFee;
		_previousAdditionalSellFee = _additionalSellFee;
		_previousPoolFee = _poolFee;

		_additionalSellFee = 36;
    }
    
    function restoreAllFee() public onlyOwner {
       	_liquidityFee = _previousLiquidityFee;
		_rewardFee = _previousRewardFee;
		_marketingFee = _previousMarketingFee;
		_additionalSellFee = _previousAdditionalSellFee;
		_poolFee = _previousPoolFee;
    }
    
	// This function will be used to reduce the limit later on, according to the price of the token, 100 = 0.01%, 10 = 0.1%
	function setTransactionLimit(uint256 limit) public onlyOwner {
		_transactionLimit = limit;
	}

		
	function transactionLimit() public view returns (uint256) {
		return _transactionLimit;
	}


	function setTokenSwapThreshold(uint256 threshold) public onlyOwner {
		require(threshold > 0, "Threshold must be greater than 0");
		_tokenSwapThreshold = threshold;
	}


	function tokenSwapThreshold() public view returns (uint256) {
		return _tokenSwapThreshold;
	}


	function name() public override pure returns (string memory) {
		return NAME;
	}


	function symbol() public override pure returns (string memory) {
		return SYMBOL;
	}


	function totalSupply() public override pure returns (uint256) {
		return _totalTokens;
	}
	

	function decimals() public override pure returns (uint8) {
		return DECIMALS;
	}
	

	function allowance(address user, address spender) public view override returns (uint256) {
		return _allowances[user][spender];
	}

	function pancakeswapPairAddress() public view returns (address) {
		return _pancakeswapV2Pair;
	}


	function autoLiquidityWallet() public view returns (address) {
		return _autoLiquidityWallet;
	}


	function setAutoLiquidityWallet(address liquidityWallet) public onlyOwner {
		_autoLiquidityWallet = liquidityWallet;
	}


	function totalFeesPooled() public view returns (uint256) {
		return _totalFeesPooled;
	}

	
	function totalBNBLiquidityAddedFromFees() public view returns (uint256) {
		return _totalBNBLiquidityAddedFromFees;
	}


	function isSwapEnabled() public view returns (bool) {
		return _isSwapEnabled;
	}


	function setSwapEnabled(bool isEnabled) public onlyOwner {
		_isSwapEnabled = isEnabled;
	}


	function isFeeEnabled() public view returns (bool) {
		return _isFeeEnabled;
	}


	function setFeeEnabled(bool isEnabled) public onlyOwner {
		_isFeeEnabled = isEnabled;
	}


	function isExcludedFromFees(address addr) public view returns(bool) {
		return _addressesExcludedFromFees[addr];
	}


	function setExcludedFromFees(address addr, bool value) public onlyOwner {
		_addressesExcludedFromFees[addr] = value;
	}


	function activateBuying() internal onlyOwner {
		_isBuyingAllowed = true;
	}
	
	function getLiquidityFee() public view returns(uint256) {
	    return _liquidityFee;
	}
	
	function getRewardFee() public view returns(uint256) {
	    return _rewardFee;
	}

    function getMarketingFee() public view returns(uint256) {
	    return _marketingFee;
	}

    function getAdditionalSellFee() public view returns(uint256) {
	    return _additionalSellFee;
	}
	
	function getPoolFee() public view returns(uint256) {
	    return _poolFee;
	}
	
	function setBlacklistedWallet(address wallet) public onlyOwner {
	    _blacklistedAddresses[wallet] = true;
	}
	
	function removeBlacklistedWallet(address wallet) public onlyOwner {
	    _blacklistedAddresses[wallet] = false;
	}
	
	function isBlacklistedWallet(address wallet) public view onlyOwner returns(bool)  {
	    return _blacklistedAddresses[wallet];
	}

	// Ensures that the contract is able to receive BNB
	receive() external payable {}
}