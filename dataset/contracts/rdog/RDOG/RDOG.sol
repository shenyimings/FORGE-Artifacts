// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

interface IBEP20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event Burn(address indexed owner, address indexed to, uint value);
}

library SafeMath {
    function add(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint a, uint b) internal pure returns (uint) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint a,
        uint b,
        string memory errorMessage
    ) internal pure returns (uint) {
        require(b <= a, errorMessage);
        uint c = a - b;

        return c;
    }

    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) {
            return 0;
        }

        uint c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint a, uint b) internal pure returns (uint) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint a,
        uint b,
        string memory errorMessage
    ) internal pure returns (uint) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint c = a / b;

        return c;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() internal {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IPancakeRouter01 {
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
    )
        external
        returns (
            uint amountA,
            uint amountB,
            uint liquidity
        );

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (
            uint amountToken,
            uint amountETH,
            uint liquidity
        );

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
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
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

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) external pure returns (uint amountB);

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut);

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountIn);

    function getAmountsOut(uint amountIn, address[] calldata path)
        external
        view
        returns (uint[] memory amounts);

    function getAmountsIn(uint amountOut, address[] calldata path)
        external
        view
        returns (uint[] memory amounts);
}

interface IPancakeRouter02 is IPancakeRouter01 {
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
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
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

interface IPancakeFactory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint) external view returns (address pair);

    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}

