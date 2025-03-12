// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.10;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


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

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

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

contract SPAL is IERC20, Ownable {
    address constant dead = 0x000000000000000000000000000000000000dEaD;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    IUniswapV2Router02 public immutable pcsV2Router;
    address public immutable pcsV2Pair;
    address payable public _marketingAddress;
    address payable public _buybackAddress;

    event FeesUpdated(uint8 liquidityFee,uint8 marketingFee,uint8 buybackFee);
    event FeeWalletsUpdated(address newMarketingAddress,address newBuybackAddress);
    event SellBurnedTokens(uint256 tokensAmount);
    event DistributeToMarketingAddress(uint256 tokensAmount);
    event DistributeToBuybackAddress(uint256 tokensAmount);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);
    event LiquidityTokensNumUpdated(uint amountLimit);

    uint256 private _totalSupply = 0 * 10**18;
    string public name = "SPAL";
    string public symbol =  "SPAL";
    uint8 public decimals = 18;

    uint8 public _liquidityFee = 5; // Fee for Liquidity
    uint8 public _marketingFee = 5; // Fee to marketing wallet
    uint8 public _buybackFee = 2; // Fee for buyback of tokens

    address constant _legacyToken = 0xcd04A5899BC5386D2ce3E95489671aA30713F2ac;
    constructor(){
        _marketingAddress = payable(0x50e0EbDC2650C3EDD296586247491e3eF3339FC8);
        _buybackAddress = payable(0x1AbB2EdA7cFe84Eb39753E3113dA28C9fB265BAf);
        // MAINNET ROUTER
        IUniswapV2Router02 _pcsV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        // Create a uniswap pair for this new token
        pcsV2Pair = IUniswapV2Factory(_pcsV2Router.factory()).createPair(address(this), _pcsV2Router.WETH());
        // set the rest of the contract variables
        pcsV2Router = _pcsV2Router;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(recipient != _msgSender(), "Cannot transfer to yourself");
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

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(_allowances[sender][_msgSender()] >= amount, "Allowance not enough");
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        require(_allowances[_msgSender()][spender] >= subtractedValue, "Allowance not enough");
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );
        return true;
    }


    function setAllFeePercent(
        uint8 liquidityFee,
        uint8 marketingFee,
        uint8 buybackFee
    ) external onlyOwner {
        require(
            liquidityFee + marketingFee + buybackFee <= 12,
            "Total fees exceed the limit"
        );
        _liquidityFee = liquidityFee;
        _marketingFee = marketingFee;
        _buybackFee = buybackFee;
        emit FeesUpdated(liquidityFee,marketingFee,buybackFee);
    }


    function setFeeWallet(address payable newMarketingAddress, address payable newBuybackAddress) external onlyOwner {
        require(newMarketingAddress != address(0),
            "Invalid marketing address");
        require(newBuybackAddress != address(0),
            "Invalid buyback address");
        _marketingAddress = newMarketingAddress;
        _buybackAddress = newBuybackAddress;
        emit FeeWalletsUpdated(newMarketingAddress,newBuybackAddress);
    }

    //to recieve ETH from pcsV2Router when swaping
    receive() external payable {}

    function _takeLiquidity(uint256 _feeLiquidity) private {
        _balances[address(this)] = _balances[address(this)] + _feeLiquidity;
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount * (_liquidityFee + _marketingFee + _buybackFee) / (10**2);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "INVALID OWNER ADDRESS");
        require(spender != address(0), "INVALID SPENDER ADDRESS");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0),"Invalid from address");
        require(to != address(0),"Invalid to address");
        require(amount > 0,"Invalid transfer amount");
        
        bool takeFee = false;

        if(to == pcsV2Pair && from != address(this)){
            takeFee = true;
        }

        _tokenTransfer(from, to, amount, takeFee);
    }


    function distributeBurnedTokens() public onlyOwner{
        uint256 contractTokenBalance = balanceOf(address(this));
        require(contractTokenBalance > 0, "balance cannot be zero");
        sellBurnedTokens(contractTokenBalance);        
    }

    function sellBurnedTokens(uint256 contractTokenBalance) private {
        uint8 totFee = _marketingFee + _liquidityFee + _buybackFee;
        uint256 spentAmount = 0;
        require(totFee > 0, "Total fee cannot be zero");
        
            
        if (_marketingFee != 0) {
            spentAmount = contractTokenBalance / totFee * _marketingFee;
            swapTokensForBNB(spentAmount,_marketingAddress);
            emit DistributeToMarketingAddress(spentAmount);
        }

        if (_buybackFee != 0) {
            spentAmount = contractTokenBalance / totFee * _buybackFee;
            swapTokensForBNB(spentAmount,_buybackAddress);
            emit DistributeToBuybackAddress(spentAmount);            
        }
    
        if (_liquidityFee != 0) {
            spentAmount = contractTokenBalance / totFee * _liquidityFee;

            // split the contract balance into halves
            uint256 half = spentAmount / 2;
            uint256 otherHalf = spentAmount - half;

            // capture the contract's current ETH balance.
            // this is so that we can capture exactly the amount of ETH that the
            // swap creates, and not make the liquidity event include any ETH that
            // has been manually sent to the contract
            uint256 initialBalance = address(this).balance;

            // swap tokens for ETH
            swapTokensForBNB(half,address(this)); // <- this breaks the ETH -> SPAL swap when swap+liquify is triggered

            // how much ETH did we just swap into?
            uint256 addBalance = address(this).balance - initialBalance;

            // add liquidity to uniswap
            addLiquidity(otherHalf, addBalance);

            emit SwapAndLiquify(half, addBalance, otherHalf);
        }
        
        emit SellBurnedTokens(contractTokenBalance); 
              
    }

    function swapBNBForTokens(uint256 amount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = pcsV2Router.WETH();
        path[1] = address(this);

        // make the swap
        pcsV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            dead, // Burn address
            block.timestamp + 300
        );
    }

    function swapTokensForBNB(uint256 tokenAmount, address transferAddr) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pcsV2Router.WETH();

        _approve(address(this), address(pcsV2Router), tokenAmount);

        // make the swap
        pcsV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            transferAddr,
            block.timestamp + 300
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(pcsV2Router), tokenAmount);

        // add the liquidity
        (, , uint liquidity) = pcsV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            dead,
            block.timestamp + 300
        );

        require(liquidity > 0, "addLiquidity failed");
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        uint256 feeLiquidity = 0;
        if (takeFee) {
            feeLiquidity = calculateLiquidityFee(amount);
            if(feeLiquidity > 0 ){
                _takeLiquidity(feeLiquidity);
                emit Transfer(sender, address(this), feeLiquidity);
            }
        }
        _balances[sender] = _balances[sender] - amount;
        uint256 realAmount = amount - feeLiquidity;
        _balances[recipient] = _balances[recipient] + realAmount;        
        emit Transfer(sender, recipient, realAmount);
    }

    function migrateLegacyToken(uint256 amount) public{
        require(_legacyToken != address(0), "Legacy token address not set");
        IERC20(_legacyToken).transferFrom(_msgSender(), dead, amount);
        _totalSupply = _totalSupply + amount;
        _balances[_msgSender()] = _balances[_msgSender()] + amount;        
        emit Transfer(address(0), _msgSender(), amount);
    }

}