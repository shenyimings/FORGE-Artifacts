// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
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
    uint256 private constant MAX_SUPPLY = 1000000000 * (10 ** 18);

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        _transfer(from, to, amount);
        _approve(from, _msgSender(), _allowances[from][_msgSender()] - amount);
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

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        require(totalSupply() + amount <= MAX_SUPPLY, "ERC20: total supply exceeds maximum supply");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        require(_balances[account] >= amount, "ERC20: burn amount exceeds balance");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] -= amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IPancakeSwapPair {
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

		event Mint(address indexed sender, uint amount0, uint amount1);
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

		function mint(address to) external returns (uint liquidity);
		function burn(address to) external returns (uint amount0, uint amount1);
		function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
		function skim(address to) external;
		function sync() external;

		function initialize(address, address) external;
}

interface IPancakeSwapRouter{
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

interface IPancakeSwapFactory {
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

contract ChipToken is ERC20, Ownable {

    IPancakeSwapPair public pairContract;
    IPancakeSwapRouter public router;
    address public pair;

    address public teamWallet = 0x77EfCc5d19b9f85fDaB5f4b7CB1C93fC884af3E8;
    address public marketingWallet = 0xd754f78649C254E304A8406AcbA69d58E2b33044;
    address public treasuryWallet = 0x43a220eA526f2bfABc1fC1a05627bF371D457968;
    address public liquidityPool;
    address public constant BURN_ADRESS = 0x000000000000000000000000000000000000dEaD;

    uint256 public buyFeeTeam = 25; // 0.25%
    uint256 public buyFeeMarketing = 100; // 1%
    uint256 public buyFeeLiquidity = 125; // 1.25%
    uint256 public buyFeeBurn = 250; // 2.5%
    uint256 public buyFeeTreasury = 300; // 3%
    uint256 public sellFeeTeam = 50; // 0.5%
    uint256 public sellFeeMarketing = 100; // 1%
    uint256 public sellFeeLiquidity = 200; // 2%
    uint256 public sellFeeBurn = 250; // 2.5%
    uint256 public sellFeeTreasury = 400; // 4%
    uint256 public constant MAX_FEE = 500; // 5%

    mapping(address => bool) private _feeExemptAddresses; // Addresses exempt from fees

    event LiquidityPoolUpdated(address indexed previousPool, address indexed newPool);
    event BuyFeesUpdated(uint256 buyTeamFee, uint256 buyMarketingFee, uint256 buyLiquidityFee, uint256 buyBurnFee, uint256 buyTreasuryFee);
    event SellFeesUpdated(uint256 sellTeamFee, uint256 sellMarketingFee, uint256 sellLiquidityFee, uint256 sellBurnFee, uint256 sellTreasuryFee);

    constructor() ERC20("ChipToken", "CHIPT") {
        _mint(_msgSender(), 1000000 * (10 ** decimals()));

        _feeExemptAddresses[teamWallet] = true;
        _feeExemptAddresses[marketingWallet] = true;
        _feeExemptAddresses[treasuryWallet] = true;

        router = IPancakeSwapRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E); 
        pair = IPancakeSwapFactory(router.factory()).createPair(
            router.WETH(),
            address(this)
        );
        liquidityPool = pair;

        pairContract = IPancakeSwapPair(pair);
    }

    function setWallets(address team, address marketing, address treasury) external onlyOwner {
        require(team != address(0), "Cannot set team wallet to the zero address");
        require(marketing != address(0), "Cannot set marketing wallet to the zero address");
        require(treasury != address(0), "Cannot set treasury wallet to the zero address");

        teamWallet = team;
        marketingWallet = marketing;
        treasuryWallet = treasury;
    }

    function setLiquidityPool(address pool) external onlyOwner {
        emit LiquidityPoolUpdated(liquidityPool, pool);
        liquidityPool = pool;
    }

