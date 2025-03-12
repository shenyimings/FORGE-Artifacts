// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IERC20 {
	
	function totalSupply() external view returns (uint256);
	function balanceOf(address account) external view returns (uint256);
	function transfer(address recipient, uint256 amount) external returns (bool);
	function allowance(address owner, address spender) external view returns (uint256);
	function approve(address spender, uint256 amount) external returns (bool);
	function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
	
	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed owner, address indexed spender, uint256 value);
	event TransferDetails(address indexed from, address indexed to, uint256 total_Amount, uint256 reflected_amount, uint256 total_TransferAmount, uint256 reflected_TransferAmount);
}

abstract contract Context {
	function _msgSender() internal view virtual returns (address) {
		return msg.sender;
	}
}

abstract contract Ownable is Context {
	address private _owner;

	event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
	constructor () {
		_owner = _msgSender();
		emit OwnershipTransferred(address(0), _owner);
	}
	
	function owner() public view virtual returns (address) {
		return _owner;
	}
	
	modifier onlyOwner() {
		require(owner() == _msgSender(), "Ownable: caller is not the owner");
		_;
	}

	function transferOwnership(address newOwner) public virtual onlyOwner {
		require(newOwner != address(0), "Ownable: new owner is the zero address");
		emit OwnershipTransferred(_owner, newOwner);
		_owner = newOwner;
	}

	function renounceOwnership() public virtual onlyOwner {
		address newOwner = address(0);
		emit OwnershipTransferred(_owner, newOwner);
		_owner = newOwner;
	}
}

interface IUniswapV2Factory {
	function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router {
	function factory() external pure returns (address);
	function WETH() external pure returns (address);
}

interface ITaxContract {
	function performTaxSwap() external;
}


contract DripToken is Context, IERC20, Ownable {
	mapping (address => uint256) public _balance_reflected;
	mapping (address => uint256) public _balance_total;    
	mapping (address => mapping (address => uint256)) private _allowances;	
	mapping (address => bool) public _isExcluded;
    mapping(address => bool) public isAdded;
	mapping (address => bool) public isFeeExempt;
    
    address[] public wallets;
	address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;
	address public immutable uniswapV2Pair;
    address[] public _excluded;

	bool public tradingOpen = false;
	bool public swapAndLiquifyEnabled = false;
	bool inSwapAndLiquify;


	uint256 private constant MAX = ~uint256(0);
	uint256 public _contractReflectionStored = 0;	
	uint256 public reflectionFee = 5;
    uint256 public reflectionFeeOld = reflectionFee;	
	uint256 public comboFee = 126;
    uint256 public comboFeeOld = comboFee;		
    uint256 public constant decimals = 18;
    uint256 public constant totalSupply = 10**8 * 10**decimals;
    uint256 private _supply_reflected = (MAX - (MAX % totalSupply));
    uint256 public maxTransaction = totalSupply * 3 / 100;
	uint256 public constant _fee_denominator = 1000;
    uint256 public swapThreshold = totalSupply / 500;

	ITaxContract public taxContract;
	IUniswapV2Router public uniswapV2Router;
    
	string public constant name = "Drip";
	string public constant symbol = "DRIP";

	event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
	event SwapAndLiquify(
		uint256 tokensSwapped,
		uint256 ethReceived,
		uint256 tokensIntoLiqudity
	);

	modifier lockTheSwap {
		inSwapAndLiquify = true;
		_;
		inSwapAndLiquify = false;
	}
	
	constructor () {
		_balance_reflected[owner()] = _supply_reflected;

		
		IUniswapV2Router _uniswapV2Router = IUniswapV2Router(0x10ED43C718714eb63d5aA57B78B54704E256024E);
		uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
		uniswapV2Router = _uniswapV2Router;

		isFeeExempt[msg.sender] = true;
		isFeeExempt[address(this)] = true;
		isFeeExempt[deadAddress] = true;
		
		emit Transfer(address(0), owner(), totalSupply);
	}

	function balanceOf(address account) public view override returns (uint256) {
		if (_isExcluded[account]) return _balance_total[account];
		return tokenFromReflection(_balance_reflected[account]);
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
		require (_allowances[sender][_msgSender()] >= amount,"ERC20: transfer amount exceeds allowance");
		_approve(sender, _msgSender(), (_allowances[sender][_msgSender()]-amount));
		return true;
	}

	function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
		_approve(_msgSender(), spender, (_allowances[_msgSender()][spender] + addedValue));
		return true;
	}

