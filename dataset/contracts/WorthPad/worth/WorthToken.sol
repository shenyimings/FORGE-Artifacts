// SPDX-License-Identifier: MIT

/* OpenZeppelin Standard Imports */
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

pragma solidity 0.8.10;

/* Interface for Pancakeswap V2 Factory */
interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

/* Interface for Pancakeswap v2 pair  */
interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

/* Interface for Pancakeswap route V1 */
interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

/* Interface for Pancakeswap Route V2 */
interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

/* Main Contract of WorthToken starts here */
contract WorthToken is Context, IERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;

    string private constant NAME = "WorthToken";
    string private constant SYMBOL = "WORTH";
    uint8 private constant DECIMAL = 18;
    uint256 private constant DECIMALS = 10**18;
    uint256 private constant FEES_DIVISOR = 10**3; 
    uint256 private constant TOTAL_SUPPLY = 100 * 10**9 * DECIMALS; 
 
    uint256 public _liquidityFee = 25;
    uint256 private _previousLiquidityFee = _liquidityFee;

    uint256 public _worthDVCFundFee = 25;
    address public worthDVCFundWallet;
    uint256 private _previousWorthDVCFundFee = _worthDVCFundFee;

    uint256 public _maxTxAmount = 10 * 10**6 * DECIMALS;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    uint256 private numTokensSellToAddToLiquidity = 1 * 10**6 * DECIMALS;
    
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
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
    
    constructor (address _worthDVCFundWallet) {
        _balances[_msgSender()] = TOTAL_SUPPLY;
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        /* Create a Pancakeswap pair for this new token */
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        /* Set the rest of the contract variables */
        uniswapV2Router = _uniswapV2Router;
        
        /* Exclude owner and this contract from fee */
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        worthDVCFundWallet = _worthDVCFundWallet;
        
        emit Transfer(address(0), _msgSender(), TOTAL_SUPPLY);
    }

    /* Function     : Returns Name of token */
    /* Parameter    : -- */
    /* Public View function */
    function name() public pure returns (string memory) {
        return NAME;
    }

    /* Function     : Returns Symbol of token */
    /* Parameter    : -- */
    /* Public Pure function */
    function symbol() public pure returns (string memory) {
        return SYMBOL;
    }

    /* Function     : Returns Decimal of token */
    /* Parameter    : -- */
    /* Public Pure function */
    function decimal() public pure returns (uint8) {
        return DECIMAL;
    }

    /* Function     : Returns total supply of token */
    /* Parameter    : -- */
    /* Public Pure function */
    function totalSupply() public pure override returns (uint256) {
        return TOTAL_SUPPLY;
    }

    /* Function     : Function to check balance of the address */
    /* Parameter    : Wallet/Contract Address */
    /* Public View function */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    /* Function     : Function to check the value of Min Auto Liquidity Sell Amount */
    /* Parameters   : -- */
    /* Public View Function */
    function getMinAutoLiquidityAmount() public view returns (uint 256) {
        return numTokensSellToAddToLiquidity;
    }

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /* Function     : Function to Increase the approved allowance */
    /* Parameter 1  : Spenders Address */
    /* Parameter 2  : Value which needs to be added */
    /* Public function */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /* Function     : Function to Decrease the approved allowance */
    /* Parameter 1  : Spenders Address */
    /* Parameter 2  : Value which needs to be deducted */
    /* Public function */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /* To recieve BNB from uniswapV2Router when swaping */
    receive() external payable {}

    /* Internal function to remove all fees in transfer */
    function removeAllFee() private {
        if(_liquidityFee == 0 && _worthDVCFundFee==0) return;
        
        _previousLiquidityFee = _liquidityFee;
        _previousWorthDVCFundFee = _worthDVCFundFee;
        
        _liquidityFee = 0;
        _worthDVCFundFee = 0;
    }
    
    /* Internal function to restore all fees in transfer */
    function restoreAllFee() private {
       _liquidityFee = _previousLiquidityFee;
       _worthDVCFundFee = _previousWorthDVCFundFee;
    }
    
    /* Function     : Checks if a address is excluded from fee or not */
    /* Parameters   : Address of the wallet/contract */
    /* Public View Function */
    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    /* Internal Approve function to approve a token for trade/contract interaction */
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /* Internal Transfer function of Token */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if(from != owner() && to != owner()) {
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }

        /* 
        - Is the token balance of this contract address over the min number of
        - Tokens that we need to initiate a swap + liquidity lock?
        - Also, don't get caught in a circular liquidity event.
        - Also, don't swap & liquify if sender is Pancakeswap pair. 
        */

        uint256 contractTokenBalance = balanceOf(address(this));        
        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            /* Add liquidity */
            swapAndLiquify(contractTokenBalance);
        }
        
        /* Transfer amount, it will take tax, burn, liquidity fee */
        _tokenTransfer(from,to,amount);
    }

    /* Internal Function to swap Tokens and add to Liquidity */
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        /* Split the contract balance into halves */
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        /* 
        - Capture the contract's current BNB balance.
        - This is so that we can capture exactly the amount of BNB that the
        - Swap creates, and not make the liquidity event include any BNB that
        - Has been manually sent to the contract 
        */
        uint256 initialBalance = address(this).balance;

        /* Swap tokens for BNB */
        swapTokensForEth(half); // <- This breaks the BNB -> WORTH swap when swap+liquify is triggered

        /* How much BNB did we just swap into? */
        uint256 newBalance = address(this).balance.sub(initialBalance);

        /* Add liquidity to Pancakeswap */
        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    /* Internal Function to swap tokens for BNB */
    function swapTokensForEth(uint256 tokenAmount) private {
        /* Generate the Pancakeswap pair path of token -> wbnb */
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        /* Make the swap */
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp
        );
    }

    /* Internal function to Add Liquidity */
    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        /* Approve token transfer to cover all possible scenarios */
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        /* Add the liquidity */
        uniswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    /* Internal Basic function for Token Transfer */
    function _tokenTransfer(address sender, address recipient, uint256 amount) private {
        if(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]){
            removeAllFee();
        }
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");
        
        uint256 worthDVCFundFee = 0;
        uint256 liquidityAmount = 0;
        
        if(_worthDVCFundFee>0){
            /* Calculate WorthDVCFund Fee */
            worthDVCFundFee = amount.mul(_worthDVCFundFee).div(FEES_DIVISOR);
        }
        if(_liquidityFee>0){
            /* Calculate Liquidity Fee */
            liquidityAmount = amount.mul(_liquidityFee).div(FEES_DIVISOR);
        }
         
        if (_isExcludedFromFee[sender]) {
            _transferStandard(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, (amount.sub(worthDVCFundFee).sub(liquidityAmount)));
            _transferStandard(sender, worthDVCFundWallet, worthDVCFundFee);
            _transferStandard(sender, address(this), liquidityAmount);
        }
         
        /* Checks if address is excluded from fee and restores all fees */
        if(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient])
            restoreAllFee();
    }

    /* Internal Standard Transfer function for Token */
    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        _balances[sender] = _balances[sender].sub(tAmount);
        _balances[recipient] = _balances[recipient].add(tAmount);
        emit Transfer(sender, recipient, tAmount);
    }


    /* Function     : Exclude A wallet/contract in fee taking */
    /* Parameters   : Address of wallet/contract */
    /* Only Owner Function */
    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }
    
    /* Function     : Include A wallet/contract in fee taking */
    /* Parameters   : Address of wallet/contract */
    /* Only Owner Function */
    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }
    
    /* Function     : Disables the Liquidity and Worth DVC Fund fee  */
    /* Parameters   : -- */
    /* Only Owner Function */
    function disableAllFees() external onlyOwner {
       
        _liquidityFee = 0;
        _previousLiquidityFee = _liquidityFee;
     
        _worthDVCFundFee = 0;
        _previousWorthDVCFundFee = _worthDVCFundFee;
        inSwapAndLiquify = false;
        emit SwapAndLiquifyEnabledUpdated(false);
    }

    /* Function     : Enables The Liquidity and Worth DVC Fund fee  */
    /* Parameters   : -- */
    /* Only Owner Function */
    function enableAllFees() external onlyOwner {
        
        _liquidityFee = 25;
        _previousLiquidityFee = _liquidityFee;
        
        _worthDVCFundFee = 25;
        _previousWorthDVCFundFee = _worthDVCFundFee;
        inSwapAndLiquify = true;
        emit SwapAndLiquifyEnabledUpdated(true);
    }
    
    /* Function     : Set New Marketing wallet  */
    /* Parameters   : New Marketing Wallet address */
    /* Only Owner Function */
    function setWorthDVCFundWallet(address newWallet) external onlyOwner {
        worthDVCFundWallet = newWallet;
    }

    /* Function     : Set Liquidity fee percentage  */
    /* Parameters   : New Percentage to be executed */
    /* Only Owner Function */
    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner {
        _liquidityFee = liquidityFee;
    }
    
    /* Function     : Set Marketing fee percentage  */
    /* Parameters   : New Percentage to be executed */
    /* Only Owner Function */
    function setWorthDVCFundFeePercent(uint256 worthDVCFundFee) external onlyOwner {
        _worthDVCFundFee = worthDVCFundFee;
    }

    /* Function     : Set Minimum amount for swapping to Liquify for Liquidity and Marketing */
    /* Parameters   : Enter the  Minimum Token to swap */
    /* Only Owner Function */
    function setMinSell(uint256 amount) external onlyOwner {
        numTokensSellToAddToLiquidity = amount * DECIMALS;
    }

    /* Function     : Set Max transaction amount for each transfer  */
    /* Parameters   : Max Amount of token to be swapped */
    /* Only Owner Function */
    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner {
        _maxTxAmount = maxTxAmount * DECIMALS;
    }

    /* Function     : Set a new router if released  */
    /* Parameters   : New router Address */
    /* Only Owner Function */
    function setRouterAddress(address newRouter) public onlyOwner {
        IUniswapV2Router02 _newPancakeRouter = IUniswapV2Router02(newRouter);
        uniswapV2Pair = IUniswapV2Factory(_newPancakeRouter.factory()).createPair(address(this), _newPancakeRouter.WETH());
        uniswapV2Router = _newPancakeRouter;
    }
    
    /* Function     : Turns ON/OFF Liquidity swap */
    /* Parameters   : Set 'true' to turn ON and 'false' to turn OFF */
    /* Only Owner Function */
    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
}
