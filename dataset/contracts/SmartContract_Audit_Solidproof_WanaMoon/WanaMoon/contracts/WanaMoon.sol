// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./IUniswapV2Router02.sol";
import "./ILotteryTracker.sol";

contract WanaMoon is Context, IERC20, Ownable{

    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isExcluded;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) public _isExcludedFromAutoLiquidity;
    mapping (address => bool) private _isBlacklisted;
    mapping (address => bool) internal _isExcludedFromTxLimit;
    address [] private _list;
    mapping (address => bool) private _transferExclusions;
    address[] private _excluded;
    address payable public _marketingWallet = payable(0x719D57c545ba456f4912370126f4E51f167b0Af1); 
    address payable public _buyBackWallet = payable(0x8e8A4071019ac6fD762131267f6EBC3497B09748); 
    address payable public _lotteryWallet = payable(0xD747D7D81134936f5c27b0C26D466405238FAD6B); 
    IERC20 public rewardToken;
    ILotteryTracker public lotteryTracker;
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 1000000 * 10**3 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;
    bool public rewardInBNB = false;
    bool public isEarlySellingEnabled = true;
    bool public disableLotteryLogic = false;
    mapping(address => bool) _isExcludedFromEarlySellingLimit;
    mapping (address => uint256) private lastBuyTime;
    uint public Level1Hours = 24;
    uint public Level2Hours = 48;
    uint256 public earlySellingFeeLevel1InHrCutOffPercent = 20;
    uint256 public earlySellingFeeLevel2InHrCutOffPercent = 10;
    uint256 public entryDivider = 10000 * 10**9;
    mapping(address => bool) _isExcludedFromLottery;
    mapping(address => bool) _accountInLottery;
    mapping(address => bool) _isLpPair;

    string private constant _name     = "WANAMOON";
    string private constant _symbol   = "MOON";
    uint8  private constant _decimals = 9;
    
    uint256 private  _lotteryTax       = 2;
    uint256 private  _marketingTax       = 4;
    uint256 private  _buyBackTax       = 2;
    uint256 public  _taxFee       = 1; // holders tax
    uint256 public  _liquidityFee = 1; // auto lp tax
    uint256 public  _totalTaxForDistribution  = _lotteryTax.add(_marketingTax).add(_buyBackTax); // total tax for distribution
    uint256 public  _totalFees      = _taxFee.add(_liquidityFee).add(_totalTaxForDistribution);
    
    uint256 public  _maxTxAmount     = 2500 * 10**3 * 10**9;
    uint256 private _minimumTokenBalance = 500 * 10**3 * 10**9;
    
    
    IUniswapV2Router02 public pancakeV2Router;
    address            public pancakeV2Pair;
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    event MinimumTokensBeforeSwapUpdated(uint256 minimumTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );
    event UpdateLastBuyTime(address account, uint256 time);
    event RemoveAccountFromLottery(address account);
    event AddAccountToLottery(address account);
    
    modifier ltsTheSwap{
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    constructor (address _lotteryTracker) {
        _rOwned[_msgSender()] = _rTotal;
        // set default to BUSD 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56
        // busd on beta 0x8301F2213c0eeD49a7E28Ae4c3e91722919B8B47
        rewardToken = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
        lotteryTracker = ILotteryTracker(_lotteryTracker);
        // pancake
        //beta router 0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        // prod router 0x10ED43C718714eb63d5aA57B78B54704E256024E
        IUniswapV2Router02 _pancakeV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pancakeV2Pair = IUniswapV2Factory(_pancakeV2Router.factory())
            .createPair(address(this), _pancakeV2Router.WETH());
        pancakeV2Router = _pancakeV2Router;
        
        // exclude system address
        _isExcludedFromFee[_msgSender()]    = true;
        _isExcludedFromFee[address(this)]   = true;
        _isExcludedFromFee[_marketingWallet] = true;
        _isExcludedFromFee[_buyBackWallet] = true;
        _isExcludedFromFee[_lotteryWallet] = true;
        _isExcludedFromEarlySellingLimit[_msgSender()] = true;
        _isExcludedFromEarlySellingLimit[address(this)] = true;
        _isExcludedFromEarlySellingLimit[_marketingWallet] = true;
        _isExcludedFromEarlySellingLimit[_buyBackWallet] = true;
        _isExcludedFromEarlySellingLimit[_lotteryWallet] = true;
        _isExcludedFromEarlySellingLimit[pancakeV2Pair] = true;
        _isExcludedFromEarlySellingLimit[address(pancakeV2Router)] = true;
        _isExcludedFromAutoLiquidity[pancakeV2Pair]            = true;
        _isExcludedFromAutoLiquidity[address(pancakeV2Router)] = true;
        _isExcludedFromLottery[address(this)] = true;
        _isExcludedFromLottery[pancakeV2Pair] = true;
        _isExcludedFromLottery[address(pancakeV2Router)] = true;
        _isLpPair[pancakeV2Pair] = true;
        _isLpPair[address(pancakeV2Router)] = true;
        _isExcludedFromTxLimit[owner()] = true;
        _isExcludedFromTxLimit[address(this)] = true;
        _isExcludedFromTxLimit[_marketingWallet] = true;
        _isExcludedFromTxLimit[_buyBackWallet] = true;
        _isExcludedFromTxLimit[_lotteryWallet] = true;
        _isExcludedFromLottery[_msgSender()] = true;
        _isExcludedFromLottery[_marketingWallet] = true;
        _isExcludedFromLottery[_lotteryWallet] = true;
        _isExcludedFromLottery[_buyBackWallet] = true;

        
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
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

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        (, uint256 tFee, uint256 tLiquidity) = _getTValues(tAmount,0);
        uint256 currentRate = _getRate();

        if (!deductTransferFee) {
            (uint256 rAmount,,) = _getRValues(tAmount, tFee, tLiquidity, currentRate);
            return rAmount;

        } else {
            (, uint256 rTransferAmount,) = _getRValues(tAmount, tFee, tLiquidity, currentRate);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");

        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");

        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is already included");

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


    function getLotteryEntryAmount(uint256 amount) internal view returns(uint256) {
        if (amount == 0) {
            return 0;
        }

        uint256 entries = amount / entryDivider;
        if (amount % entryDivider > 0) {
            return entries + 1;
        }

        return entries;
    }

    function setLotteryTracker(address _lotteryTracker) external onlyOwner {
        lotteryTracker = ILotteryTracker(_lotteryTracker);
        _isExcludedFromLottery[address(_lotteryTracker)] = true;
    }


    function setRewardInBNB(bool  a) external onlyOwner{
        rewardInBNB = a;
    }

    function setDisableLotteryLogic(bool  a) external onlyOwner{
        disableLotteryLogic = a;
    }

    function setEarlySellingEnabled(bool  a) external onlyOwner{
        isEarlySellingEnabled = a;
    }
    
    function setRewardToken(address token) external onlyOwner{
       rewardToken = IERC20(token);
    }

    function setExcludedFromLottery(address holder, bool a) external onlyOwner {
        _isExcludedFromLottery[holder] = a;
    }

    function isExcludedFromLottery(address holder) external view returns(bool) {
        return _isExcludedFromLottery[holder];
    }

    function setExcludedFromTxLimit(address holder, bool a) external onlyOwner {
        _isExcludedFromTxLimit[holder] = a;
    }

    function isExcludedFromTxLimit(address holder) external view returns(bool) {
        return _isExcludedFromTxLimit[holder];
    }

    function isAccountInLottery(address account) external view returns(bool) {
        if(_accountInLottery[account]){
            return lotteryTracker.isActiveAccount(account);
        }
        return false;
    }

    function setMarketingWallet(address  wallet) external onlyOwner{
        _marketingWallet = payable(wallet);
        _isExcludedFromFee[_marketingWallet] = true;
        _isExcludedFromEarlySellingLimit[_marketingWallet] = true;
        _isExcludedFromTxLimit[_marketingWallet] = true;
        _isExcludedFromLottery[_marketingWallet] = true;
    }

    function setBuyBackWallet(address  wallet) external onlyOwner{
        _buyBackWallet = payable(wallet);
        _isExcludedFromFee[_buyBackWallet] = true;
        _isExcludedFromEarlySellingLimit[_buyBackWallet] = true;
        _isExcludedFromTxLimit[_buyBackWallet] = true;
        _isExcludedFromLottery[_buyBackWallet] = true;
    }

    function setLotteryWallet(address  wallet) external onlyOwner{
        _lotteryWallet = payable(wallet);
        _isExcludedFromFee[_lotteryWallet] = true;
        _isExcludedFromEarlySellingLimit[_lotteryWallet] = true;
        _isExcludedFromTxLimit[_lotteryWallet] = true;
        _isExcludedFromLottery[_lotteryWallet] = true;
    } 
    
    function setExcludedFromFee(address account, bool e) external onlyOwner {
        _isExcludedFromFee[account] = e;
    }
    // Quantity required for Loto entry
    function setEntryDivider(uint256 entryDividerAmount) external onlyOwner {
        require(entryDividerAmount>1000000000, "EntryDividerAmount  is less than 1");
        entryDivider = entryDividerAmount;
    }

    function setEarlySellingLevel1InHrCutOffTax(uint256 hoursToSet, uint256 taxFee) external onlyOwner {
        require(taxFee>0, "EarlySellingFeeLevel1InHrCutOffPercent tax is less than 0");
        require(hoursToSet>0, "Hours can not be 0");
        Level1Hours = hoursToSet;
        earlySellingFeeLevel1InHrCutOffPercent = taxFee;
    }

    function setEarlySellingLevel2InHrCutOffTax(uint256 hoursToSet, uint256 taxFee) external onlyOwner {
        require(taxFee>0, "EarlySellingFeeLevel2InHrCutOffPercent tax is less than 0");
        require(hoursToSet>0, "Hours can not be 0");
        Level2Hours = hoursToSet;
        earlySellingFeeLevel2InHrCutOffPercent = taxFee;
    }
    
    function setHoldersFeePercent(uint256 taxFee) external onlyOwner {
        require(taxFee>0, "Holder tax is less than 0");
        _taxFee = taxFee;
        _totalFees      = _taxFee.add(_liquidityFee).add(_totalTaxForDistribution);
    }
    
    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner {
        require(liquidityFee>0, "Liquidity tax is less than 0");
        _liquidityFee = liquidityFee;
        _totalFees      = _taxFee.add(_liquidityFee).add(_totalTaxForDistribution);
    }

    function setTotalTaxForDistribution(uint256 lotteryTax,uint256 marketingTax,uint256 buyBackTax) external onlyOwner {
        require(lotteryTax>0, "Lottery tax is less than 0");
        require(marketingTax>0, "Marketing tax is less than 0");
        require(buyBackTax>0, "BuyBack tax is less than 0");
        _totalTaxForDistribution = lotteryTax.add(marketingTax).add(buyBackTax);
        _lotteryTax = lotteryTax;
        _marketingTax = marketingTax;
        _buyBackTax = buyBackTax;
        _totalFees      = _taxFee.add(_liquidityFee).add(_totalTaxForDistribution);
    }
    
    function setMaxTx(uint256 maxTx) external onlyOwner {
        require(maxTx >100000000000000, "Max transaction is less than 100000");
        _maxTxAmount = maxTx;
    }

    function setContractSellThreshold(uint256 minimumTokenBalance) external onlyOwner {
        require(minimumTokenBalance > 10000000000000, "Max transaction is less than 10000");
        _minimumTokenBalance = minimumTokenBalance;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
    
    receive() external payable {}

    
    function updateNewRouter(address _router) public onlyOwner returns(address _pair) {
       
        IUniswapV2Router02 _pancakeV2Router = IUniswapV2Router02(_router);
        _pair = IUniswapV2Factory(_pancakeV2Router.factory()).getPair(address(this), _pancakeV2Router.WETH());
        if(_pair == address(0)){
            // Pair doesn't exist, create a new one
            _pair = IUniswapV2Factory(_pancakeV2Router.factory())
            .createPair(address(this), _pancakeV2Router.WETH());
        }
        pancakeV2Pair = _pair;
        // Update the router of the contract variables
        pancakeV2Router = _pancakeV2Router;
        _isExcludedFromAutoLiquidity[pancakeV2Pair]            = true;
        _isExcludedFromAutoLiquidity[address(pancakeV2Router)] = true;
        _isExcludedFromEarlySellingLimit[pancakeV2Pair] = true;
        _isExcludedFromEarlySellingLimit[address(pancakeV2Router)] = true;
        _isLpPair[pancakeV2Pair] = true;
        _isLpPair[address(pancakeV2Router)] = true;
        
    }
    

    function setIsLpPair(address a, bool b) external onlyOwner {
        _isLpPair[a] = b;
    }

     function isAddressLpPair(address a) external view returns(bool) {
        return _isLpPair[a];
    }

    function setExcludedFromAutoLiquidity(address a, bool b) external onlyOwner {
        _isExcludedFromAutoLiquidity[a] = b;
    }

    // to blacklist bots
    function blacklist(address _address, bool setTo) external onlyOwner {
        _isBlacklisted[_address] = setTo;
        if(setTo == true){
            _list.push(_address);
        }
        
    }

    function checkBlackList() public view returns(address[] memory){
        address[] memory response = new address[](_list.length);
        for (uint i = 0; i < _list.length; i++) {
            if(_isBlacklisted[_list[i]] == true){
                response[i] = _list[i];
            }
        }
        return response;
    }

     function setTransferExclusions(address _address, bool setTo) external onlyOwner {
        _transferExclusions[_address] = setTo;
    }

    function getTransferExclusions(address account) public view returns (bool) {
        return _transferExclusions[account];
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal    = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getTValues(uint256 tAmount, uint256 earlySellingTaxAmount) private view returns (uint256, uint256, uint256) {
        //Total fee for distribution and autolp
        uint256 _totalFeesForBNB = _liquidityFee.add(_totalTaxForDistribution);
        uint256 tFee       = tAmount.mul(_taxFee).div(100);
        uint256 tLiquidity = tAmount.mul(_totalFeesForBNB).div(100);
        uint256 tTransferAmount = tAmount.sub(tFee);
        if(earlySellingTaxAmount>0){
            tLiquidity = tLiquidity.add(earlySellingTaxAmount);
        }
        tTransferAmount = tTransferAmount.sub(tLiquidity);
        return (tTransferAmount, tFee, tLiquidity);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount    = tAmount.mul(currentRate);
        uint256 rFee       = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee);
        rTransferAmount = rTransferAmount.sub(rLiquidity);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    function takeTransactionFee(address to, uint256 tAmount, uint256 currentRate) private {
        if (tAmount <= 0) { return; }

        uint256 rAmount = tAmount.mul(currentRate);
        _rOwned[to] = _rOwned[to].add(rAmount);
        if (_isExcluded[to]) {
            _tOwned[to] = _tOwned[to].add(tAmount);
        }
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
    

    function checkTxLimit(address sender,address receiver, uint256 amount) internal view {
        if (_isExcludedFromTxLimit[sender] || _isExcludedFromTxLimit[receiver]) {
            return;
        }
        // allow the LP pair, as they are buy
        if(_isLpPair[sender]){
            return;
        }
        require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(!_isBlacklisted[from] && !_isBlacklisted[to], "Cannot transfer from or to a blacklisted address");

        checkTxLimit(from,to,amount);

        uint256 contractTokenBalance = balanceOf(address(this));
        
        if (contractTokenBalance >= _maxTxAmount) {
            contractTokenBalance = _maxTxAmount;
        }
        
        bool isOverMinimumTokenBalance = contractTokenBalance >= _minimumTokenBalance;
        if (
            isOverMinimumTokenBalance &&
            !inSwapAndLiquify &&
            !_isExcludedFromAutoLiquidity[from] &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = _minimumTokenBalance;
            swapAndLiquify(contractTokenBalance);
        }
        // When from is LP pair then its a buy
        if(!inSwapAndLiquify && _isLpPair[from]){
            recordLastBuy(to);
        }
        
        bool takeFee = true;
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }
        _tokenTransfer(from, to, amount, takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private ltsTheSwap {
        
        uint256 _totalFeesForBNB = _liquidityFee.add(_totalTaxForDistribution);
        if(_totalFeesForBNB < 1){
            _totalFeesForBNB = 1;
        }
        // take LP part from total balance
        uint256 lpPart = contractTokenBalance.mul(_liquidityFee).div(_totalFeesForBNB);
        uint256 distributionPart = contractTokenBalance.sub(lpPart);
        uint256 half      = lpPart.div(2);
        uint256 otherHalf = lpPart.sub(half);

        uint256 initialBalance = address(this).balance;
        swapTokensForBnb(half);
        uint256 newBalance = address(this).balance.sub(initialBalance);
        addLiquidity(otherHalf, newBalance);
        emit SwapAndLiquify(half, newBalance, otherHalf);
        // swap and take distribution part
        if( distributionPart > 0)
        {
            initialBalance = address(this).balance;
            swapTokensForBnb(distributionPart);
            newBalance = address(this).balance.sub(initialBalance);
            // devide the converted token to lottery, marketing and Buy back
            uint256 lotteryPart = newBalance.mul(_lotteryTax).div(_totalTaxForDistribution);
            uint256 marketingPart = newBalance.mul(_marketingTax).div(_totalTaxForDistribution);
            uint256 buyBackPart = newBalance.mul(_buyBackTax).div(_totalTaxForDistribution);
            transferToAddressBNB(_marketingWallet,marketingPart);
            transferToAddressBNB(_buyBackWallet,buyBackPart);
            if(rewardInBNB){
                transferToAddressBNB(_lotteryWallet,lotteryPart);
            }else{
                swapAndSendToken(lotteryPart);
            }
            
        }
    }
function swapAndSendToken(uint256 bnbBalance) private ltsTheSwap {
        uint256 initialBalance = rewardToken.balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = pancakeV2Router.WETH();
        path[1] = address(rewardToken);

        pancakeV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: bnbBalance}(
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 tokenReceived = rewardToken.balanceOf(address(this)).sub(initialBalance);
        rewardToken.transfer(_lotteryWallet, tokenReceived);
    }

    function swapTokensForBnb(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeV2Router.WETH();

        _approve(address(this), address(pancakeV2Router), tokenAmount);
        pancakeV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        _approve(address(this), address(pancakeV2Router), tokenAmount);
        pancakeV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function setExcludedFromEarlySellingLimit(address holder, bool status) external onlyOwner {
        _isExcludedFromEarlySellingLimit[holder] = status;
    }

    function getExcludedFromEarlySellingLimit(address holder) public view returns (bool) {
        return  _isExcludedFromEarlySellingLimit[holder];
    }

    function recordLastBuy(address buyer) internal {
        lastBuyTime[buyer] = block.timestamp;
        emit UpdateLastBuyTime(buyer, block.timestamp);
    }

    function getLastBuy(address buyer) external view returns(uint256) {
        return lastBuyTime[buyer];
    }

    function calculateEarlySellingFee(address from, uint256 amount) internal view returns(uint256) {
        if (_isExcludedFromEarlySellingLimit[from]) {
            return 0;
        }
        if (block.timestamp.sub(lastBuyTime[from]) < Level1Hours * 1 hours) {
            return amount.mul(earlySellingFeeLevel1InHrCutOffPercent).div(100);
        }else if (block.timestamp.sub(lastBuyTime[from]) < Level2Hours * 1 hours) {
            return amount.mul(earlySellingFeeLevel2InHrCutOffPercent).div(100);
        }
        return 0;
    }
    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
        uint256 previousTaxFee       = _taxFee;
        uint256 previousLiquidityFee = _liquidityFee;
        uint256 previousTaxForDistributionFee  = _totalTaxForDistribution;
        uint256 earlySellingTaxAmount = 0;
        if(isEarlySellingEnabled && takeFee){
            earlySellingTaxAmount = calculateEarlySellingFee(sender, amount);
        }

        if (!takeFee) {
            _taxFee       = 0;
            _liquidityFee = 0;
            _totalTaxForDistribution  = 0;
        } 
        
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount,earlySellingTaxAmount);

        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount,earlySellingTaxAmount);

        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount,earlySellingTaxAmount);

        } else {
            _transferStandard(sender, recipient, amount,earlySellingTaxAmount);
        }
        
        if (!takeFee) {
            _taxFee       = previousTaxFee;
            _liquidityFee = previousLiquidityFee;
            _totalTaxForDistribution  = previousTaxForDistributionFee;
        }
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount,uint256 earlySellingTaxAmount) private {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getTValues(tAmount,earlySellingTaxAmount);
        uint256 currentRate = _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, currentRate);
        _rOwned[sender]    = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        takeTransactionFee(address(this), tLiquidity, currentRate);
        _reflectFee(rFee, tFee);
        updateAccountLottery(sender,recipient,tTransferAmount);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount,uint256 earlySellingTaxAmount) private {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getTValues(tAmount,earlySellingTaxAmount);
        uint256 currentRate = _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, currentRate);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        takeTransactionFee(address(this), tLiquidity, currentRate);
        _reflectFee(rFee, tFee);
        updateAccountLottery(sender,recipient,tTransferAmount);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount,uint256 earlySellingTaxAmount) private {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getTValues(tAmount,earlySellingTaxAmount);
        uint256 currentRate = _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, currentRate);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        takeTransactionFee(address(this), tLiquidity, currentRate);
        _reflectFee(rFee, tFee);
        updateAccountLottery(sender,recipient,tTransferAmount);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount,uint256 earlySellingTaxAmount) private {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getTValues(tAmount,earlySellingTaxAmount);
        uint256 currentRate = _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, currentRate);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        takeTransactionFee(address(this), tLiquidity, currentRate);
        _reflectFee(rFee, tFee);
        updateAccountLottery(sender,recipient,tTransferAmount);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function updateAccountLottery(address removeAccount, address addAccount, uint256 amount) internal {
        if(disableLotteryLogic){ 
            return;
        }
        if(_transferExclusions[addAccount]){
            // don't remove the account from lottery as this is approved address, 
            //but we need to reduce the entry from lottery
            uint256 entries = getLotteryEntryAmount(amount);
            lotteryTracker.removeEntryFromWallet(removeAccount, entries);
            return;
        }
        if (_accountInLottery[removeAccount]) {
            _accountInLottery[removeAccount] = false;
            if(lotteryTracker.isActiveAccount(removeAccount)){
                lotteryTracker.removeAccount(removeAccount);
            }
            emit RemoveAccountFromLottery(removeAccount);
        }

        if (!_isExcludedFromLottery[addAccount]) {
            uint256 entries = getLotteryEntryAmount(amount);
            lotteryTracker.updateAccount(addAccount, entries);
            if (!_accountInLottery[addAccount]) {
                _accountInLottery[addAccount] = true;
                emit AddAccountToLottery(addAccount);
            }
        }
    }
    
    function transferToAddressBNB(address payable recipient, uint256 amount) private {
        recipient.transfer(amount);
    }
    
    // This is recommended by Certik, if this is not used many BNB will be lost forever.
    function sweep(address to) external onlyOwner {
        uint256 balance = address(this).balance;
        payable(to).transfer(balance);
    }


    function prepareForPresale() public onlyOwner {
        _taxFee       = 0; // holders tax
        _liquidityFee = 0; // auto lp tax
        _lotteryTax       = 0;
        _marketingTax       = 0;
        _buyBackTax       = 0;
        _totalTaxForDistribution  = 0;
        _totalFees      = _taxFee.add(_liquidityFee).add(_totalTaxForDistribution);
        _maxTxAmount = _tTotal;
        swapAndLiquifyEnabled = false; 
    }
    
    function activateContractAfterPresale() public onlyOwner {
        _maxTxAmount     = 2500 * 10**3 * 10**9;
        swapAndLiquifyEnabled = true;
        _taxFee       = 1; // holders tax
        _liquidityFee = 1; // auto lp tax
        _lotteryTax       = 2;
        _marketingTax       = 4;
        _buyBackTax       = 2;
        _totalTaxForDistribution  = 8;
        _totalFees      = _taxFee.add(_liquidityFee).add(_totalTaxForDistribution);
    }
        
}