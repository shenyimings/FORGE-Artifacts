/* 

    🄷🄴🅁🄸🅃🅈 🄽🄴🅃🅆🄾🅁🄺
    
      Website: https://herity.io/
     Telegram: https://t.me/heritynetwork

*/

/* SPDX-License-Identifier: Unlicensed */
pragma solidity ^0.8.7;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );
}

contract HerityNetwork is Context, IERC20, Ownable {
    using SafeMath for uint256;
    string private constant _name = unicode"HerityNetwork";
    string private constant _symbol = "HER";
    uint8 private constant _decimals = 9;
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public _isExcludedFromFee;
    uint256 private constant MAX = ~uint256(0);
    bool public swapAndLiquifyEnabled = true;
    uint256 public _numTokensSellToAddToLiquidity = 25 * (10**12);
    uint256 private constant _tTotal = 100000000 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    uint256 public _liquidityFee = 8;

    // made public for transparency
    address payable public _buybackAddress;
    address payable public _ongAddress;
    address public _routerAddress;
    //
    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool private inSwap = false;
    uint256 public _maxTxAmount = _tTotal;

    event MaxTxAmountUpdated(uint256 _maxTxAmount);
    event NumTokensSoldUpdated(uint256 numTokensSellToAddToLiquidity);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor(
        address payable buyback,
        address payable ong,
        address router
    ) {
        _buybackAddress = buyback;
        _ongAddress = ong;
        _routerAddress = router;
        _rOwned[_msgSender()] = _rTotal;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_routerAddress] = true;
        _isExcludedFromFee[_buybackAddress] = true;
        _isExcludedFromFee[_ongAddress] = true;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            _routerAddress
        );
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
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

    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return tokenFromReflection(_rOwned[account]);
    }

    function humanBalanceOf(address account) public view returns (uint256) {
        return balanceOf(account).div(10**9);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function setIsExcludedFromFee(address _address, bool _isExcluded)
        external
        onlyOwner
    {
        _isExcludedFromFee[_address] = _isExcluded;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function setBuybackAddress(address payable _address) external onlyOwner {
        _buybackAddress = _address;
    }

    function setOngAddress(address payable _address) external onlyOwner {
        _ongAddress = _address;
    }

    function tokenFromReflection(uint256 rAmount)
        private
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function removeAllFee() private {
        if (_liquidityFee == 0) return;
        _liquidityFee = 0;
    }

    function restoreAllFee() private {
        _liquidityFee = 8;
    }

    function setRemoveAllFee() external onlyOwner {
        if (_liquidityFee == 0) return;
        _liquidityFee = 0;
    }

    function setRestoreAllFee() external onlyOwner {
        _liquidityFee = 8;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
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
        bool takeFee = false;

        if (from != owner() && to != owner()) {
            // buy handler
            if (
                from == uniswapV2Pair &&
                to != address(uniswapV2Router) &&
                !_isExcludedFromFee[to]
            ) {
                require(
                    amount <= _maxTxAmount,
                    "Amount larger than max tx amount!"
                );
                takeFee = false;
            }

            // sell handler
            if (
                !inSwap &&
                to == uniswapV2Pair &&
                from != address(uniswapV2Router)
            ) {
                require(amount <= _maxTxAmount,
                    "Slippage is over MaxTxAmount!"
                );
                takeFee = true;
                uint256 contractTokenBalance = balanceOf(address(this));
                bool overMinTokenBalance = contractTokenBalance >=
                    _numTokensSellToAddToLiquidity;
                if (overMinTokenBalance && swapAndLiquifyEnabled) {
                    swapTokensForEth(_numTokensSellToAddToLiquidity);
                }
            }
        }

        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        _tokenTransfer(from, to, amount, takeFee);
        restoreAllFee();
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;
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

        uint256 amount = address(this).balance.sub(initialBalance);
        uint256 half = amount.div(2);
        _ongAddress.transfer(half);
        _buybackAddress.transfer(amount.sub(half));
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();
        _transferStandard(sender, recipient, amount);
        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        // _getTValues
        uint256 tLiquidityFee = tAmount.mul(_liquidityFee).div(100);
        uint256 tTransferAmount = tAmount.sub(tLiquidityFee);
        // _getRValues
        uint256 currentRate = _getRate();
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rLiquidityFee = tLiquidityFee.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rLiquidityFee);

        _calculateReflectTransfer(sender, recipient, rAmount, rTransferAmount);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidityFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    // added to reduce stack
    function _calculateReflectTransfer(
        address sender,
        address recipient,
        uint256 rAmount,
        uint256 rTransferAmount
    ) private {
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
    }

    // allow contract to receive deposits
    receive() external payable {}

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function setMaxTxPercent(uint256 maxTxPercent, uint256 power) external onlyOwner {
        require(maxTxPercent > 0, "Percent must be greater than 0");
        require(power > 1 && power < 5, "Power must be betweeen 1 and 5");
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(10 ** power);
        emit MaxTxAmountUpdated(_maxTxAmount);
    }

    function setNumTokensToAddToLiquidity(uint256 percent, uint256 power) external onlyOwner {
        require(percent > 0, "Percent must be greater than 0");
        require(power > 11, "Power must be greater than 11");
        _numTokensSellToAddToLiquidity = percent * (10 ** power);
        emit NumTokensSoldUpdated(_numTokensSellToAddToLiquidity);
    }

    function manualSwap() external onlyOwner {
        require(!inSwap, "Already in swap");
        uint256 amount = balanceOf(address(this));
        if (amount > _numTokensSellToAddToLiquidity) amount = _numTokensSellToAddToLiquidity;
        swapTokensForEth(amount);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function withdrawResidualBnb(address newAddress) external onlyOwner {
        payable(newAddress).transfer(address(this).balance);
    }
    
    function transferResidualErc20(IERC20 token, address to) external onlyOwner {
        uint256 erc20balance = token.balanceOf(address(this));
        token.transfer(to, erc20balance);
    }
}