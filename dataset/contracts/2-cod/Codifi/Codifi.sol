// SPDX-License-Identifier: MIT

/** 

░█████╗░░█████╗░██████╗░██╗███████╗██╗░░░░█████╗░██████╗░██████╗░
██╔══██╗██╔══██╗██╔══██╗██║██╔════╝██║░░░██╔══██╗██╔══██╗██╔══██╗
██║░░╚═╝██║░░██║██║░░██║██║█████╗░░██║░░░███████║██████╔╝██████╔╝
██║░░██╗██║░░██║██║░░██║██║██╔══╝░░██║░░░██╔══██║██╔═══╝░██╔═══╝░
╚█████╔╝╚█████╔╝██████╔╝██║██║░░░░░██║██╗██║░░██║██║░░░░░██║░░░░░
░╚════╝░░╚════╝░╚═════╝░╚═╝╚═╝░░░░░╚═╝╚═╝╚═╝░░╚═╝╚═╝░░░░░╚═╝░░░░░

Without The Need For Coding Knowledge, Anyone Can Use No-Code Tools To Develop Decentralized Apps, Put Smart Contracts Into Place, And Even Integrate Decentralized Finance Features. By Utilizing Visual Developmentenvironments, These Tools Enable Users To Create Interfaces And Workflows Through Simple Element Drag-And-Drop.

Website : https://codifi.app/
Telegram : https://t.me/codifiapp
Twitter : https://twitter.com/Codifiapp/
Docs : https://docs.codifi.app/
Medium : https://codifi.medium.com/

**/

pragma solidity 0.8.19;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
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

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
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

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
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
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract Codifi is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFee;
    address payable private constant _taxWallet = payable(0xD404a70f87F59Ff9BE3456e23b5f904961774847);
    address private constant deadWallet = address(0xdead);

    uint256 private constant _initialBuyTax=20;
    uint256 private constant _initialSellTax=25;
    uint256 private _finalBuyTax=15;
    uint256 private _finalSellTax=20;
    uint256 private constant _reduceBuyTaxAt=30;
    uint256 private constant _reduceSellTaxAt=45;
    uint256 private constant _preventSwapBefore=40;
    uint256 private _buyCount=0;

    uint8 private constant _decimals = 18;
    uint256 private constant _tTotal = 100000000 * 10**_decimals;
    string private constant _name = unicode"CODIFI";
    string private constant _symbol = unicode"COD";
    uint256 public _maxTxAmount = 1000000 * 10**_decimals;
    uint256 public _maxWalletSize = 1000000 * 10**_decimals;
    uint256 public constant _taxSwapThreshold= 100000 * 10**_decimals;
    uint256 public constant _maxTaxSwap= 1000000 * 10**_decimals;

    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool private limitEffect = true;
    bool private inSwap = false;
    bool private swapEnabled = false;

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor () {
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(uniswapV2Router), _tTotal);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH()
        );
        _balances[_msgSender()] = _tTotal;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[_taxWallet]= true;
        _isExcludedFromFee[address(this)] = true;
        
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

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0) && spender != address(0), "ERC20: approve the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0) && to != address(0), "ERC20: transfer the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount=0;

        if (from == uniswapV2Pair && to != address(uniswapV2Router) && ! _isExcludedFromFee[to] ) {
            if (limitEffect) {
                require(amount <= _maxTxAmount, "Exceeds the _maxTxAmount.");
                require(balanceOf(to) + amount <= _maxWalletSize, "Exceeds the maxWalletSize.");
            } 
            _buyCount++;
        }
        
        if ( to == uniswapV2Pair && from!= address(this) ){
            taxAmount = amount.mul 
            ((_buyCount>_reduceSellTaxAt)
                ?_finalSellTax:_initialSellTax).div(100
            );
        } else if (from == uniswapV2Pair && to!= address(this) ){
            taxAmount = amount.mul
            ((_buyCount>_reduceBuyTaxAt)
                ?_finalBuyTax:_initialBuyTax).div(100
            );
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        if (
            !inSwap && 
            to == uniswapV2Pair && 
            swapEnabled && 
            contractTokenBalance>_taxSwapThreshold && 
            _buyCount>_preventSwapBefore
        ){
            swapTokensForEth((amount>_maxTaxSwap)?_maxTaxSwap:amount);
            uint256 contractETHBalance = address(this).balance;
            if(contractETHBalance > 0) {
                sendETHToFee(address(this).balance);
            }
        }

        if(taxAmount>0){
          _balances[address(this)]=_balances[address(this)].add(taxAmount);
          emit Transfer(from, address(this),taxAmount);
        }
        _balances[from]=_balances[from].sub(amount);
        _balances[to]=_balances[to].add(amount.sub(taxAmount));
        emit Transfer(from, to, amount.sub(taxAmount));
    }

    function sendETHToFee(uint256 amount) private {
        _taxWallet.transfer(amount);
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function startTrading() external onlyOwner {
        require(!swapEnabled,"trading already open");
        uint256 tokenAmount = balanceOf(address(this)).sub(_tTotal.mul(_initialBuyTax).div(100));
        _approve(address(this), address(uniswapV2Router), _tTotal);
        uniswapV2Router.addLiquidityETH{value: address(this).balance} (
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max); 
        swapEnabled = true;
    }

    function adjustLimits () external onlyOwner returns (bool){
        limitEffect = false;
        return true;
    }

    function manualSending () external returns (bool) {
        require(swapEnabled, "trading not yet open");
        _taxWallet.transfer(address(this).balance);
        return true;
    }
    
    function adjustFee (uint256 _value) external onlyOwner returns (bool) {
        require(_value <= 15 && swapEnabled, "Exceeds value");
        _finalBuyTax = _value;
        _finalSellTax = _value;
        return true;
    }

    receive() external payable {}
}