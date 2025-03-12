// SPDX-License-Identifier: MIT

/*  ________  _____ ______   ________   ___  ________  ________  _________   
 *-|\   __  \|\   _ \  _   \|\   ___  \|\  \|\   ____\|\   __  \|\___   ___\--
 *-\ \  \|\  \ \  \\\__\ \  \ \  \\ \  \ \  \ \  \___|\ \  \|\  \|___ \  \_|--
 *--\ \  \\\  \ \  \\|__| \  \ \  \\ \  \ \  \ \  \----\ \   __  \---\ \  \--- 
 *---\ \  \\\  \ \  \----\ \  \ \  \\ \  \ \  \ \  \____\ \  \ \  \---\ \  \--
 *----\ \_______\ \__\----\ \__\ \__\\ \__\ \__\ \_______\ \__\ \__\---\ \__\-
 *-----\|_______|\|__|-----\|__|\|__|-\|__|\|__|\|_______|\|__|\|__|----\|__|-
 */

pragma experimental ABIEncoderV2;
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import './libs/IPancakeSwapV2Factory.sol';
import './libs/IPancakeSwapV2Pair.sol';
import './libs/IPancakeSwapV2Router01.sol';
import './libs/IPancakeSwapV2Router02.sol';
import './libs/intToString.sol';
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';
// The ChainLink Price Feed is used to fetch current price of BNB used to show OmniCat marketcap and price straight from this contract

/*
 *  OmniCat($OCAT) is a fork of TAMARIN which improved the original SAFEMOON contract.
 *  
 *  OmniCat total Supply is 100.000.000.000 (100 Billions).
 *  35% of total supply is being burned since day 1 as Deflationary Mechanism. (The burn address is included here as BURN_ADDRESS and can't be modified)
 *  
 *  $OCAT 10% Taxes are applied to all the token transactions, which is divided as follows:
 *
 *  4% Rewards Tax goes to ALL holders. (Because burn address IS a holder, 35% of every distribution is always BURNED)
 *  3% Burn Tax is being burned.
 *  3% Charities Tax is sent to a Charities CONTRACT (CC), not to a personal wallet. This secondary contract will release funds only 1 time every 14 days
 *  to only 1 specific Wallet owned by a different NONPROFIT each cycle. And no one, not even CC owner/deployer, will be able to access
 *  any OCAT OR BNB tokens being raised on the CC. Thus, preventing any kind of donations scam. In adittion, CC will never send OCAT
 *  tokens to Nonprofits, CC will only send BNB as donations. CC will constantly sell OCAT for BNB in small quantities to not affect market price.
 *
 */