	function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
		require (_allowances[_msgSender()][spender] >= subtractedValue,"ERC20: decreased allowance below zero");
		_approve(_msgSender(), spender, (_allowances[_msgSender()][spender] - subtractedValue));
		return true;
	}

	function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
		require(rAmount <= _supply_reflected, "Amount must be less than total reflections");
		uint256 currentRate =  _getRate();
		return (rAmount / currentRate);
	}

    function addToWallets(address wallet) internal {
        if (!isAdded[wallet]) {
            wallets.push(wallet);
            isAdded[wallet] = true;
        }
    }


	function excludeFromReward(address account) external onlyOwner {
		require(!_isExcluded[account], "Account is already excluded");
		if(_balance_reflected[account] > 0) {
			_balance_total[account] = tokenFromReflection(_balance_reflected[account]);
		}
		_isExcluded[account] = true;
		_excluded.push(account);
	}

	function includeInReward(address account) external onlyOwner {
		require(_isExcluded[account], "Account is already included");
		for (uint256 i = 0; i < _excluded.length; i++) {
			if (_excluded[i] == account) {
				_excluded[i] = _excluded[_excluded.length - 1];
				_balance_total[account] = 0;
				_isExcluded[account] = false;
				_excluded.pop();
				break;
			}
		}
	}

	function updateRouter(address _router) external onlyOwner {
		uniswapV2Router = IUniswapV2Router(_router);
	}

	function updateTaxContract (ITaxContract _taxContract) external onlyOwner {
		taxContract = ITaxContract(_taxContract);
	}

	function goLive() external onlyOwner {
		require(!tradingOpen,"Cannot be executed after going live");
		tradingOpen = true;
		swapAndLiquifyEnabled = true;
	}

    function setMaxTransaction (uint256 _maxTransaction) external onlyOwner {
        require(_maxTransaction >= totalSupply / 1000, "Max Transaction must be greater than 0.1% of supply");
        maxTransaction = _maxTransaction;
    }

	function setSwapSettings(bool _status, uint256 _threshold) external onlyOwner {
		require(_threshold > 0,"swap threshold cannot be 0");
		swapAndLiquifyEnabled = _status;
		swapThreshold = _threshold;
	}

	function manage_excludeFromFee(address[] calldata addresses, bool status) external onlyOwner {
		for (uint256 i; i < addresses.length; ++i) {
			isFeeExempt[addresses[i]] = status;
		}
	}

	function clearStuckBalance(uint256 amountPercentage) external onlyOwner {
		uint256 amountToClear = amountPercentage * address(this).balance / 100;
		payable(msg.sender).transfer(amountToClear);
	}

	function clearStuckToken(address tokenAddress, uint256 tokens) external onlyOwner returns (bool success) {
		if(tokens == 0){
			tokens = IERC20(tokenAddress).balanceOf(address(this));
		}
		return IERC20(tokenAddress).transfer(msg.sender, tokens);
	}

	function _getRate() private view returns(uint256) {
		(uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
		return rSupply / tSupply;
	}

	function _getCurrentSupply() private view returns(uint256, uint256) {
		uint256 rSupply = _supply_reflected;
		uint256 tSupply = totalSupply;
		for (uint256 i = 0; i < _excluded.length; i++) {
			if (_balance_reflected[_excluded[i]] > rSupply || _balance_total[_excluded[i]] > tSupply) return (_supply_reflected, totalSupply);
			rSupply = rSupply - _balance_reflected[_excluded[i]];
			tSupply = tSupply - _balance_total[_excluded[i]];
		}
		if (rSupply < (_supply_reflected/totalSupply)) return (_supply_reflected, totalSupply);
		return (rSupply, tSupply);
	}


	function _getValues(uint256 tAmount) private view returns (
		uint256 rAmount, uint256 rTransferAmount, uint256 rReflection,
		uint256 tTransferAmount, uint256 tReflection, uint256 tCombo) {

		tCombo = ( tAmount * comboFee ) / (_fee_denominator);
		tReflection = ( tAmount * reflectionFee ) / (_fee_denominator);

		tTransferAmount = tAmount - ( tCombo + tReflection);
		rReflection = tReflection * _getRate();
		rAmount = tAmount * _getRate();
		rTransferAmount = tTransferAmount * _getRate();
	}

	function takeFees(uint256 feeAmount, address receiverWallet) private {
		uint256 reflectedReeAmount = feeAmount * _getRate();
		_balance_reflected[receiverWallet] = _balance_reflected[receiverWallet] + reflectedReeAmount;

		if(_isExcluded[receiverWallet]){
			_balance_total[receiverWallet] = _balance_total[receiverWallet] + feeAmount;
		}
		if(feeAmount > 0){
			emit Transfer(msg.sender, receiverWallet, feeAmount);
		}
	}

	function _setAllFees(uint256 _comboFee, uint256 _reflectionFee) internal {
		comboFee = _comboFee;
        reflectionFee = _reflectionFee;
	}

	function set_All_Fees(uint256 _comboFee, uint256 _reflectionFee) external onlyOwner {
		uint256 total_fees =  ( _reflectionFee + _comboFee );
		//fee denominator is 1000, max input is 200.
		require(total_fees <= 200, "Max fee allowed is 20%");
		_setAllFees( _comboFee, _reflectionFee);
	}

    function totalFees() external view returns (uint256) {
        uint256 totalFee = (reflectionFee + comboFee);
        return totalFee;
    }

	function removeAllFee() private {
		reflectionFeeOld = reflectionFee;
        comboFeeOld = comboFee;

		_setAllFees(0,0);
	}
	
	function restoreAllFee() private {
		_setAllFees(comboFeeOld, reflectionFeeOld);
	}

	function transferTaxes() internal lockTheSwap {
		uint256 amountToTransfer = balanceOf(address(this));
		_transfer(address(this), address(taxContract), amountToTransfer);
		try taxContract.performTaxSwap() {
		} catch {
		}
    }


	function _approve(address owner, address spender, uint256 amount) private {
		require(owner != address(0), "ERC20: approve from the zero address");
		require(spender != address(0), "ERC20: approve to the zero address");

		_allowances[owner][spender] = amount;
		emit Approval(owner, spender, amount);
	}

	function _transfer(address from, address to, uint256 amount) private {

		if(!isFeeExempt[from] && !isFeeExempt[to]){
			require(tradingOpen,"Trading not open yet");
			require(amount <= maxTransaction, "Cannot trade more than 3% of supply in one transaction");
		}

		if(!inSwapAndLiquify && from != uniswapV2Pair && swapAndLiquifyEnabled && balanceOf(address(this)) > swapThreshold){
			transferTaxes();
		}
		
		bool takeFee = true;
		if(isFeeExempt[from] || isFeeExempt[to]){
		    takeFee = false;
		    removeAllFee();
		}
		
		(uint256 rAmount, uint256 rTransferAmount, uint256 rReflection, uint256 tTransferAmount, uint256 tReflection, uint256 tCombo ) = _getValues(amount);

		_transferStandard(from, to, amount, rAmount, tTransferAmount, rTransferAmount);

		_supply_reflected = _supply_reflected - rReflection;
		_contractReflectionStored = _contractReflectionStored + tReflection;

        uint256 amountToContract = tCombo;

		if(!takeFee){
		    restoreAllFee();
		} else{
		    takeFees(amountToContract,address(this));
		}

        addToWallets(msg.sender);
        addToWallets(to);
	}

	function _transferStandard(address from, address to, uint256 tAmount, uint256 rAmount, uint256 tTransferAmount, uint256 rTransferAmount) private {
		_balance_reflected[from]    = _balance_reflected[from]  - rAmount;

		if (_isExcluded[from]){
		    _balance_total[from]    = _balance_total[from]      - tAmount;
		}

		if (_isExcluded[to]){
		    _balance_total[to]      = _balance_total[to]        + tTransferAmount;
		}
		_balance_reflected[to]      = _balance_reflected[to]    + rTransferAmount;

		if(tTransferAmount > 0){
			emit Transfer(from, to, tTransferAmount);	
		}
	}
}