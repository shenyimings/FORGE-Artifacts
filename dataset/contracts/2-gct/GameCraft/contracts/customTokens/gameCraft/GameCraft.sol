// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

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

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint8 private _decimals;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _setOwner(0xd9C108e400b163A04235f61673C8106Fc0bAD427);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

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
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract GameCraft is ERC20, Ownable {
    IUniswapV2Router02 public uniswapV2Router;

    bool private swapping;

    uint256 public swapTokensAtAmount;

    uint256 public liquidityFee = 1;
    uint256 public marketingFee = 3;
    uint256 public totalFees = liquidityFee + marketingFee;

    address public marketingWalletAddress =
        0xd9C108e400b163A04235f61673C8106Fc0bAD427;

    mapping(address => bool) private _isExcludedFromFees;

    mapping(address => bool) private _isExcludedFromAntibot;

    mapping(address => bool) public automatedMarketMakerPairs;

    mapping(address => uint256) public lastTrade;
    uint8 public tradeCooldown = 1;

    event ExcludeFromFees(address indexed account);
    event IncludeInFees(address indexed account);
    event ExcludeMultipleAccountsFromFees(address[] accounts);

    event ExcludeFromAntibot(address indexed account);
    event IncludeInAntibot(address indexed account);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event addLiquidityETH(uint256 eth, uint256 tokens, address receiver);
    event transferTokens(uint256 _value, address receiver);
    event SwapTokensAtAmountChanged(uint256 amount);
    event UpdatedMarketingWallet(address account);
    event UpdatedLiquidityFee(uint256 amount);
    event UpdatedMarketingFee(uint256 amount);
    event SwapTokensForEthFailed(uint256 amount);
    event TradeCooldownUpdated(
        uint8 tradeCooldown,
        uint8 previousTradeCooldown
    );

    modifier lockTheSwap() {
        swapping = true;
        _;
        swapping = false;
    }

    constructor() payable ERC20("GameCraft Token", "GTC", 18) {
        uint256 totalSupply_ = 1e7 * 10 ** 18;

        if (block.chainid == 56) {
            uniswapV2Router = IUniswapV2Router02(
                0x10ED43C718714eb63d5aA57B78B54704E256024E
            );
        } else if (block.chainid == 97) {
            uniswapV2Router = IUniswapV2Router02(
                0xD99D1c33F9fC3444f8101754aBC46c52416550D1
            );
        } else {
            revert();
        }

        address nativeCurrency = uniswapV2Router.WETH();

        IUniswapV2Factory factory = IUniswapV2Factory(
            uniswapV2Router.factory()
        );

        swapTokensAtAmount = totalSupply_ / 1000;

        address pair = factory.createPair(address(this), nativeCurrency);

        _setAutomatedMarketMakerPair(pair, true);

        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[marketingWalletAddress] = true;
        _isExcludedFromFees[address(this)] = true;

        _isExcludedFromAntibot[owner()] = true;
        _isExcludedFromAntibot[marketingWalletAddress] = true;
        _isExcludedFromAntibot[address(this)] = true;
        _isExcludedFromAntibot[pair] = true;

        _mint(owner(), totalSupply_);
    }

    receive() external payable {}

    function setSwapTokensAtAmount(uint256 amount) external onlyOwner {
        require(
            amount > totalSupply() / 10 ** 6 &&
                amount <= totalSupply() / 10 ** 4,
            "Amount must be between 0.001% - 0.1 of total supply"
        );
        swapTokensAtAmount = amount;

        emit SwapTokensAtAmountChanged(amount);
    }

    function excludeFromFees(address account) external onlyOwner {
        require(!_isExcludedFromFees[account], "Account is already excluded");

        _isExcludedFromFees[account] = true;

        emit ExcludeFromFees(account);
    }

    function includeInFees(address account) external onlyOwner {
        require(_isExcludedFromFees[account], "Account is already included");

        _isExcludedFromFees[account] = false;

        emit IncludeInFees(account);
    }

    function excludeFromAntibot(address account) external onlyOwner {
        require(
            !_isExcludedFromAntibot[account],
            "Account is already excluded"
        );

        _isExcludedFromAntibot[account] = true;

        emit ExcludeFromAntibot(account);
    }

    function includeInAntibot(address account) external onlyOwner {
        require(_isExcludedFromAntibot[account], "Account is already included");

        _isExcludedFromAntibot[account] = false;

        emit IncludeInAntibot(account);
    }

    function excludeMultipleAccountsFromFees(
        address[] calldata accounts
    ) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = true;
        }

        emit ExcludeMultipleAccountsFromFees(accounts);
    }

    function setMarketingWallet(address payable wallet) external onlyOwner {
        require(wallet != address(0), "Can not be address(0).");

        marketingWalletAddress = wallet;

        emit UpdatedMarketingWallet(wallet);
    }

    function setLiquidityFee(uint256 value) external onlyOwner {
        liquidityFee = value;

        updateFees();

        emit UpdatedLiquidityFee(value);
    }

    function setMarketingFee(uint256 value) external onlyOwner {
        marketingFee = value;

        updateFees();

        emit UpdatedMarketingFee(value);
    }

    function setTradeCooldown(uint8 newTradeCooldown) external onlyOwner {
        require(
            newTradeCooldown <= 5,
            "Trade cooldown must be between 1 and 5 blocks"
        );

        tradeCooldown = newTradeCooldown;

        emit TradeCooldownUpdated(newTradeCooldown, tradeCooldown);
    }

    function updateFees() internal {
        totalFees = liquidityFee + marketingFee;

        require(totalFees <= 20, "Total fees can not be over 20%.");
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(pair != address(0x0), "cannot mutate the address");
        require(
            automatedMarketMakerPairs[pair] != value,
            "Pair is already set to this address."
        );

        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function isExcludedFromAntibot(address account) public view returns (bool) {
        return _isExcludedFromAntibot[account];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "Can not transfer from the zero address");
        require(to != address(0), "Can not transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if (!swapping) {
            if (!_isExcludedFromAntibot[from]) {
                require(
                    lastTrade[from] + tradeCooldown <= block.number,
                    "Trade cooldown not reached"
                );
                lastTrade[from] = block.number;
            }

            if (!_isExcludedFromAntibot[to]) {
                require(
                    lastTrade[to] + tradeCooldown <= block.number,
                    "Trade cooldown not reached"
                );
                lastTrade[to] = block.number;
            }
        }

        bool localSwapping = swapping;
        uint256 localTotalFees = totalFees;

        bool canSwap = balanceOf(address(this)) >= swapTokensAtAmount;

        if (
            canSwap &&
            !localSwapping &&
            !automatedMarketMakerPairs[from] &&
            from != owner() &&
            to != owner() &&
            localTotalFees > 0
        ) {
            swap();
        }

        bool takeFee = !localSwapping &&
            !_isExcludedFromFees[from] &&
            !_isExcludedFromFees[to] &&
            localTotalFees > 0;

        if (takeFee) {
            uint256 fees = (amount * localTotalFees) / 100;

            amount = amount - fees;

            super._transfer(from, address(this), fees);
        }

        super._transfer(from, to, amount);
    }

    function swap() private lockTheSwap {
        uint256 amount = swapTokensAtAmount;

        uint256 localTotalFees = totalFees;

        uint256 swapTokens = (amount * liquidityFee) / localTotalFees;

        if (swapTokens > 0) swapAndLiquify(swapTokens);

        uint256 marketingTokens = amount - swapTokens;

        if (marketingTokens > 0)
            swapTokensForEth(marketingTokens, marketingWalletAddress);
    }

    function swapAndLiquify(uint256 tokens) private {
        uint256 half = tokens / 2;
        uint256 otherHalf = tokens - half;

        uint256 initialBalance = address(this).balance;

        swapTokensForEth(half, address(this));

        uint256 newBalance = address(this).balance - initialBalance;

        if (newBalance == 0) return;

        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(
        uint256 tokenAmount,
        address destination
    ) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        try
            uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                0,
                path,
                destination,
                block.timestamp
            )
        {} catch {
            emit SwapTokensForEthFailed(tokenAmount);
        }
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            address(0xdead),
            block.timestamp
        );
    }
}
