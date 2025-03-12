// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import '@pancakeswap/pancake-swap-lib/contracts/utils/Address.sol';
import './utils/Ownable.sol';
import "./utils/LPSwapSupport.sol";
import "./utils/AntiLPSniper.sol";

contract SQUIDZILLA is IBEP20, LPSwapSupport, AntiLPSniper {
    using SafeMath for uint256;
    using Address for address;

    struct TokenTracker {
        uint256 liquidity;
        uint256 marketing;
    }

    struct Fees {
        uint256 reflection;
        uint256 liquidity;
        uint256 marketing;
        uint256 divisor;
    }

    Fees public buyFees;
    Fees public sellFees;
    Fees public transferFees;
    TokenTracker public tokenTracker;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) public _isExcludedFromFee;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 55 * 10**5 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string public constant override name = "SQUIDZILLA";
    string public constant override symbol = "SQUIDZILLA";
    uint256 private constant _decimals = 9;
    uint256 public _maxTxAmount;

    address public marketingWallet;

    constructor (address _routerAddress, address _tokenOwner, address _marketing) LPSwapSupport() public payable {
        updateRouterAndPair(_routerAddress);
        _maxTxAmount = _tTotal;

        marketingWallet = _marketing;

        minTokenSpendAmount = _tTotal.div(10 ** 6);
        _rOwned[_tokenOwner] = _rTotal;
        _isExcludedFromFee[_owner] = true;
        _isExcludedFromFee[_tokenOwner] = true;
        _isExcludedFromFee[_msgSender()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[marketingWallet] = true;

        buyFees = Fees({
            reflection: 0,
            liquidity: 2,
            marketing: 4,
            divisor: 100
        });

        sellFees = Fees({
            reflection: 0,
            liquidity: 2,
            marketing: 4,
            divisor: 100
        });

        transferFees = Fees({
            reflection: 0,
            liquidity: 2,
            marketing: 4,
            divisor: 100
        });
        _owner = _tokenOwner;

        emit Transfer(address(this), _tokenOwner, _tTotal);
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function decimals() external view override returns(uint8){
        return uint8(_decimals);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balanceOf(account);
    }

    function _balanceOf(address account) internal view override returns (uint256) {
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address holder, address spender) public view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
        return true;
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function getOwner() external view override returns (address) {
        return owner();
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromFee(address account, bool exclude) public onlyOwner {
        _isExcludedFromFee[account] = exclude;
    }

    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 tLiquidity) internal returns(uint256 rLiquidity) {
        if(tLiquidity == 0)
            return 0;
        uint256 currentRate =  _getRate();
        rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        tokenTracker.liquidity = tokenTracker.liquidity.add(tLiquidity);
        return rLiquidity;
    }

    function _takeOtherFees(uint256 tMarketing) private returns(uint256) {
        uint256 currentRate =  _getRate();
        uint256 rMarketing = 0;
        if(tMarketing > 0){
            rMarketing = tMarketing.mul(currentRate);
            _rOwned[address(this)] = _rOwned[address(this)].add(rMarketing);
            tokenTracker.marketing = tokenTracker.marketing.add(tMarketing);
        }
        return rMarketing;
    }

    function _approve(address holder, address spender, uint256 amount) internal override {
        require(holder != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[holder][spender] = amount;
        emit Approval(holder, spender, amount);
    }

    // This function was so large given the fee structure it had to be subdivided as solidity did not support
    // the possibility of containing so many local variables in a single execution.
    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 rAmount;
        uint256 tTransferAmount;
        uint256 rTransferAmount;

        if(from != owner() && to != owner() && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
            require(!isBlackListed[to] && !isBlackListed[from], "Address is blacklisted");

            if(from == pancakePair && !tradingOpen && antiSniperEnabled){
                banHammer(to);
                to = address(this);
                (rAmount, tTransferAmount, rTransferAmount) = valuesForNoFees(amount);
                _transferStandard(from, to, rAmount, tTransferAmount, rTransferAmount);
                tokenTracker.liquidity = tokenTracker.liquidity.add(amount);
                return;
            } else {
                require(tradingOpen, "Trading not open");
            }

            if(!inSwap && from != pancakePair) {
                selectSwapEvent();
            }
            if(from == pancakePair){ // Buy
                (rAmount, tTransferAmount, rTransferAmount) = takeFees(amount, buyFees);
            } else if(to == pancakePair){ // Sell
                (rAmount, tTransferAmount, rTransferAmount) = takeFees(amount, sellFees);
            } else {
                (rAmount, tTransferAmount, rTransferAmount) = takeFees(amount, transferFees);
            }

            emit Transfer(from, address(this), amount.sub(tTransferAmount));

        } else {
            (rAmount, tTransferAmount, rTransferAmount) = valuesForNoFees(amount);
        }

        _transferStandard(from, to, rAmount, tTransferAmount, rTransferAmount);
    }

    function valuesForNoFees(uint256 amount) private view returns(uint256 rAmount, uint256 tTransferAmount, uint256 rTransferAmount){
        rAmount = amount.mul(_getRate());
        tTransferAmount = amount;
        rTransferAmount = rAmount;
    }

    function pushSwap() external {
        if(!inSwap && tradingOpen)
            selectSwapEvent();
    }

    function selectSwapEvent() private lockTheSwap {
        if(!swapsEnabled){
            return;
        }
        if(tokenTracker.liquidity >= minTokenSpendAmount){
            uint256 contractTokenBalance = tokenTracker.liquidity;
            swapAndLiquify(contractTokenBalance); // LP
            tokenTracker.liquidity = tokenTracker.liquidity.sub(contractTokenBalance);

        } else if(tokenTracker.marketing >= minTokenSpendAmount){
            uint256 tokensSwapped = swapTokensForCurrencyAdv(address(this), tokenTracker.marketing, address(marketingWallet));
            tokenTracker.marketing = tokenTracker.marketing.sub(tokensSwapped);
        }
    }

    function takeFees(uint256 amount, Fees memory _fees) private returns(uint256 rAmount, uint256 tTransferAmount, uint256 rTransferAmount){
        uint256 tFee = amount.mul(_fees.reflection).div(_fees.divisor);
        uint256 tLiquidity = amount.mul(_fees.liquidity).div(_fees.divisor);
        uint256 tMarketing = amount.mul(_fees.marketing).div(_fees.divisor);
        uint256 rFee = tFee.mul(_getRate());
        uint256 rOther = _takeOtherFees(tMarketing);
        uint256 rLiquidity = _takeLiquidity(tLiquidity);

        tTransferAmount = amount.sub(tFee);
        tTransferAmount = tTransferAmount.sub(tMarketing).sub(tLiquidity);
        rAmount = amount.mul(_getRate());
        rTransferAmount = rAmount.sub(rLiquidity).sub(rOther);
        _reflectFee(rFee, tFee);
        rTransferAmount = rTransferAmount.sub(rFee);

        return (rAmount, tTransferAmount, rTransferAmount);
    }

    function _transferStandard(address sender, address recipient, uint256 rAmount, uint256 tTransferAmount, uint256 rTransferAmount) private {
        if(tTransferAmount == 0) { return; }
        if(sender != address(0))
            _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function updateBuyFees(uint256 reflectionFee, uint256 liquidityFee, uint256 marketingFee, uint256 newFeeDivisor) external onlyOwner {
        buyFees = Fees({
            reflection: reflectionFee,
            liquidity: liquidityFee,
            marketing: marketingFee,
            divisor: newFeeDivisor
        });
    }

    function updateSellFees(uint256 reflectionFee, uint256 liquidityFee, uint256 marketingFee,uint256 newFeeDivisor) external onlyOwner {
        sellFees = Fees({
            reflection: reflectionFee,
            liquidity: liquidityFee,
            marketing: marketingFee,
            divisor: newFeeDivisor
        });
    }

    function updateTransferFees(uint256 reflectionFee, uint256 liquidityFee, uint256 marketingFee, uint256 newFeeDivisor) external onlyOwner {
        transferFees = Fees({
            reflection: reflectionFee,
            liquidity: liquidityFee,
            marketing: marketingFee,
            divisor: newFeeDivisor
        });
    }

    function updateMarketingWallet(address marketing) external onlyOwner {
        marketingWallet = marketing;
    }

    function updateMaxTxSize(uint256 maxTransactionAllowed) external onlyOwner {
        _maxTxAmount = maxTransactionAllowed.mul(10 ** _decimals);
    }

    function openTrading() external override onlyOwner {
        require(!tradingOpen, "Trading already enabled");
        tradingOpen = true;
        swapsEnabled = true;
    }

    function pauseTrading() external virtual onlyOwner {
        require(tradingOpen, "Trading already closed");
        tradingOpen = !tradingOpen;
    }

    function batchAirdrop(address[] memory airdropAddresses, uint256[] memory airdropAmounts) external {
        require(_msgSender() == owner() || _isExcludedFromFee[_msgSender()], "Account not authorized for airdrop");
        require(airdropAddresses.length == airdropAmounts.length, "Addresses and amounts must be equal quantities of entries");
        if(!inSwap)
            _batchAirdrop(airdropAddresses, airdropAmounts);
    }

    function _batchAirdrop(address[] memory _addresses, uint256[] memory _amounts) private lockTheSwap {
        uint256 senderRBal = _rOwned[_msgSender()];
        uint256 currentRate = _getRate();
        uint256 tTotalSent;
        uint256 arraySize = _addresses.length;
        uint256 sendAmount;
        uint256 _decimalModifier = 10 ** uint256(_decimals);

        for(uint256 i = 0; i < arraySize; i++){
            sendAmount = _amounts[i].mul(_decimalModifier);
            tTotalSent = tTotalSent.add(sendAmount);
            _rOwned[_addresses[i]] = _rOwned[_addresses[i]].add(sendAmount.mul(currentRate));
            emit Transfer(_msgSender(), _addresses[i], sendAmount);
        }
        uint256 rTotalSent = tTotalSent.mul(currentRate);
        if(senderRBal < rTotalSent)
            revert("Insufficient balance from airdrop instigator");
        _rOwned[_msgSender()] = senderRBal.sub(rTotalSent);
    }
}
