// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./IUniswapV2Factory.sol";
import "./IUniswapV2Router.sol";

contract WToken is Context, IERC20, IERC20Metadata, Ownable {
    using SafeMath for uint256;
    
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;

    address private projectAddress = 0xD5436D6e0C7791761A751Eeb5Eabc81e70b193FA;
    address private fundingAddress = 0x170f9d2a442CD78f7b2d0694dD012bBD02200515;
    address private liquidityWalletAddress = 0xD5436D6e0C7791761A751Eeb5Eabc81e70b193FA;
    
    uint256 private _tTotal = 100000000 * (10**18);
    uint256 private fundAmount = (_tTotal / 100);
    string private _name = "WohpeDao";
    string private _symbol = "PEACE";
    uint8 private _decimals = 18;
    
    uint256 private _projectFee = 7;
    uint256 private _previousProjectFee = _projectFee;
    
    uint256 private _liquidityFee = 1;
    uint256 private _previousLiquidityFee = _liquidityFee;

    uint256 private _fundingFee = 1;
    uint256 private _previousFundingFee = _fundingFee;

    uint256 private _burnFee = 1;
    uint256 private _previousBurnFee = _burnFee;

    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    
    bool private inSwapAndLiquify;
    bool private swapAndLiquifyEnabled = true;
    bool private presaleEnded = false;
    bool private isMaxTokensCanHold = true;
    
    uint256 private _maxTxAmount = 100000000 * (10**18);
    uint256 private _maxTokensCanHoldPerMille = 10;
    uint256 private _maxTokensCanHold = (_tTotal * _maxTokensCanHoldPerMille) / 1000; 
    uint256 private swapTokensAtAmount = 10000 * (10**18);
    uint256 private swapCoolDownTime = 0;
    
    uint256 private lastSwapTime;

    bool private killDeadBlocks = true;
    uint256 private blockLaunchedAt;
    uint256 private deadBlocks = 2;

    event SwapAndLiquifyEnabledUpdated(bool enabled); 
    event ExcludedFromFee(address account);
    event IncludedToFee(address account);
    event UpdateFees(uint256 projectFee, uint256 liquidityFee, uint256 burnFee, uint256 fundingFee);
    event UpdatedMaxTxAmount(uint256 maxTxAmount);
    event UpdateSwapTokensAtAmount(uint256 amount);
    event SwapAndLiquified(uint256 tokensSwapped, uint256 tokensIntoLiqudity, uint256 ethIntoLiqudity);
    event SwapAndCharged(uint256 tokensSwapped, uint256 ethCharged);
    event UpdatedCoolDowntime(uint256 timeForContract);
    event UpdatedMaxTokensCanHoldPerMille(uint256 perMille);
    event UpdatedIsMaxTokensCanHold(bool value);

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    constructor () {
        //Test Net  
	
	//IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
        
	//Main Net
        
	IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        
        //exclude owner and this contract from fee
        _isExcludedFromFee[_msgSender()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[liquidityWalletAddress] = true;
	_isExcludedFromFee[fundingAddress] = true;
	_balances[_msgSender()] = (_tTotal - fundAmount);
	_balances[fundingAddress] = fundAmount;

        emit Transfer(address(0), _msgSender(), (_tTotal - fundAmount));
	emit Transfer(address(0), fundingAddress, fundAmount);
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }
    
    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function getOwner() public view returns (address) {
        return owner();
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
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

    function setCoolDownTime(uint256 timeForContract) external onlyOwner {
        require(swapCoolDownTime != timeForContract);
        swapCoolDownTime = timeForContract;
        emit UpdatedCoolDowntime(timeForContract);
    }

    function updatePresaleStatus(bool status) external onlyOwner {
        presaleEnded = status;
    }
    
    function excludeFromFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = true;
        emit ExcludedFromFee(account);
    }
    
    function includeInFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = false;
        emit IncludedToFee(account);
    }
    
    function setFees(uint256 projectFee, uint256 liquidityFee, uint256 burnFee, uint256 fundingFee) external onlyOwner {
        require(_projectFee != projectFee || _liquidityFee != liquidityFee || _burnFee != burnFee || _fundingFee != fundingFee);
        _projectFee = projectFee;
        _liquidityFee = liquidityFee;
	_burnFee = burnFee;
	_fundingFee = fundingFee;
        emit UpdateFees(projectFee, liquidityFee, burnFee, fundingFee);
    }

    function setProjectAddress(address account) external onlyOwner {
	require(account != projectAddress, "can't set to the same address");
	projectAddress = account;
    }

    function setFundingAddress(address account) external onlyOwner {
	require(account != fundingAddress, "can't set to the same address");
	fundingAddress = account;
	_isExcludedFromFee[account] = true;
    }

    function setLiquidityWalletAddress(address account) external onlyOwner {
        require(account != liquidityWalletAddress, "can't set to same address");
        liquidityWalletAddress = account;
    }
   
    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner {
        require(_maxTxAmount != maxTxAmount, "can't set to the same value");
	_maxTxAmount = maxTxAmount;
        emit UpdatedMaxTxAmount(maxTxAmount);
    }

    function setKillDeadBlocks(bool value) external onlyOwner {
        require(killDeadBlocks != value, "can't set to teh same value");
        killDeadBlocks = value;
    }

    function setMaxTokensCanHoldPerMille(uint256 perMille) external onlyOwner {
	require(_maxTokensCanHoldPerMille != perMille, "can't set to the same value");
        _maxTokensCanHoldPerMille = perMille;
	emit UpdatedMaxTokensCanHoldPerMille(perMille);
    }

    function setIsMaxTokensCanHold(bool value) external onlyOwner {
        require(isMaxTokensCanHold != value, "can't set to the same value");
        isMaxTokensCanHold = value;
	emit UpdatedIsMaxTokensCanHold(value);
    }

    function getIsMaxTokensCanHold() external view returns (bool) {
        return isMaxTokensCanHold;
    }
    
    function setSwapTokensAtAmount(uint256 amount) external onlyOwner {
        require(swapTokensAtAmount != amount);
        swapTokensAtAmount = amount;
        emit UpdateSwapTokensAtAmount(amount);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
    
    receive() external payable {}

    function _getFeeValues(uint256 tAmount) private view returns (uint256) {
        uint256 fee = tAmount.mul(_projectFee + _liquidityFee + _burnFee + _fundingFee).div(100);
        uint256 tTransferAmount = tAmount.sub(fee);
        return tTransferAmount;
    }

    function removeAllFee() private {
        if (_projectFee == 0 && _liquidityFee == 0 && _burnFee == 0 && _fundingFee == 0) return;
        
        _previousProjectFee = _projectFee;
        _previousLiquidityFee = _liquidityFee;
	_previousFundingFee = _fundingFee;
	_previousBurnFee = _burnFee;
        
        _projectFee = 0;
        _liquidityFee = 0;
	_fundingFee = 0;
	_burnFee = 0;
    }

    function setBuyFeeAndStore(uint256 projectFee, uint256 liquidityFee, uint256 burnFee, uint256 fundingFee) private {
        _previousProjectFee = _projectFee;
        _previousLiquidityFee = _liquidityFee;
        _previousFundingFee = _fundingFee;
        _previousBurnFee = _burnFee;

	_projectFee = projectFee;
	_liquidityFee = liquidityFee;
	_fundingFee = fundingFee;
	_burnFee = burnFee;
    }

    function restoreAllFee() private {
        _projectFee = _previousProjectFee;
        _liquidityFee = _previousLiquidityFee;
	_fundingFee = _previousFundingFee;
	_burnFee = _previousBurnFee;
    }
    
    function isExcludedFromFee(address account) external view returns(bool) {
        return _isExcludedFromFee[account];
    }

   function launched() private view returns (bool) {
        return blockLaunchedAt != 0;
   }

   function launch() private {
        blockLaunchedAt = block.number;
   }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    function _burn(address account, uint256 amount) private {
	require(account != address(0), "ERC20: burn from the zero address");

	uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _tTotal -= amount;

        emit Transfer(account, address(0), amount);
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
        
	if (to == uniswapV2Pair && balanceOf(uniswapV2Pair) == 0) {
            require(presaleEnded == true, "You are not allowed to add liquidity before presale is ended");
        }

	if (!launched() && to == uniswapV2Pair) { 
            require(balanceOf(from) > 0); 
            launch(); 
	}

        if(
            !_isExcludedFromFee[from] && 
            !_isExcludedFromFee[to] && 
            balanceOf(uniswapV2Pair) > 0 && 
            !inSwapAndLiquify &&
            from != address(uniswapV2Router) && 
            (from == uniswapV2Pair || to == uniswapV2Pair)
        ) {
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");          
        }
	
	if ((to != uniswapV2Pair && isMaxTokensCanHold) && (!_isExcludedFromFee[from] || !_isExcludedFromFee[to])) {
            uint256 heldTokens = balanceOf(to);
	    require(heldTokens + amount <= _maxTokensCanHold, "Total Holding is currently limited, you can not buy that much");
	}

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 tokenBalance = balanceOf(address(this));
        
	if (tokenBalance >= _maxTxAmount)
        {
            tokenBalance = _maxTxAmount;
        }
        
        bool overMinTokenBalance = tokenBalance >= swapTokensAtAmount;
        uint256 feeTotal = _burnFee + _liquidityFee + _fundingFee + _projectFee;

	if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled &&
            block.timestamp >= lastSwapTime + swapCoolDownTime
        ) {
            uint256 swapTokens = tokenBalance.mul(_liquidityFee + _projectFee + _fundingFee).div(feeTotal);
	    swapAndLiquify(swapTokens);

	    _burn(address(this), tokenBalance.mul(_burnFee).div(feeTotal));

            lastSwapTime = block.timestamp;
        }
        
        //indicates if fee should be deducted from transfer
        bool takeFee = false;
        
	if (balanceOf(uniswapV2Pair) > 0 && (from == uniswapV2Pair || to == uniswapV2Pair)) {
            takeFee = true;
        }
        
        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }
        
        //transfer amount, it will take tax, burn, liquidity fee
        if (blockLaunchedAt + 3 > block.number && killDeadBlocks && takeFee) {
          
	    _balances[from] = _balances[from].sub(amount);
	    
	    _burn(from, amount.mul(84).div(100));
	    _balances[projectAddress] = _balances[projectAddress].add(amount.mul(5).div(100));
            _balances[fundingAddress] = _balances[fundingAddress].add(amount.mul(1).div(100));
            _balances[to] = _balances[to].add(amount.mul(10).div(100));

	    emit Transfer(from, to, amount.mul(10).div(100));
	    
	} else {
	    _tokenTransfer(from, to, amount, takeFee);
	}
    }

    function swapAndLiquify(uint256 swapTokens) private lockTheSwap {
        uint256 liquidityTokens = swapTokens.mul(_liquidityFee).div(_liquidityFee + _projectFee + _fundingFee).div(2);
	uint256 otherPart = swapTokens.sub(liquidityTokens);
	
        uint256 initialBalance = address(this).balance;

        swapTokensForEth(otherPart); 

        uint256 newBalance = address(this).balance.sub(initialBalance);

	(bool successProject,) = projectAddress.call{value: newBalance.mul(_projectFee).div(_fundingFee + _liquidityFee + _projectFee)}("");
	if (successProject) {
		emit SwapAndCharged(swapTokens, newBalance.mul(_projectFee).div(_fundingFee + _liquidityFee + _projectFee));
	}

	(bool successFunding,) = fundingAddress.call{value: newBalance.mul(_fundingFee).div(_fundingFee + _liquidityFee + _projectFee)}("");
	if (successFunding) {
		emit SwapAndCharged(swapTokens, newBalance.mul(_fundingFee).div(_fundingFee + _liquidityFee + _projectFee));
	}


        addLiquidity(liquidityTokens, newBalance.mul(_liquidityFee).div(_fundingFee + _liquidityFee + _projectFee).div(2));

        emit SwapAndLiquified(swapTokens, liquidityTokens, newBalance.mul(_liquidityFee).div(_fundingFee + _liquidityFee + _projectFee).div(2));
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            liquidityWalletAddress,
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
        
	if (!takeFee) {
            removeAllFee();
	}

	if (sender == uniswapV2Pair && takeFee) {
            setBuyFeeAndStore(5, 1, 1, 1);
        }

        uint256 tTransferAmount = _getFeeValues(amount);

        if (sender == uniswapV2Pair && takeFee) {
            restoreAllFee();
	}

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(tTransferAmount);   
        _balances[address(this)] = _balances[address(this)].add(amount.sub(tTransferAmount));
        
	emit Transfer(sender, recipient, tTransferAmount);
        
        if (!takeFee) {
            restoreAllFee();
	}
    }
}
