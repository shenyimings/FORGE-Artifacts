// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IUniswapV2.sol";


contract Omax is Context, IERC20, Ownable {
    using Address for address;

    struct RValuesStruct {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rFee;
        uint256 rBurn;
        uint256 rMarketing;
        uint256 rLiquidity;
    }

    struct TValuesStruct {
        uint256 tTransferAmount;
        uint256 tFee;
        uint256 tBurn;
        uint256 tMarketing;
        uint256 tLiquidity;
    }

    struct ValuesStruct {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rFee;
        uint256 rBurn;
        uint256 rMarketing;
        uint256 rLiquidity;
        uint256 tTransferAmount;
        uint256 tFee;
        uint256 tBurn;
        uint256 tMarketing;
        uint256 tLiquidity;
    }

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcludedFromFee;

    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    string private _name = "OMAX TOKEN";
    string private _symbol = "OMAX";
    uint8 private _decimals = 18;
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 10 * 10 ** 9 * 10 ** uint256(_decimals);
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;
    uint256 private _tBurnTotal;

    uint256 public _taxFee = 400;
    uint256 private _previousTaxFee = _taxFee;

    uint256 public _burnFee = 200;
    uint256 private _previousBurnFee = _burnFee;

    uint256 public _marketFee = 200;
    uint256 private _previousMarketFee = _marketFee;

    uint256 public _liquidityFee = 200;
    uint256 private _previousLiquidityFee = _liquidityFee;

    uint256 public _sellFeeMultiplier = 120;
    uint256 public constant DENOMINATOR = 10000;

    address public marketingWallet = 0x7962fd13E436eac95cc62e4e61d47E27CCac4Ef3;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = false;

    uint256 public _maxTxAmount = 40 * 10 ** 6 * 10 ** uint256(_decimals);
    uint256 public _numTokensSellToAddToLiquidity = 40 * 10 ** 6 * 10 ** uint256(_decimals);

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor() {
        _rOwned[_msgSender()] = _rTotal;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // PCS V2
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[0x10ED43C718714eb63d5aA57B78B54704E256024E] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
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
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
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
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] - subtractedValue);
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function totalBurn() public view returns (uint256) {
        return _tBurnTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        uint256 rAmount = tAmount * _getRate();
        _rOwned[sender] -= rAmount;
        _rTotal -= rAmount;
        _tFeeTotal += tAmount;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns (uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            uint256 rAmount = tAmount * _getRate();
            return rAmount;
        } else {
            uint256 rTransferAmount = _getValues(tAmount, false).rTransferAmount;
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    function excludeFromReward(address account) public onlyOwner() {
        require(account != 0x10ED43C718714eb63d5aA57B78B54704E256024E, 'We can not exclude Pancake router.');
        require(!_isExcluded[account], "Account is already excluded");
        require(_excluded.length < 50, "Excluded list is too long");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _distributeFee(uint256 rFee, uint256 rBurn, uint256 rMarketing, uint256 tFee, uint256 tBurn, uint256 tMarketing) private {
        _rTotal -= (rFee + rBurn);
        _tFeeTotal += tFee;
        _tTotal -= tBurn;
        _tBurnTotal += tBurn;

        _rOwned[marketingWallet] += rMarketing;
        if (_isExcluded[marketingWallet]) {
            _tOwned[marketingWallet] += tMarketing;
        }
    }

    function _getValues(uint256 tAmount, bool isSell) private view returns (ValuesStruct memory) {
        TValuesStruct memory tvs = _getTValues(tAmount, isSell);
        RValuesStruct memory rvs = _getRValues(tAmount, tvs.tFee, tvs.tBurn, tvs.tMarketing, tvs.tLiquidity, _getRate());

        return ValuesStruct(
            rvs.rAmount,
            rvs.rTransferAmount,
            rvs.rFee,
            rvs.rBurn,
            rvs.rMarketing,
            rvs.rLiquidity,
            tvs.tTransferAmount,
            tvs.tFee,
            tvs.tBurn,
            tvs.tMarketing,
            tvs.tLiquidity
        );
    }

    function _getTValues(uint256 tAmount, bool isSell) private view returns (TValuesStruct memory) {
        uint256 tFee = calculateTaxFee(tAmount, isSell);
        uint256 tBurn = calculateBurnFee(tAmount, isSell);
        uint256 tMarketing = calculateMarketingFee(tAmount, isSell);
        uint256 tLiquidity = calculateLiquidityFee(tAmount, isSell);
        uint256 tTransferAmount = tAmount - tFee - tBurn - tMarketing - tLiquidity;
        return TValuesStruct(tTransferAmount, tFee, tBurn, tMarketing, tLiquidity);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tBurn, uint256 tMarketing, uint256 tLiquidity, uint256 currentRate) private view returns (RValuesStruct memory) {
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rBurn = tBurn * currentRate;
        uint256 rMarketing = tMarketing * currentRate;
        uint256 rLiquidity = tLiquidity * currentRate;
        uint256 rTransferAmount = rAmount - rFee - rLiquidity - rBurn - rMarketing;
        return RValuesStruct(rAmount, rTransferAmount, rFee, rBurn, rMarketing, rLiquidity);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 rLiquidity, uint256 tLiquidity) private {
        _rOwned[address(this)] += rLiquidity;
        if (_isExcluded[address(this)])
            _tOwned[address(this)] += tLiquidity;
    }

    function calculateTaxFee(uint256 _amount, bool isSell) private view returns (uint256) {
        return _amount * _taxFee * (isSell ? _sellFeeMultiplier : 100) / DENOMINATOR / 100;
    }

    function calculateBurnFee(uint256 _amount, bool isSell) private view returns (uint256) {
        return _amount * _burnFee * (isSell ? _sellFeeMultiplier : 100) / DENOMINATOR / 100;
    }

    function calculateMarketingFee(uint256 _amount, bool isSell) private view returns (uint256) {
        return _amount * _marketFee * (isSell ? _sellFeeMultiplier : 100) / DENOMINATOR / 100;
    }

    function calculateLiquidityFee(uint256 _amount, bool isSell) private view returns (uint256) {
        return _amount * _liquidityFee * (isSell ? _sellFeeMultiplier : 100) / DENOMINATOR / 100;
    }

    function removeAllFee() private {
        _previousTaxFee = _taxFee;
        _previousBurnFee = _burnFee;
        _previousMarketFee = _marketFee;
        _previousLiquidityFee = _liquidityFee;
        _taxFee = 0;
        _liquidityFee = 0;
        _burnFee = 0;
        _marketFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _marketFee = _previousMarketFee;
        _burnFee = _previousBurnFee;

    }

    function isExcludedFromFee(address account) public view returns (bool) {
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

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinTokenBalance = contractTokenBalance >= _numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = _numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half);
        // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance - initialBalance;

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
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
        uniswapV2Router.addLiquidityETH{value : ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount) private {
        if (_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]) {
            removeAllFee();
        }
        else {
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }

        bool isSell = (recipient == uniswapV2Pair);
        ValuesStruct memory vs = _getValues(amount, isSell);
        _takeLiquidity(vs.rLiquidity, vs.tLiquidity);
        _distributeFee(vs.rFee, vs.rBurn, vs.rMarketing, vs.tFee, vs.tBurn, vs.tMarketing);

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount, vs);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, vs);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, vs);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount, vs);
        }

        if (_isExcludedFromFee[sender] || _isExcludedFromFee[recipient])
            restoreAllFee();
    }

    function _transferStandard(address sender, address recipient, ValuesStruct memory vs) private {
        _rOwned[sender] -= vs.rAmount;
        _rOwned[recipient] += vs.rTransferAmount;
        emit Transfer(sender, recipient, vs.tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, ValuesStruct memory vs) private {
        _rOwned[sender] -= vs.rAmount;
        _tOwned[recipient] += vs.tTransferAmount;
        _rOwned[recipient] += vs.rTransferAmount;
        emit Transfer(sender, recipient, vs.tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount, ValuesStruct memory vs) private {
        _tOwned[sender] -= tAmount;
        _rOwned[sender] -= vs.rAmount;
        _rOwned[recipient] += vs.rTransferAmount;
        emit Transfer(sender, recipient, vs.tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount, ValuesStruct memory vs) private {
        _tOwned[sender] -= tAmount;
        _rOwned[sender] -= vs.rAmount;
        _tOwned[recipient] += vs.tTransferAmount;
        _rOwned[recipient] += vs.rTransferAmount;
        emit Transfer(sender, recipient, vs.tTransferAmount);
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    //Call this function after finalizing the presale
    function enableAllFees() external onlyOwner() {
        restoreAllFee();
        _previousTaxFee = _taxFee;
        _previousBurnFee = _taxFee;
        _previousMarketFee = _marketFee;
        _previousLiquidityFee = _liquidityFee;
        setSwapAndLiquifyEnabled(true);
    }

    function disableAllFees() external onlyOwner() {
        removeAllFee();
        setSwapAndLiquifyEnabled(false);
    }

    function setMarketingWallet(address newWallet) external onlyOwner {
        marketingWallet = newWallet;
    }

    function setMaxTxPercent(uint256 maxTxAmount) external onlyOwner {
        _maxTxAmount = maxTxAmount;
    }

    function setNumTokensSellToAddToLiquidity(uint256 numTokensSellToAddToLiquidity) external onlyOwner {
        _numTokensSellToAddToLiquidity = numTokensSellToAddToLiquidity;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }


    function setSellFeeMultiplier(uint256 newSellFeeMultiplier) external onlyOwner {
        require(newSellFeeMultiplier >= 150 && newSellFeeMultiplier <= 300, 'Multiplier has to be from 150 to 300');
        emit UpdateSellFeeMultiplier(_sellFeeMultiplier, newSellFeeMultiplier);
        _sellFeeMultiplier = newSellFeeMultiplier;
    }

    function setTaxFee(uint256 taxFee) external onlyOwner {
        _taxFee = taxFee;
    }

    function setBurnFee(uint256 burnFee) external onlyOwner {
        _burnFee = burnFee;
    }

    function setLiquidityFee(uint256 liquidityFee) external onlyOwner {
        _liquidityFee = liquidityFee;
    }

    function setMarketFee(uint256 marketFee) external onlyOwner {
        _marketFee = marketFee;
    }

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    event UpdateSellFeeMultiplier(uint256 oldSellFeeMultiplier, uint256 newSellFeeMultiplier);
}
