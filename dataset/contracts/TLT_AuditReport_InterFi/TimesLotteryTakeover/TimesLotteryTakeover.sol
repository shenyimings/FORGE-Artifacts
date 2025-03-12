// SPDX-License-Identifier: MIT                                                                               
                                                    
pragma solidity 0.8.9;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

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
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

    }

    function _createInitialSupply(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

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

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
    function renounceOwnership() external virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IUniswapV2Router02  {
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

contract TimesLotteryTakeover is ERC20, Ownable {

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    address public constant deadAddress = address(0xdead);

    bool private swapping;

    address public marketingAddress;
    address public devAddress;
    address public lotteryAddress1;
    address public lotteryAddress2;
    address public lotteryAddress3;
    address public buybackAddress;
    address public rewardsAddress;
    address public charityAddress;
    
    uint256 public maxTransactionAmount;
    uint256 public swapTokensAtAmount;

    bool public limitsInEffect = true;
    bool public tradingActive = false;
    bool public swapEnabled = false;
    
    bool private gasLimitActive = true;
    uint256 private constant gasPriceLimit = 70 * 1 gwei; // do not allow over x gwei for launch
    
     // Anti-bot and anti-whale mappings and variables
    mapping(address => uint256) private _holderLastTransferTimestamp; // to hold last Transfers temporarily during launch
    bool public transferDelayEnabled = true;

    uint256 public buyTotalFees;
    uint256 public buyMarketingFee;
    uint256 public buyLiquidityFee;
    uint256 public buyBuyBackFee;
    uint256 public buyDevFee;
    uint256 public buyLottery1Fee;
    uint256 public buyLottery2Fee;
    uint256 public buyLottery3Fee;
    uint256 public buyRewardsFee;
    uint256 public buyCharityFee;
    
    uint256 public sellTotalFees;
    uint256 public sellMarketingFee;
    uint256 public sellLiquidityFee;
    uint256 public sellBuyBackFee;
    uint256 public sellDevFee;
    uint256 public sellLottery1Fee;
    uint256 public sellLottery2Fee;
    uint256 public sellLottery3Fee;
    uint256 public sellRewardsFee;
    uint256 public sellCharityFee;
    
    uint256 public tokensForMarketing;
    uint256 public tokensForLiquidity;
    uint256 public tokensForBuyBack;
    uint256 public tokensForDev;
    uint256 public tokensForLottery1;
    uint256 public tokensForLottery2;
    uint256 public tokensForLottery3;
    uint256 public tokensForRewards;
    uint256 public tokensForCharity;
    
    bool public happyHourEnabled = false;

    // exclude from fees and max transaction amount
    mapping (address => bool) private _isExcludedFromFees;
    mapping (address => bool) public _isExcludedMaxTransactionAmount;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping (address => bool) public automatedMarketMakerPairs;

    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event marketingAddressUpdated(address indexed newWallet, address indexed oldWallet);
    
    event devAddressUpdated(address indexed newWallet, address indexed oldWallet);

    event buyBackAddressUpdated(address indexed newWallet, address indexed oldWallet);

    event rewardsAddressUpdated(address indexed newWallet, address indexed oldWallet);

    event LotteryAddressUpdated(address indexed newWallet, address indexed oldWallet);

    event charityAddressUpdated(address indexed newWallet, address indexed oldWallet);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );

    event HappyHour(bool enabled);

    constructor() ERC20("Times Lottery Takeover", "TLT") {
        address newOwner = 0x9E399ff1aD18F41CcdD4d0eF1e9edBED60617AB4;
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        
        excludeFromMaxTransaction(address(_uniswapV2Router), true);
        uniswapV2Router = _uniswapV2Router;
        
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        excludeFromMaxTransaction(address(uniswapV2Pair), true);
        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        uint256 totalSupply = 1 * 1e12 * 1e18;
        
        maxTransactionAmount = totalSupply * 5 / 1000; // 0.5% maxTransactionAmountTxn
        swapTokensAtAmount = totalSupply * 5 / 10000; // 0.05% swap wallet

        buyMarketingFee = 2;
        buyLiquidityFee = 2;
        buyBuyBackFee = 2;
        buyDevFee = 2;
        buyLottery1Fee = 3;
        buyLottery2Fee = 2;
        buyLottery3Fee = 1;
        buyRewardsFee = 3;
        buyCharityFee = 1;
        buyTotalFees = buyMarketingFee + buyLiquidityFee + buyBuyBackFee + buyDevFee + buyLottery1Fee + buyLottery2Fee + buyLottery3Fee + buyRewardsFee + buyCharityFee;
        
        sellMarketingFee = 2;
        sellLiquidityFee = 2;
        sellBuyBackFee = 2;
        sellDevFee = 2;
        sellLottery1Fee = 3;
        sellLottery2Fee = 2;
        sellLottery3Fee = 1;
        sellRewardsFee = 3;
        sellCharityFee = 1;
        sellTotalFees = sellMarketingFee + sellLiquidityFee + sellBuyBackFee + sellDevFee + sellLottery1Fee + sellLottery2Fee + sellLottery3Fee + sellRewardsFee + sellCharityFee;
        
    	marketingAddress = address(0x3772B415B30C87AfEA05d74Fc1A01D944BAe41e4); // set as marketing wallet
    	devAddress = address(0x04493D0D46B856af9C173F25Bb62aFD85afF9487); // set as dev wallet
        lotteryAddress1 = 0x9fcf2a7686C74cbDB6Dc42E18Ab0fbC5101C177B;
        lotteryAddress2 = 0x49cC60626B2929F3c8bb3aFF915aa9Bb801029B4;
        lotteryAddress3 = 0x4Da235c06B4E4A0b9185aae8Ba06037021210db6;
        buybackAddress = 0x7cc0Df4805B7C2e46D54D743C5D8F5E4eE1c4d0b;
        rewardsAddress = 0x6eb3d0D5818E38c19657f0622E25D9e444AF55Db;
        charityAddress = 0x8c2dc0858778B05f2787c9F0c3556b4174aeE0b5;

        // exclude from paying fees or having max transaction amount
        excludeFromFees(newOwner, true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);
        
        excludeFromMaxTransaction(newOwner, true);
        excludeFromMaxTransaction(address(this), true);
        excludeFromMaxTransaction(address(0xdead), true);
        
        /*
            _createInitialSupply is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _createInitialSupply(newOwner, totalSupply);
        transferOwnership(newOwner);
    }

    receive() external payable {
  	}

    // once enabled, can never be turned off
    function enableTrading() external onlyOwner {
        tradingActive = true;
        swapEnabled = true;
    }
    
    // remove limits after token is stable
    function removeLimits() external onlyOwner returns (bool){
        limitsInEffect = false;
        gasLimitActive = false;
        transferDelayEnabled = false;
        return true;
    }
    
    // disable Transfer delay - cannot be reenabled
    function disableTransferDelay() external onlyOwner returns (bool){
        transferDelayEnabled = false;
        return true;
    }
    
    function airdropToWallets(address[] memory airdropWallets, uint256[] memory amounts) external onlyOwner returns (bool){
        require(!tradingActive, "Trading is already active, cannot airdrop after launch.");
        require(airdropWallets.length == amounts.length, "arrays must be the same length");
        require(airdropWallets.length < 200, "Can only airdrop 200 wallets per txn due to gas limits"); // allows for airdrop + launch at the same exact time, reducing delays and reducing sniper input.
        for(uint256 i = 0; i < airdropWallets.length; i++){
            address wallet = airdropWallets[i];
            uint256 amount = amounts[i];
            _transfer(msg.sender, wallet, amount);
        }
        return true;
    }
    
     // change the minimum amount of tokens to sell from fees
    function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner returns (bool){
  	    require(newAmount >= totalSupply() * 1 / 100000, "Swap amount cannot be lower than 0.001% total supply.");
  	    require(newAmount <= totalSupply() * 5 / 1000, "Swap amount cannot be higher than 0.5% total supply.");
  	    swapTokensAtAmount = newAmount;
  	    return true;
  	}
    
    function updateMaxAmount(uint256 newNum) external onlyOwner {
        require(newNum >= (totalSupply() * 5 / 1000)/1e18, "Cannot set maxTransactionAmount lower than 0.5%");
        maxTransactionAmount = newNum * (10**18);
    }
    
    function excludeFromMaxTransaction(address updAds, bool isEx) public onlyOwner {
        _isExcludedMaxTransactionAmount[updAds] = isEx;
    }
    
    // only use to disable contract sales if absolutely necessary (emergency use only)
    function updateSwapEnabled(bool enabled) external onlyOwner(){
        swapEnabled = enabled;
    }
    
    function updateBuyFees(uint256 _marketingFee, uint256 _liquidityFee, uint256 _buyBackFee, uint256 _devFee, uint256 _rewardsFee, uint256 _charityFee, uint256 _lottery1Fee, uint256 _lottery2Fee, uint256 _lottery3Fee) external onlyOwner {
        buyMarketingFee = _marketingFee;
        buyLiquidityFee = _liquidityFee;
        buyBuyBackFee = _buyBackFee;
        buyDevFee = _devFee;
        buyRewardsFee = _rewardsFee;
        buyCharityFee = _charityFee;
        buyLottery1Fee = _lottery1Fee;
        buyLottery2Fee = _lottery2Fee;
        buyLottery3Fee = _lottery3Fee;
        buyTotalFees = buyMarketingFee + buyLiquidityFee + buyBuyBackFee + buyDevFee + buyRewardsFee + buyCharityFee + buyLottery1Fee + buyLottery2Fee + buyLottery3Fee;
        require(buyTotalFees <= 25, "Must keep fees at 25% or less");
    }
    
    function updateSellFees(uint256 _marketingFee, uint256 _liquidityFee, uint256 _buyBackFee, uint256 _devFee, uint256 _rewardsFee, uint256 _charityFee, uint256 _lottery1Fee, uint256 _lottery2Fee, uint256 _lottery3Fee) external onlyOwner {
        sellMarketingFee = _marketingFee;
        sellLiquidityFee = _liquidityFee;
        sellBuyBackFee = _buyBackFee;
        sellDevFee = _devFee;
        sellRewardsFee = _rewardsFee;
        sellCharityFee = _charityFee;
        sellLottery1Fee = _lottery1Fee;
        sellLottery2Fee = _lottery2Fee;
        sellLottery3Fee = _lottery3Fee;
        sellTotalFees = sellMarketingFee + sellLiquidityFee + sellBuyBackFee + sellDevFee + sellRewardsFee + sellCharityFee + sellLottery1Fee + sellLottery2Fee + sellLottery3Fee;
        require(sellTotalFees <= 35, "Must keep fees at 35% or less");
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
        require(pair != uniswapV2Pair, "The pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateMarketingWallet(address newMarketingWallet) external onlyOwner {
        emit marketingAddressUpdated(newMarketingWallet, marketingAddress);
        marketingAddress = newMarketingWallet;
    }
    
    function updateDevWallet(address newWallet) external onlyOwner {
        emit devAddressUpdated(newWallet, devAddress);
        devAddress = newWallet;
    }

    function updateCharityWallet(address newWallet) external onlyOwner {
        emit charityAddressUpdated(newWallet, charityAddress);
        charityAddress = newWallet;
    }

    function updateBuyBackWallet(address newWallet) external onlyOwner {
        emit buyBackAddressUpdated(newWallet, buybackAddress);
        buybackAddress = newWallet;
    }

    function updateRewardWallet(address newWallet) external onlyOwner {
        emit rewardsAddressUpdated(newWallet, rewardsAddress);
        rewardsAddress = newWallet;
    }

    function updateLottery1Wallet(address newWallet) external onlyOwner {
        emit LotteryAddressUpdated(newWallet, lotteryAddress1);
        lotteryAddress1 = newWallet;
    }

    function updateLottery2Wallet(address newWallet) external onlyOwner {
        emit LotteryAddressUpdated(newWallet, lotteryAddress2);
        lotteryAddress2 = newWallet;
    }

    function updateLottery3Wallet(address newWallet) external onlyOwner {
        emit LotteryAddressUpdated(newWallet, lotteryAddress3);
        lotteryAddress3 = newWallet;
    }

    function isExcludedFromFees(address account) external view returns(bool) {
        return _isExcludedFromFees[account];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        
         if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if(!tradingActive){
            require(_isExcludedFromFees[from] || _isExcludedFromFees[to], "Trading is not active.");
        }
        
        if(limitsInEffect){
            if (
                from != owner() &&
                to != owner() &&
                to != address(0) &&
                to != address(0xdead) &&
                !swapping
            ){

                // only use to prevent sniper buys in the first blocks.
                if (gasLimitActive && automatedMarketMakerPairs[from]) {
                    require(tx.gasprice <= gasPriceLimit, "Gas price exceeds limit.");
                }

                // at launch if the transfer delay is enabled, ensure the block timestamps for purchasers is set -- during launch.  
                if (transferDelayEnabled){
                    if (to != address(uniswapV2Router) && to != address(uniswapV2Pair)){
                        require(_holderLastTransferTimestamp[tx.origin] < block.number, "_transfer:: Transfer Delay enabled.  Only one purchase per block allowed.");
                        _holderLastTransferTimestamp[tx.origin] = block.number;
                    }
                }
                 
                //when buy
                if (automatedMarketMakerPairs[from] && !_isExcludedMaxTransactionAmount[to]) {
                        require(amount <= maxTransactionAmount, "Buy transfer amount exceeds the maxTransactionAmount.");
                }
                
                //when sell
                else if (automatedMarketMakerPairs[to] && !_isExcludedMaxTransactionAmount[from]) {
                        require(amount <= maxTransactionAmount, "Sell transfer amount exceeds the maxTransactionAmount.");
                }
            }
        }
        
		uint256 contractTokenBalance = balanceOf(address(this));
        
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if( 
            canSwap &&
            swapEnabled &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            !_isExcludedFromFees[from] &&
            !_isExcludedFromFees[to]
        ) {
            swapping = true;
            
            swapBack();

            swapping = false;
        }
        
        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }
        
        uint256 fees = 0;
        // only take fees on buys/sells, do not take on wallet transfers
        if(takeFee){
            // on sell
            if (automatedMarketMakerPairs[to] && sellTotalFees > 0){
                fees = amount * sellTotalFees /100;
                tokensForLiquidity += fees * sellLiquidityFee / sellTotalFees;
                tokensForBuyBack += fees * sellBuyBackFee / sellTotalFees;
                tokensForDev += fees * sellDevFee / sellTotalFees;
                tokensForMarketing += fees * sellMarketingFee / sellTotalFees;
                tokensForLottery1 += fees * sellLottery1Fee / sellTotalFees;
                tokensForLottery2 += fees * sellLottery2Fee / sellTotalFees;
                tokensForLottery3 += fees * sellLottery3Fee / sellTotalFees;
                tokensForRewards += fees * sellRewardsFee / sellTotalFees;
                tokensForCharity += fees * sellCharityFee / sellTotalFees;
            }
            // on buy
            else if(automatedMarketMakerPairs[from] && buyTotalFees > 0) {
        	    fees = amount * buyTotalFees / 100;
        	    tokensForLiquidity += fees * buyLiquidityFee / buyTotalFees;
                tokensForBuyBack += fees * buyBuyBackFee / buyTotalFees;
                tokensForDev += fees * buyDevFee / buyTotalFees;
                tokensForMarketing += fees * buyMarketingFee / buyTotalFees;
                tokensForLottery1 += fees * buyLottery1Fee / buyTotalFees;
                tokensForLottery2 += fees * buyLottery2Fee / buyTotalFees;
                tokensForLottery3 += fees * buyLottery3Fee / buyTotalFees;
                tokensForRewards += fees * buyRewardsFee / buyTotalFees;
                tokensForCharity += fees * buyCharityFee / buyTotalFees;
            }
            
            if(fees > 0){    
                super._transfer(from, address(this), fees);
            }
        	
        	amount -= fees;
        }

        super._transfer(from, to, amount);
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
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            deadAddress,
            block.timestamp
        );
    }

    function swapBack() private {
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap = tokensForLiquidity + tokensForMarketing + tokensForBuyBack + tokensForDev + 
            tokensForCharity + tokensForRewards + tokensForLottery1 + tokensForLottery2 + tokensForLottery3;
        
        if(contractBalance == 0 || totalTokensToSwap == 0) {return;}

        bool success;
        
        // Halve the amount of liquidity tokens
        uint256 liquidityTokens = contractBalance * tokensForLiquidity / totalTokensToSwap / 2;
        
        swapTokensForEth(contractBalance - liquidityTokens); 
        
        uint256 ethBalance = address(this).balance;
        uint256 ethForLiquidity = ethBalance;

        uint256 ethForMarketing = ethBalance * tokensForMarketing / totalTokensToSwap;
        uint256 ethForDev = ethBalance * tokensForDev / totalTokensToSwap;
        uint256 ethForBuyBack = ethBalance * tokensForBuyBack / totalTokensToSwap;
        uint256 ethForCharity = ethBalance * tokensForCharity / totalTokensToSwap;
        uint256 ethForRewards = ethBalance * tokensForRewards / totalTokensToSwap;

        ethForLiquidity -= ethForMarketing + ethForDev + ethForBuyBack + ethForCharity + ethForRewards;

        uint256 ethForLottery = ethBalance * tokensForLottery1 / totalTokensToSwap;
        (success,) = address(lotteryAddress1).call{value: ethForLottery}("");
        ethForLiquidity -= ethForLottery;

        ethForLottery = ethBalance * tokensForLottery2 / totalTokensToSwap;
        (success,) = address(lotteryAddress2).call{value: ethForLottery}("");
        ethForLiquidity -= ethForLottery;
        
        ethForLottery = ethBalance * tokensForLottery3 / totalTokensToSwap;
        (success,) = address(lotteryAddress3).call{value: ethForLottery}("");
        ethForLiquidity -= ethForLottery;
            
        tokensForLiquidity = 0;
        tokensForMarketing = 0;
        tokensForBuyBack = 0;
        tokensForDev = 0;
        tokensForCharity = 0;
        tokensForRewards = 0;
        tokensForLottery1 = 0;
        tokensForLottery2 = 0;
        tokensForLottery3 = 0;
        
        (success,) = address(devAddress).call{value: ethForDev}("");
        (success,) = address(buybackAddress).call{value: ethForBuyBack}("");
        (success,) = address(charityAddress).call{value: ethForCharity}("");
        (success,) = address(rewardsAddress).call{value: ethForRewards}("");
        
        if(liquidityTokens > 0 && ethForLiquidity > 0){
            addLiquidity(liquidityTokens, ethForLiquidity);
        }

        (success,) = address(marketingAddress).call{value: address(this).balance}("");
    }

    function happyHourToggle(bool enable) external onlyOwner {
        
        require(happyHourEnabled != enable, "Already set to this setting.");
        
        // uses hardcoded values to set happy hour on or off
        
        if(enable){
            happyHourEnabled = true;
            buyMarketingFee = 0;
            buyLiquidityFee = 2;
            buyBuyBackFee = 0;
            buyDevFee = 0;
            buyLottery1Fee = 3;
            buyLottery2Fee = 2;
            buyLottery3Fee = 1;
            buyRewardsFee = 0;
            buyCharityFee = 0;
            buyTotalFees = buyMarketingFee + buyLiquidityFee + buyBuyBackFee + buyDevFee + buyLottery1Fee + buyLottery2Fee + buyLottery3Fee + buyRewardsFee + buyCharityFee; 
        }
        // set back to normal taxes
        else if(!enable){
            happyHourEnabled = false;
            buyMarketingFee = 2;
            buyLiquidityFee = 2;
            buyBuyBackFee = 2;
            buyDevFee = 2;
            buyLottery1Fee = 3;
            buyLottery2Fee = 2;
            buyLottery3Fee = 1;
            buyRewardsFee = 3;
            buyCharityFee = 1;
            buyTotalFees = buyMarketingFee + buyLiquidityFee + buyBuyBackFee + buyDevFee + buyLottery1Fee + buyLottery2Fee + buyLottery3Fee + buyRewardsFee + buyCharityFee;     
        }
        
        emit HappyHour(enable);
    }
}