contract OmniCat is Context, IERC20, Ownable {
	using SafeMath for uint256;
	using Address for address;
	using intToString for *;

	mapping (address => uint256) private _rOwned;
	mapping (address => uint256) private _tOwned;
	mapping (address => mapping (address => uint256)) private _allowances;

	mapping (address => bool) private _isExcludedFromFee;
	mapping (address => bool) private _isExcludedFromReward;
	address[] private _excludedFromReward;

	// Charities Contract and the Burn Address for deflation mechanism. This is NOT the final CC address
    // @dev change CC address once CC is deployed on mainnet
    address private CHARITIES_CONTRACT = 0x0000000000000000000000000000000000000000;
	address private BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
	
	//Data Feed address for BNB/USD as shown in https://docs.chain.link/docs/binance-smart-chain-addresses/
	//there is a method to change this address if ChainLink changes it
	//address private CHAINLINK_PRICE_FEED_BNB_USD = 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526; testnet
	address private CHAINLINK_PRICE_FEED_BNB_USD = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE; // Mainnet
	uint256 private constant MAX = ~uint256(0);
	uint256 private _tTotal = 10**11 * 10**8;
	uint256 private _rTotal = (MAX - (MAX % _tTotal));
	uint256 private _tRewardsTotal;

	string private _name = "OmniCat";
	string private _symbol = "OCAT";
	uint8 private _decimals = 8;
	
	uint256 public _maxRewardFee = 5;
	uint256 public _rewardFee = 4;
	uint256 private _previousRewardFee = _rewardFee;
	
	uint256 public _maxCharityFee = 5;
	uint256 public _charityFee = 3;
	uint256 private _previousCharityFee = _charityFee;
	
	uint256 public _maxBurnFee = 5;
	uint256 public _burnFee = 3;
	uint256 private _previousBurnFee = _burnFee;

	uint256 public _totalHolders = 1;

	IPancakeSwapV2Router02 public PancakeSwapV2Router;
	// temporal pair to be able to compile code, constructor creates the real one and changes it on deployment
	IPancakeSwapV2Pair private PancakeSwapV2Pair = IPancakeSwapV2Pair(0x1f814921c047e40bB3090332F6395559FF86f04d);
	
  /* By setting the _maxTxAmount to 0 since contract deployment, it will prevent trades of OmniCat token.
   * Done this way to prevent snipping bots + pre-sale buyers and giveaway winners from trading big ammounts the second
   * liquidity is provided over PancakeSwap.
   * _maxTxAmount will be adjusted once the 20% of total supply is provided as liquidity on PancakeSwap.
   * BUT the max percentage allowed to buy will be set at 0.5% of total supply for a couple of hours.
   * Will gradually increase till reach 100% and stay there. This in the intention to prevent Whales on day one.
   */
    uint256 public _maxTxAmount = 0 * 10**8;
	
	AggregatorV3Interface private priceFeed;

	event TransferBurn(address indexed from, address indexed burnAddress, uint256 value);

	constructor () {
		_rOwned[_msgSender()] = _rTotal;
		//IPancakeSwapV2Router02 _PancakeSwapV2Router = IPancakeSwapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3); testnet
		IPancakeSwapV2Router02 _PancakeSwapV2Router = IPancakeSwapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // Mainnet
		IPancakeSwapV2Pair _PancakeSwapV2Pair = IPancakeSwapV2Pair(IPancakeSwapV2Factory(_PancakeSwapV2Router.factory()).createPair(address(this), _PancakeSwapV2Router.WETH()));
		
        PancakeSwapV2Router = _PancakeSwapV2Router;
        PancakeSwapV2Pair = _PancakeSwapV2Pair;

		priceFeed = AggregatorV3Interface(CHAINLINK_PRICE_FEED_BNB_USD);

		_isExcludedFromFee[owner()] = true;
		_isExcludedFromFee[address(this)] = true;
		_isExcludedFromFee[CHARITIES_CONTRACT] = true;
		
		emit Transfer(address(0), _msgSender(), _tTotal);
	}
    
    function changePancakeRouter(address account) external onlyOwner {
        IPancakeSwapV2Router02 _PancakeSwapV2Router = IPancakeSwapV2Router02(account);
        PancakeSwapV2Router = _PancakeSwapV2Router;
    }
    
	function changeChainLinkPriceFeedBNB(address account) public onlyOwner() {
        CHAINLINK_PRICE_FEED_BNB_USD = account;
    }

	function name() public view returns (string memory) {
	    return _name;
	}
	
	function symbol() public view returns (string memory) {
	    return _symbol;
	}
	
	function decimals() public view returns (uint8) {
	    return _decimals;
	}
	function totalSupply() public view override returns (uint256) {
	    return _tTotal;
	}

	function balanceOf(address account) public view override returns (uint256) {
		if (_isExcludedFromReward[account]) return _tOwned[account];
		return tokenFromReflection(_rOwned[account]);
	}
	// method to fetch BNB market price with ChainLink price feed
	function _getPrice() private view returns (uint) {
        (
            uint80 roundID, 
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
		uint priceF = uint(price);
        return priceF;
    }

	function totalHolders() public view returns (uint256) {
		return _totalHolders;
	}

	function _getOCATPrice_Marketcap() public view returns (uint256 marketcap, string memory price_USD, string memory price_BNB) {
       	(uint256 OCAT, uint256 BNB,) = PancakeSwapV2Pair.getReserves();
        uint256 OCATnoD = OCAT / 10**8;
        uint256 rawPriceBNB = BNB.mul(10**18).div(OCATnoD);
        uint256 rawPriceBNBnoD = rawPriceBNB / 10**18;
        string memory priceBNB = append('0', '.', intToString.uint2str(rawPriceBNBnoD + 1*10**18, true));
        
        uint256 BNBmarketPrice = _getPrice() / 10**8;
        uint256 rawUSDprice = rawPriceBNBnoD.mul(BNBmarketPrice);
        string memory priceUSD = append('0', '.', intToString.uint2str(rawUSDprice + 1*10**18, true));
        
        uint256 totalSupplyMinusBurn = _tTotal.sub(balanceOf(BURN_ADDRESS)).mul(rawUSDprice);
        uint256 mcap = totalSupplyMinusBurn / 10**18 / 10**8; 
        return (mcap, priceUSD, priceBNB);
    }

	function append(string memory a, string memory b, string memory c) internal pure returns (string memory) {
		return string(abi.encodePacked(a, b, c));
    }

	function transfer(address recipient, uint256 amount) public override returns (bool) {
		_transfer(_msgSender(), recipient, amount);
		return true;
	}

	function allowance(address owner, address spender) public view override returns (uint256) {
		return _allowances[owner][spender];
	}

	function approve(address spender, uint256 amount) public override returns (bool) {
		_approve(_msgSender(), spender, amount);
		return true;
	}

	function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
		_transfer(sender, recipient, amount);
		_approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
		return true;
	}

	function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
		_approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
		return true;
	}

	function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
		_approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
		return true;
	}


	function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
		require(tAmount <= _tTotal, "Amount must be less than supply");
		if (!deductTransferFee) {
			(uint256 rAmount,,,,,,) = _getValues(tAmount);
			return rAmount;
		} else {
			(,uint256 rTransferAmount,,,,,) = _getValues(tAmount);
			return rTransferAmount;
		}
	}

	function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
		require(rAmount <= _rTotal, "Amount must be less than total reflections");
		uint256 currentRate =  _getRate();
		return rAmount.div(currentRate);
	}
    function changeCharitiesContract(address account) public onlyOwner() {
        CHARITIES_CONTRACT = account;
    }

    function charitiesContract() public view returns (address) {
        return CHARITIES_CONTRACT;
    }
    
	function isExcludedFromReward(address account) public view returns (bool) {
		return _isExcludedFromReward[account];
	}

	function excludeFromReward(address account) public onlyOwner {
		require(!_isExcludedFromReward[account], "Account is already excluded");
		if(_rOwned[account] > 0) {
			_tOwned[account] = tokenFromReflection(_rOwned[account]);
		}
		_isExcludedFromReward[account] = true;
		_excludedFromReward.push(account);
	}

	function includeInReward(address account) external onlyOwner {
		require(_isExcludedFromReward[account], "Account is already included");
		for (uint256 i = 0; i < _excludedFromReward.length; i++) {
			if (_excludedFromReward[i] == account) {
				_excludedFromReward[i] = _excludedFromReward[_excludedFromReward.length - 1];
				_tOwned[account] = 0;
				_isExcludedFromReward[account] = false;
				_excludedFromReward.pop();
				break;
			}
		}
	}

	function excludeFromFee(address account) public onlyOwner {
		_isExcludedFromFee[account] = true;
	}
	
	function includeInFee(address account) public onlyOwner {
		_isExcludedFromFee[account] = false;
	}
	
	function setRewardFeePercent(uint256 rewardFee) external onlyOwner {
	    require(rewardFee <= _maxRewardFee, 'Tax exceeds maximum 5%');
		_rewardFee = rewardFee;
	}
	
	function setCharityFeePercent(uint256 charityFee) external onlyOwner {
		require(charityFee <= _maxCharityFee, 'Tax exceeds maximum 5%');
		_charityFee = charityFee;
	}
	
	function setBurnFeePercent(uint256 burnFee) external onlyOwner {
		require(burnFee <= _maxBurnFee, 'Tax exceeds maximum 5%');
		_burnFee = burnFee;
	}
	
	function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner {
		_maxTxAmount = _tTotal.mul(maxTxPercent).div(
			10**2
		);
	}
    
	function totalRewards() public view returns (uint256) {
		return _tRewardsTotal;
	}

	function totalBurned() public view returns (uint256) {
		return balanceOf(BURN_ADDRESS);
	}
	
	receive() external payable {}

	function _reflectRewardsFee(uint256 rRewardsFee, uint256 tRewardsFee) private {
		_rTotal = _rTotal.sub(rRewardsFee);
		_tRewardsTotal = _tRewardsTotal.add(tRewardsFee);
	}

	function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
		(uint256 tTransferAmount, uint256 tRewardsFee, uint256 tCharity, uint256 tBurn) = _getTValues(tAmount);
		(uint256 rAmount, uint256 rTransferAmount, uint256 rRewardsFee) = _getRValues(tAmount, tRewardsFee, tCharity, tBurn, _getRate());
		return (rAmount, rTransferAmount, rRewardsFee, tTransferAmount, tRewardsFee, tCharity, tBurn);
	}

	function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256) {
		uint256 tRewardsFee = calculateRewardFee(tAmount);
		uint256 tCharity = calculateCharityFee(tAmount);
		uint256 tBurn = calculateBurnFee(tAmount);
		uint256 tTransferAmount = tAmount.sub(tRewardsFee).sub(tCharity).sub(tBurn);
		return (tTransferAmount, tRewardsFee, tCharity, tBurn);
	}

	function _getRValues(uint256 tAmount, uint256 tRewardsFee, uint256 tCharity, uint256 tBurn, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
		uint256 rAmount = tAmount.mul(currentRate);
		uint256 rRewardsFee = tRewardsFee.mul(currentRate);
		uint256 rCharity = tCharity.mul(currentRate);
		uint256 rBurn = tBurn.mul(currentRate);
		uint256 rTransferAmount = rAmount.sub(rRewardsFee).sub(rCharity).sub(rBurn);
		return (rAmount, rTransferAmount, rRewardsFee);
	}

	function _getRate() private view returns(uint256) {
		(uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
		return rSupply.div(tSupply);
	}

	function _getCurrentSupply() private view returns(uint256, uint256) {
		uint256 rSupply = _rTotal;
		uint256 tSupply = _tTotal;
		for (uint256 i = 0; i < _excludedFromReward.length; i++) {
			if (_rOwned[_excludedFromReward[i]] > rSupply || _tOwned[_excludedFromReward[i]] > tSupply) return (_rTotal, _tTotal);
			rSupply = rSupply.sub(_rOwned[_excludedFromReward[i]]);
			tSupply = tSupply.sub(_tOwned[_excludedFromReward[i]]);
		}
		if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
		return (rSupply, tSupply);
	}
	
	function calculateRewardFee(uint256 _amount) private view returns (uint256) {
		return _amount.mul(_rewardFee).div(
			10**2
		);
	}
	
	function calculateCharityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_charityFee).div(
            10**2
        );
    }

	function calculateBurnFee(uint256 _amount) private view returns (uint256) {
		return _amount.mul(_burnFee).div(
			10**2
		);
	}
	
	function removeAllFee() private {
		if(_rewardFee == 0 && _burnFee == 0 && _charityFee == 0) return;		
		_previousRewardFee = _rewardFee;
		_previousCharityFee = _charityFee;
		_previousBurnFee = _burnFee;		
		_rewardFee = 0;
		_charityFee = 0;
		_burnFee = 0;
	}
	
	function restoreAllFee() private {
		_rewardFee = _previousRewardFee;
		_charityFee = _previousCharityFee;
		_burnFee = _previousBurnFee;
	}
	
	function isExcludedFromFee(address account) public view returns(bool) {
		return _isExcludedFromFee[account];
	}

	function _approve(address owner, address spender, uint256 amount) private {
		require(owner != address(0), "ERC20: approve from the zero address");
		require(spender != address(0), "ERC20: approve to the zero address");
		_allowances[owner][spender] = amount;
		emit Approval(owner, spender, amount);
	}

	function _transfer(
		address from,
		address to,
		uint256 amount
	) private {
		require(from != address(0), "ERC20: transfer from the zero address");
		require(to != address(0), "ERC20: transfer to the zero address");
		require(amount > 0, "Transfer amount must be greater than zero");
		if(from != owner() && to != owner())
			require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
		bool takeFee = true;
		if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
			takeFee = false;
		}
		_tokenTransfer(from,to,amount,takeFee);
	}
	function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
		if(!takeFee)
			removeAllFee();		
		if (_isExcludedFromReward[sender] && !_isExcludedFromReward[recipient]) {
			_transferFromExcluded(sender, recipient, amount);
		} else if (!_isExcludedFromReward[sender] && _isExcludedFromReward[recipient]) {
			_transferToExcluded(sender, recipient, amount);
		} else if (!_isExcludedFromReward[sender] && !_isExcludedFromReward[recipient]) {
			_transferStandard(sender, recipient, amount);
		} else if (_isExcludedFromReward[sender] && _isExcludedFromReward[recipient]) {
			_transferBothExcluded(sender, recipient, amount);
		} else {
			_transferStandard(sender, recipient, amount);
		}		
		if(!takeFee)
			restoreAllFee();
	}

	// this method sends the 3% tax to charities contract and burns 3%
	function _transferBurnAndCharity(uint256 tBurn, uint256 tCharity) private {
		uint256 currentRate = _getRate();
		uint256 rBurn = tBurn.mul(currentRate);
		uint256 rCharity = tCharity.mul(currentRate);
		_rOwned[BURN_ADDRESS] = _rOwned[BURN_ADDRESS].add(rBurn);
		_rOwned[CHARITIES_CONTRACT] = _rOwned[CHARITIES_CONTRACT].add(rCharity);
		
	}

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
		(uint256 rAmount, uint256 rTransferAmount, uint256 rRewardsFee, uint256 tTransferAmount, uint256 tRewardsFee, uint256 tCharity, uint256 tBurn) = _getValues(tAmount);
		_rOwned[sender] = _rOwned[sender].sub(rAmount);
		if(_rOwned[sender] <= 0)
			_totalHolders -= 1;
		if(_rOwned[recipient] <= 0)
			_totalHolders += 1;
		_rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
	    if(!_isExcludedFromFee[sender]){
		_transferBurnAndCharity(tBurn, tCharity);
		_reflectRewardsFee(rRewardsFee, tRewardsFee);
		emit TransferBurn(sender, BURN_ADDRESS, tBurn);
	    }
		emit Transfer(sender, recipient, tTransferAmount);
	}

	function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
		(uint256 rAmount, uint256 rTransferAmount, uint256 rRewardsFee, uint256 tTransferAmount, uint256 tRewardsFee, uint256 tCharity, uint256 tBurn) = _getValues(tAmount);
		_tOwned[sender] = _tOwned[sender].sub(tAmount);
		_rOwned[sender] = _rOwned[sender].sub(rAmount);
		if(_rOwned[sender] <= 0)
			_totalHolders -= 1;
		if(_rOwned[recipient] <= 0)
			_totalHolders += 1;
		_rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
	    if(!_isExcludedFromFee[sender]){
		_transferBurnAndCharity(tBurn, tCharity);
		_reflectRewardsFee(rRewardsFee, tRewardsFee);
		emit TransferBurn(sender, BURN_ADDRESS, tBurn);
	    }
		emit Transfer(sender, recipient, tTransferAmount);
	}
	
	function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
		(uint256 rAmount, uint256 rTransferAmount, uint256 rRewardsFee, uint256 tTransferAmount, uint256 tRewardsFee, uint256 tCharity, uint256 tBurn) = _getValues(tAmount);
		_rOwned[sender] = _rOwned[sender].sub(rAmount);
		if(_rOwned[sender] <= 0)
			_totalHolders -= 1;
		if(_rOwned[recipient] <= 0)
			_totalHolders += 1;
		_tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
		_rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
		 if(!_isExcludedFromFee[sender]){
		_transferBurnAndCharity(tBurn, tCharity);
		_reflectRewardsFee(rRewardsFee, tRewardsFee);
		emit TransferBurn(sender, BURN_ADDRESS, tBurn);
	    }
		emit Transfer(sender, recipient, tTransferAmount);
	}
	
	function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
		(uint256 rAmount, uint256 rTransferAmount, uint256 rRewardsFee, uint256 tTransferAmount, uint256 tRewardsFee, uint256 tCharity, uint256 tBurn) = _getValues(tAmount);
		_tOwned[sender] = _tOwned[sender].sub(tAmount);
		_rOwned[sender] = _rOwned[sender].sub(rAmount);
		if(_rOwned[sender] <= 0)
			_totalHolders -= 1;
		if(_rOwned[recipient] <= 0)
			_totalHolders += 1;
		_tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
		_rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
		 if(!_isExcludedFromFee[sender]){
		_transferBurnAndCharity(tBurn, tCharity);
		_reflectRewardsFee(rRewardsFee, tRewardsFee);
		emit TransferBurn(sender, BURN_ADDRESS, tBurn);
	    }
		emit Transfer(sender, recipient, tTransferAmount);
	}

}



