// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

interface BEP20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

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

interface IDEXFactory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IDEXRouter {
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

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;
}

contract Olefy is BEP20 {
    IDEXRouter public router =
        IDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    //token data
    string public constant name = "Olefy";
    string public constant symbol = "Olefy";
    uint8 public constant decimals = 18;
    uint256 public totalSupply = 100000000 * 10**decimals;
    //mappings
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) _allowances;
    mapping(address => bool) pairs;
    mapping(address => bool) public isFeeExempt;
    //uint256

    //BUY FEES
    uint256 public liquidityFee = 20; // 2% autoliquidify
    uint256 public marketingFee = 40; // 4% marketing
    uint256 public ExpansaoFee = 20; // 2% espansÃ£o
    uint256 public PionnerFee = 20; // 2% Pionner
    uint256 public totalBuyFee = 100;
    //SELL FEES
    uint256 public sellLiquidityFee = 20; // 2% autoliquidify
    uint256 public sellMarketingFee = 40; // 4% marketing
    uint256 public sellExpansaoFee = 20; // 2% Expansao
    uint256 public sellPionnerFee = 20; // 2% Pionner
    uint256 public totalSellFee = 100;

    uint256 public constant feeDenominator = 1000;
    uint256 transferMultiplier = 25;
    uint256 public swapThreshold = totalSupply / 50000;
    uint256 txbnbGas = 50000;
    uint256 LiquidifyGas = 500000;
    uint256 public launchedAt;
    //addresses
    address public marketingFeeReceiver;
    address public ExpansaoReceiver;
    address public PionnerReceiver;
    address private _owner;
    address public WBNB = router.WETH();
    //bools
    bool public tradingOpen = false;
    bool public burnEnabled = true;
    bool public swapEnabled = true;
    bool inSwap;
    //modifiers
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }
    modifier onlyOwner() {
        require(
            _owner == msg.sender,
            "Ownable: only owner can call this function"
        );
        _;
    }

    //constructor
    constructor() {
        _owner = msg.sender;
        address pair = IDEXFactory(router.factory()).createPair(
            WBNB,
            address(this)
        );

        marketingFeeReceiver = msg.sender;
        ExpansaoReceiver = msg.sender;
        PionnerReceiver = msg.sender;

        pairs[pair] = true;

        isFeeExempt[msg.sender] = true;
        isFeeExempt[address(this)] = true;

        _allowances[address(this)][address(router)] = totalSupply * 1000;

        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
        emit OwnershipTransferred(address(0), _owner);
    }

    //functions
    receive() external payable {}

    function owner() public view returns (address) {
        return _owner;
    }

    function allowance(address holder, address spender)
        external
        view
        returns (uint256)
    {
        return _allowances[holder][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount)
        external
        override
        returns (bool)
    {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        require(
            _allowances[sender][msg.sender] >= amount,
            "Insufficient Allowance"
        );
        _allowances[sender][msg.sender] =
            _allowances[sender][msg.sender] -
            amount;

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        require(balanceOf[sender] >= amount, "Insufficient Balance");
        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }

        if (isFeeExempt[sender] || isFeeExempt[recipient]) {
            return _basicTransfer(sender, recipient, amount);
        } else {
            require(tradingOpen, "Trading not open yet");
            if (shouldSwapBack()) {
                swapBack();
            }
        }

        balanceOf[sender] = balanceOf[sender] - amount;

        uint256 amountReceived = (isFeeExempt[sender] || isFeeExempt[recipient])
            ? amount
            : takeFee(sender, amount, recipient);

        balanceOf[recipient] = balanceOf[recipient] + amountReceived;

        emit Transfer(sender, recipient, amountReceived);
        return true;
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        require(balanceOf[sender] >= amount, "Insufficient Balance");
        balanceOf[sender] = balanceOf[sender] - amount;
        balanceOf[recipient] = balanceOf[recipient] + amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function _isSell(bool a) internal view returns (uint256) {
        return a ? totalSellFee : totalBuyFee;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(amount != 0);
        require(amount <= balanceOf[account]);
        balanceOf[account] = balanceOf[account] - amount;
        totalSupply = totalSupply - amount;
        emit Transfer(account, address(0), amount);
    }

    function famount(
        uint256 amount,
        uint256 fee,
        uint256 multi
    ) internal pure returns (uint256) {
        return ((amount * (fee)) * multi) / (feeDenominator * 100);
    }

    function takeFee(
        address sender,
        uint256 amount,
        address recipient
    ) internal returns (uint256) {
        uint256 totalFee = _isSell(pairs[recipient]);
        if (amount == 0 || totalFee == 0) {
            return amount;
        }

        uint256 multiplier = (pairs[recipient] || pairs[sender])
            ? 100
            : transferMultiplier;

        uint256 feeAmount = famount(amount, totalFee, multiplier);
        uint256 contractTokens = feeAmount;

        if (contractTokens > 0) {
            _txTransfer(sender, address(this), contractTokens);
        }

        return amount - feeAmount;
    }

    function _txTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        balanceOf[recipient] = balanceOf[recipient] + amount;
        emit Transfer(sender, recipient, amount);
    }

    function shouldSwapBack() internal view returns (bool) {
        return
            !pairs[msg.sender] &&
            !inSwap &&
            swapEnabled &&
            balanceOf[address(this)] >= swapThreshold;
    }

    // switch Trading
    function tradingEnable() external onlyOwner {
        require(!tradingOpen, "Trading already open"); //trade only can change one time
        tradingOpen = true;
        launchedAt = block.timestamp;
        emit config_TradingStatus(tradingOpen);
    }

    function swapBack() internal swapping {
        uint256 totalETHFee = totalSellFee;

        uint256 amountToLiquify = (swapThreshold * sellLiquidityFee) /
            (totalETHFee * 2);

        uint256 amountToSwap = swapThreshold - amountToLiquify;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WBNB;
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountBNB = address(this).balance;

        totalETHFee = totalETHFee - (sellLiquidityFee / 2);

        uint256 amountBNBLiquidity = (amountBNB * sellLiquidityFee) /
            (totalETHFee * 2);

        uint256 amountBNBMarketing = (amountBNB * sellMarketingFee) /
            totalETHFee;

        uint256 amountBNBExpansao = (amountBNB * sellExpansaoFee) / totalETHFee;

        uint256 amountBNBPionner = (amountBNB * sellPionnerFee) / totalETHFee;

        if (amountBNBMarketing > 0) {
            (bool success, ) = payable(marketingFeeReceiver).call{
                value: amountBNBMarketing,
                gas: txbnbGas
            }("");
        }
        if (amountBNBExpansao > 0) {
            (bool success, ) = payable(ExpansaoReceiver).call{
                value: amountBNBExpansao,
                gas: txbnbGas
            }("");
        }
        if (amountBNBPionner > 0) {
            (bool success, ) = payable(PionnerReceiver).call{
                value: amountBNBPionner,
                gas: txbnbGas
            }("");
        }
        if (amountToLiquify > 0) {
            router.addLiquidityETH{
                value: amountBNBLiquidity,
                gas: LiquidifyGas
            }(
                address(this),
                amountToLiquify,
                0,
                0,
                address(this),
                block.timestamp
            );
        }
    }

    function manualSend() external onlyOwner {
        payable(marketingFeeReceiver).transfer(address(this).balance);
        _basicTransfer(
            address(this),
            marketingFeeReceiver,
            balanceOf[address(this)]
        );
    }

    function setPair(address _pair, bool io) public onlyOwner {
        pairs[_pair] = io;
    }

    function manage_FeeExempt(address[] calldata addresses, bool status)
        external
        onlyOwner
    {
        require(
            addresses.length < 501,
            "GAS Error: max limit is 500 addresses"
        );
        for (uint256 i = 0; i < addresses.length; ++i) {
            isFeeExempt[addresses[i]] = status;
            emit Wallet_feeExempt(addresses[i], status);
        }
    }

    function setFees(
        uint256 _liquidityFee,
        uint256 _ExpansaoFee,
        uint256 _PionnerFee,
        uint256 _marketingFee,
        uint256 _sellLiquidityFee,
        uint256 _sellExpansaoFee,
        uint256 _sellPionnerFee,
        uint256 _sellMarketingFee
    ) external onlyOwner {
        liquidityFee = _liquidityFee;
        marketingFee = _marketingFee;
        ExpansaoFee = _ExpansaoFee;
        PionnerFee = _PionnerFee;

        totalBuyFee =
            _liquidityFee +
            _marketingFee +
            _ExpansaoFee +
            _PionnerFee;

        sellLiquidityFee = _sellLiquidityFee;
        sellExpansaoFee = _sellExpansaoFee;
        sellPionnerFee = _sellPionnerFee;
        sellMarketingFee = _sellMarketingFee;

        totalSellFee =
            _sellLiquidityFee +
            _sellExpansaoFee +
            _sellPionnerFee +
            _sellMarketingFee;

        require((totalBuyFee) <= 120, "Buy tax cannot be more than 12%");
        require((totalSellFee) <= 120, "Sell tax cannot be more than 12%");
        emit UpdateFee(uint8(totalBuyFee), uint8(totalSellFee));
    }

    function setSwapBackSettings(bool _enabled, uint256 _amount)
        external
        onlyOwner
    {
        require(_amount < (totalSupply / 10), "Amount too high");

        swapEnabled = _enabled;
        swapThreshold = _amount;

        emit config_SwapSettings(swapThreshold, swapEnabled);
    }

    function setmarketingFeeReceivers(address _marketingFeeReceiver)
        external
        onlyOwner
    {
        marketingFeeReceiver = _marketingFeeReceiver;
    }

    function setExpansaoReceiver(address _autoExpansaoReceiver)
        external
        onlyOwner
    {
        ExpansaoReceiver = _autoExpansaoReceiver;
    }

    function setPionnersReceiver(address _PionnersReceiver) external onlyOwner {
        PionnerReceiver = _PionnersReceiver;
    }

    function setTXBNBgas(uint256 gas) external onlyOwner {
        require(gas < 100000);
        txbnbGas = gas;
    }

    function setLiquidifyGas(uint256 gas) external onlyOwner {
        require(gas < 1000000);
        LiquidifyGas = gas;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    event AutoLiquify(uint256 amountBNB, uint256 amountTokens);
    event UpdateFee(uint8 Buy, uint8 Sell);
    event Wallet_feeExempt(address Wallet, bool Status);
    event clearToken(address TokenAddressCleared, uint256 Amount);
    event Set_Wallets(address MarketingWallet, address BuyBackWallet);
    event config_TradingStatus(bool Status);
    event config_SwapSettings(uint256 Amount, bool Enabled);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
}