contract BEP20 is Context, Ownable, IBEP20 {
    using SafeMath for uint;

    mapping(address => uint) internal _balances;
    mapping(address => mapping(address => uint)) internal _allowances;
    mapping(address => bool) private _isExcluded;
    mapping(address => bool) public isMarketPair;

    uint public totalBurn;

    uint internal _totalSupply;

    uint256 public _taxFee = 13;
    uint256 public _liquidityFee = 2;
    uint256 public _lpHolderFee = 3;
    uint256 public _lpPowerFee = 3;
    uint256 public _fundFee = 2;
    uint256 public _communityFee = 1;
    uint256 public _burnFee = 2;
    bool public _sellFeeEnable = true;
    bool public _buyFeeEnable = false;
    uint256 private numTokensSellToAddToLiquidity = 50000 * 10**18;
    bool private inSwapAndLiquify;

    address public Liquidity = 0xED91611CcA6729844760bD48B312eA15e62C8723;
    address public LPHolder = 0x2c5D2e6ea7101C91A0cE263405cdA0fAf2EFeCb8;
    address public LPPower = 0x2c5D2e6ea7101C91A0cE263405cdA0fAf2EFeCb8;
    address public Fund = 0x7EB480D2d465A8C2aF30454263c380B0677af9F5;
    address public Community = 0x58493acaA44290B1506110B0584D1e406aa7B129;
    address public DeadAddress = 0x000000000000000000000000000000000000dEaD;

    IPancakeRouter02 public swapRouter;
    address public swapPair;

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor() internal {
        swapRouter = IPancakeRouter02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );
        swapPair = IPancakeFactory(swapRouter.factory()).createPair(
            address(this),
            swapRouter.WETH()
        );

        _isExcluded[owner()] = true;
        _isExcluded[address(this)] = true;
        isMarketPair[swapPair] = true;
    }

    receive() external payable {}

    function totalSupply() public view override returns (uint) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint) {
        return _balances[account];
    }

    function transfer(address recipient, uint amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address towner, address spender)
        public
        view
        override
        returns (uint)
    {
        return _allowances[towner][spender];
    }

    function approve(address spender, uint amount)
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
        uint amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "BEP20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint addedValue)
        public
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint subtractedValue)
        public
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "BEP20: decreased allowance below zero"
            )
        );
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint amount
    ) internal {
        require(sender != address(0), "BEP20: transfer from the zero address");

        if (inSwapAndLiquify) {
            _basicTransfer(sender, recipient, amount);
        } else {
            _balances[sender] = _balances[sender].sub(
                amount,
                "BEP20: transfer amount exceeds balance"
            );

            _swap(recipient);

            uint256 netAmount = _takeFees(sender, recipient, amount);

            _balances[recipient] = _balances[recipient].add(netAmount);

            _burn(sender, recipient, amount);

            emit Transfer(sender, recipient, netAmount);
        }
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(
            amount,
            "BEP20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function _takeFees(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (uint256 netAmount) {
        uint256 tax = 0;

        if (
            (_buyFeeEnable && isMarketPair[sender]) ||
            (_sellFeeEnable && isMarketPair[recipient])
        ) {
            tax = amount.mul(_taxFee).div(100);
        }

        if (_isExcluded[sender] || _isExcluded[recipient]) {
            tax = 0;
        }

        netAmount = amount - tax;

        if (tax > 0) {
            _takeFee(sender, address(this), tax, _liquidityFee);
            _takeFee(sender, LPHolder, tax, _lpHolderFee);
            _takeFee(sender, LPPower, tax, _lpPowerFee);
            _takeFee(sender, Fund, tax, _fundFee);
            _takeFee(sender, Community, tax, _communityFee);
            _takeBurnFee(sender, DeadAddress, tax);
        }
    }

    function _takeFee(
        address sender,
        address recipient,
        uint256 _tax,
        uint256 _feeRate
    ) private {
        uint256 fee = _tax.mul(_feeRate).div(_taxFee);
        _balances[recipient] = _balances[recipient].add(fee);
        emit Transfer(sender, recipient, fee);
    }

    function _takeBurnFee(
        address sender,
        address recipient,
        uint256 tax
    ) private {
        uint256 fee = tax.mul(_burnFee).div(_taxFee);
        _balances[recipient] = _balances[recipient].add(fee);
        _burn(sender, recipient, fee);
        emit Transfer(sender, recipient, fee);
    }

    function _burn(
        address sender,
        address recipient,
        uint amount
    ) private {
        if (recipient == address(0) || recipient == DeadAddress) {
            totalBurn = totalBurn.add(amount);
            _totalSupply = _totalSupply.sub(amount);

            emit Burn(sender, DeadAddress, amount);
        }
    }

    function _approve(
        address towner,
        address spender,
        uint amount
    ) internal {
        require(towner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[towner][spender] = amount;
        emit Approval(towner, spender, amount);
    }

    function _swap(address recipient) internal {
        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinTokenBalance = contractTokenBalance >=
            numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance && !inSwapAndLiquify && isMarketPair[recipient]
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            // add liquidity
            swapAndLiquify(contractTokenBalance);
        }
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = swapRouter.WETH();

        _approve(address(this), address(swapRouter), tokenAmount);

        // make the swap
        swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(swapRouter), tokenAmount);

        // add the liquidity
        swapRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            Liquidity,
            block.timestamp
        );
    }

    function excludeFrom(address account) external onlyOwner {
        _isExcluded[account] = false;
    }

    function includeIn(address account) external onlyOwner {
        _isExcluded[account] = true;
    }

    function setLPHolderAddr(address _addr) external onlyOwner {
        require(_addr != address(0), "address is zero");
        LPHolder = _addr;
    }

    function setLPPowerAddr(address _addr) external onlyOwner {
        require(_addr != address(0), "address is zero");
        LPPower = _addr;
    }

    function setFundAddr(address _addr) external onlyOwner {
        require(_addr != address(0), "address is zero");
        Fund = _addr;
    }

    function setCommunityAddr(address _addr) external onlyOwner {
        require(_addr != address(0), "address is zero");
        Community = _addr;
    }

    function setLiquidityAddr(address _addr) external onlyOwner {
        require(_addr != address(0), "address is zero");
        Liquidity = _addr;
    }

    function setRouterAddr(address _addr) external onlyOwner {
        require(_addr != address(0), "address is zero");
        swapRouter = IPancakeRouter02(_addr);
    }

    function setSellToAddToLiquidity(uint256 _num) external onlyOwner {
        require(_num > 0, "params error");
        numTokensSellToAddToLiquidity = _num;
    }

    function setMarketPairStatus(address account, bool newValue)
        external
        onlyOwner
    {
        isMarketPair[account] = newValue;
    }

    function getMarketPairStatus(address account) external view returns (bool) {
        return isMarketPair[account];
    }

    function setSellFeeEnable(bool newValue) external onlyOwner {
        _sellFeeEnable = newValue;
    }

    function setBuyFeeEnable(bool newValue) external onlyOwner {
        _buyFeeEnable = newValue;
    }

    function setRates(
        uint256 taxFee,
        uint256 liquidityFee,
        uint256 lpHolderFee,
        uint256 lpPowerFee,
        uint256 fundFee,
        uint256 communityFee,
        uint256 burnFee
    ) external onlyOwner {
        require(
            taxFee ==
                (liquidityFee +
                    lpHolderFee +
                    lpPowerFee +
                    fundFee +
                    communityFee +
                    burnFee),
            "params error"
        );
        _taxFee = taxFee;
        _liquidityFee = liquidityFee;
        _lpHolderFee = lpHolderFee;
        _lpPowerFee = lpPowerFee;
        _fundFee = fundFee;
        _communityFee = communityFee;
        _burnFee = burnFee;
    }
}

contract BEP20Detailed is BEP20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(
        string memory tname,
        string memory tsymbol,
        uint8 tdecimals
    ) internal BEP20() {
        _name = tname;
        _symbol = tsymbol;
        _decimals = tdecimals;
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
}

contract RDOG is BEP20Detailed {
    constructor() public BEP20Detailed("Robot Dog", "RDOG", 18) {
        _totalSupply = 100_000_000_000 * (10**18);

        _balances[_msgSender()] = _totalSupply;

        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function takeOutTokenInCase(
        address _token,
        uint256 _amount,
        address _to
    ) public onlyOwner {
        IBEP20(_token).transfer(_to, _amount);
    }
}