    function setBuyFees(uint256 buyteamFee, uint256 buymarketingFee, uint256 buyliquidityFee, uint256 buyburnFee, uint256 buytreasuryFee) external onlyOwner {
        require(buyteamFee <= MAX_FEE, "Exceeds maximum team fee");
        require(buymarketingFee <= MAX_FEE, "Exceeds maximum marketing fee");
        require(buyliquidityFee <= MAX_FEE, "Exceeds maximum liquidity fee");
        require(buyburnFee <= MAX_FEE, "Exceeds maximum burn fee");
        require(buytreasuryFee <= MAX_FEE, "Exceeds maximum treasury fee");

        buyFeeTeam = buyteamFee;
        buyFeeMarketing = buymarketingFee;
        buyFeeLiquidity = buyliquidityFee;
        buyFeeBurn = buyburnFee;
        buyFeeTreasury = buytreasuryFee;

        emit BuyFeesUpdated(buyteamFee, buymarketingFee, buyliquidityFee, buyburnFee, buytreasuryFee);
    }

    function setSellFees(uint256 sellteamFee, uint256 sellmarketingFee, uint256 sellliquidityFee, uint256 sellburnFee, uint256 selltreasuryFee) external onlyOwner {
        require(sellteamFee <= MAX_FEE, "Exceeds maximum team fee");
        require(sellmarketingFee <= MAX_FEE, "Exceeds maximum marketing fee");
        require(sellliquidityFee <= MAX_FEE, "Exceeds maximum liquidity fee");
        require(sellburnFee <= MAX_FEE, "Exceeds maximum burn fee");
        require(selltreasuryFee <= MAX_FEE, "Exceeds maximum treasury fee");

        sellFeeTeam = sellteamFee;
        sellFeeMarketing = sellmarketingFee;
        sellFeeLiquidity = sellliquidityFee;
        sellFeeBurn = sellburnFee;
        sellFeeTreasury = selltreasuryFee;

        emit SellFeesUpdated(sellteamFee, sellmarketingFee, sellliquidityFee, sellburnFee, selltreasuryFee);
    }

    function addFeeExemptAddress(address account) external onlyOwner {
        _feeExemptAddresses[account] = true;
    }

    function removeFeeExemptAddress(address account) external onlyOwner {
        _feeExemptAddresses[account] = false;
    }

    function setLP(address _address) external onlyOwner {
        pairContract = IPancakeSwapPair(_address);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        bool isBuy = (sender == liquidityPool || sender == BURN_ADRESS);
        bool isSell = (recipient == liquidityPool);

        if (isBuy) {
            // Apply buy fees
            uint256 transferAmount = amount;
            require(transferAmount > 0, "Amount after fee must be greater than zero");

            if (!_feeExemptAddresses[sender]) {
                // Apply fees for non-fee-exempt addresses
                transferAmount = amount - (amount * (buyFeeTeam + buyFeeMarketing + buyFeeLiquidity + buyFeeBurn + buyFeeTreasury)) / 10000;
                super._transfer(sender, teamWallet, amount * buyFeeTeam / 10000);
                super._transfer(sender, marketingWallet, amount * buyFeeMarketing / 10000);
                super._transfer(sender, liquidityPool, amount * buyFeeLiquidity / 10000);
                super._transfer(sender, BURN_ADRESS, amount * buyFeeBurn / 10000);
                super._transfer(sender, treasuryWallet, amount * buyFeeTreasury / 10000);
            }

            super._transfer(sender, recipient, transferAmount);
        } else if (isSell) {
            // Apply sell fees
            uint256 transferAmount = amount;
            require(transferAmount > 0, "Amount after fee must be greater than zero");

            if (!_feeExemptAddresses[sender]) {
                // Apply fees for non-fee-exempt addresses
                transferAmount = amount - (amount * (sellFeeTeam + sellFeeMarketing + sellFeeLiquidity + sellFeeBurn + sellFeeTreasury)) / 10000;
                super._transfer(sender, teamWallet, amount * sellFeeTeam / 10000);
                super._transfer(sender, marketingWallet, amount * sellFeeMarketing / 10000);
                super._transfer(sender, liquidityPool, amount * sellFeeLiquidity / 10000);
                super._transfer(sender, BURN_ADRESS, amount * sellFeeBurn / 10000);
                super._transfer(sender, treasuryWallet, amount * sellFeeTreasury / 10000);
            }

            super._transfer(sender, recipient, transferAmount);
        } else {
            // No fees applied
            super._transfer(sender, recipient, amount);
        }
    }
}