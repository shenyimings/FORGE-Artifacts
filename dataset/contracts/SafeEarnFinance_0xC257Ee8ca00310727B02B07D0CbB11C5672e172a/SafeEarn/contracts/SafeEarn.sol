//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./DividendDistributor.sol";
import "./IPinkAntiBot.sol";

contract SafeEarn is IERC20, Ownable {
    using SafeMath for uint256;

    address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;

    address public REWARD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    string constant _name = "SafeEarn";
    string constant _symbol = "EARN";
    uint8 constant _decimals = 9;

    uint256 _totalSupply = 100000000000 * (10**_decimals);

    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _allowances;

    mapping(address => bool) isFeeExempt;
    mapping(address => bool) isDividendExempt;
    // allowed users to do transactions before trading enable
    mapping(address => bool) isAuthorized;
    mapping(address => bool) isMaxSellExempt;

    // buy fees
    uint256 public buyRewardFee = 10;
    uint256 public buyMarketingFee = 2;
    uint256 public buyLiquidityFee = 1;
    uint256 public buyBuyBackFee = 1;
    uint256 public buyStakePoolFee = 2;
    uint256 public buyTotalFees = 16;
    // sell fees
    uint256 public sellRewardFee = 10;
    uint256 public sellMarketingFee = 2;
    uint256 public sellLiquidityFee = 1;
    uint256 public sellBuyBackFee = 1;
    uint256 public sellStakePoolFee = 2;
    uint256 public sellTotalFees = 16;

    address public marketingFeeReceiver;
    address public buyBackFeeReceiver;
    address public autoLPReceiver;
    address public stakePoolAddress;

    // swap percentage
    uint256 public rewardSwap = 4;
    uint256 public marketingSwap = 3;
    uint256 public liquiditySwap = 1;
    uint256 public buyBackSwap = 4;
    uint256 public totalSwap = 12;

    IUniswapV2Router02 public router;
    address public pair;

    bool public tradingOpen = false;

    DividendDistributor public dividendTracker;
    IPinkAntiBot public pinkAntiBot;

    address public pinkAntiBot_ = 0x8EFDb3b642eb2a20607ffe0A56CFefF6a95Df002;
    bool public antiBotEnabled = true;

    address private newOwner = 0x05B7DCA28D2f97F09B9bfF370d38a5D1864892B9;

    uint256 distributorGas = 500000;

    event AutoLiquify(uint256 amountBNB, uint256 amountBOG);
    event ChangeRewardTracker(address token);
    event IncludeInReward(address holder);

    bool public swapEnabled = true;
    uint256 public swapThreshold = (_totalSupply * 10) / 10000; // 0.01% of supply
    uint256 public maxSellLimit = (_totalSupply * 1000) / 10000; // 0.5% of supply

    bool inSwap;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() {
        router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pair = IUniswapV2Factory(router.factory()).createPair(
            WBNB,
            address(this)
        );
        _allowances[address(this)][address(router)] = type(uint256).max;

        dividendTracker = new DividendDistributor(address(router), REWARD);

        isFeeExempt[newOwner] = true;

        isDividendExempt[pair] = true;
        isDividendExempt[address(this)] = true;
        isDividendExempt[DEAD] = true;

        isAuthorized[newOwner] = true;

        isMaxSellExempt[newOwner] = true;
        isMaxSellExempt[pair] = true;
        isMaxSellExempt[address(this)] = true;

        pinkAntiBot = IPinkAntiBot(pinkAntiBot_);
        pinkAntiBot.setTokenOwner(newOwner);

        marketingFeeReceiver = 0x246Ec71297f554e3225989Bd39Ce7cCc7B3c3716;
        stakePoolAddress = 0x097ac30d037B592d325566e6De75f1c45C798EFF;
        autoLPReceiver = 0x05B7DCA28D2f97F09B9bfF370d38a5D1864892B9;
        buyBackFeeReceiver = 0xd449f40bA1c9134F8829953eEF691B35375cF216;

        _balances[newOwner] = _totalSupply;
        emit Transfer(address(0), newOwner, _totalSupply);
    }

    receive() external payable {}

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
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

    function circulatingSupply() public view returns (uint256) {
        return _totalSupply.sub(_balances[DEAD]);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    // tracker dashboard functions
    function getHolderDetails(address holder)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return dividendTracker.getHolderDetails(holder);
    }

    function getLastProcessedIndex() public view returns (uint256) {
        return dividendTracker.getLastProcessedIndex();
    }

    function getNumberOfTokenHolders() public view returns (uint256) {
        return dividendTracker.getNumberOfTokenHolders();
    }

    function totalDistributedRewards() public view returns (uint256) {
        return dividendTracker.totalDistributedRewards();
    }

    function allowance(address holder, address spender)
        external
        view
        override
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

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
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
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender]
                .sub(amount, "Insufficient Allowance");
        }

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }
        if (antiBotEnabled) {
            pinkAntiBot.onPreTransferCheck(sender, recipient, amount);
        }
        if (!isAuthorized[sender]) {
            require(tradingOpen, "Trading not open yet");
        }

        if (!isMaxSellExempt[sender] && recipient == pair) {
            require(amount <= maxSellLimit, "Max Sell Amount exceed");
        }
        if (shouldSwapBack()) {
            swapBackInBnb();
        }

        //Exchange tokens
        _balances[sender] = _balances[sender].sub(
            amount,
            "Insufficient Balance"
        );

        uint256 amountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, amount, recipient)
            : amount;
        _balances[recipient] = _balances[recipient].add(amountReceived);

        // Dividend tracker
        if (!isDividendExempt[sender]) {
            try dividendTracker.setShare(sender, _balances[sender]) {} catch {}
        }

        if (!isDividendExempt[recipient]) {
            try
                dividendTracker.setShare(recipient, _balances[recipient])
            {} catch {}
        }

        try dividendTracker.process(distributorGas) {} catch {}

        emit Transfer(sender, recipient, amountReceived);
        return true;
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(
            amount,
            "Insufficient Balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function shouldTakeFee(address sender, address to)
        internal
        view
        returns (bool)
    {
        if (isFeeExempt[sender] || isFeeExempt[to]) {
            return false;
        } else {
            return true;
        }
    }

    function takeFee(
        address sender,
        uint256 amount,
        address to
    ) internal returns (uint256) {
        uint256 feeAmount = 0;
        uint256 stakePoolToken = 0;
        if (to == pair) {
            feeAmount = amount.mul(sellTotalFees).div(100);
            if (sellStakePoolFee > 0) {
                stakePoolToken = feeAmount.mul(sellStakePoolFee).div(
                    sellTotalFees
                );
                _balances[stakePoolAddress] = _balances[stakePoolAddress].add(
                    stakePoolToken
                );
                emit Transfer(sender, stakePoolAddress, stakePoolToken);
            }
        } else {
            feeAmount = amount.mul(buyTotalFees).div(100);
            if (buyStakePoolFee > 0) {
                stakePoolToken = feeAmount.mul(buyStakePoolFee).div(
                    buyTotalFees
                );
                _balances[stakePoolAddress] = _balances[stakePoolAddress].add(
                    stakePoolToken
                );
                emit Transfer(sender, stakePoolAddress, stakePoolToken);
            }
        }
        uint256 tokensToContract = feeAmount.sub(stakePoolToken);

        _balances[address(this)] = _balances[address(this)].add(
            tokensToContract
        );
        emit Transfer(sender, address(this), tokensToContract);

        return amount.sub(feeAmount);
    }

    function shouldSwapBack() internal view returns (bool) {
        return
            msg.sender != pair &&
            !inSwap &&
            swapEnabled &&
            tradingOpen &&
            _balances[address(this)] >= swapThreshold;
    }

    function clearStuckBalance(uint256 amountPercentage) external onlyOwner {
        uint256 amountBNB = address(this).balance;
        payable(msg.sender).transfer((amountBNB * amountPercentage) / 100);
    }

    function updateBuyFees(
        uint256 reward,
        uint256 marketing,
        uint256 liquidity,
        uint256 staking,
        uint256 buyBack
    ) public onlyOwner {
        buyRewardFee = reward;
        buyMarketingFee = marketing;
        buyLiquidityFee = liquidity;
        buyStakePoolFee = staking;
        buyBuyBackFee = buyBack;
        buyTotalFees = reward.add(marketing).add(liquidity).add(buyBack).add(
            staking
        );

        require(buyTotalFees <= 20, "Fees should be less than 20%");
    }

    function updateSellFees(
        uint256 reward,
        uint256 marketing,
        uint256 liquidity,
        uint256 staking,
        uint256 buyBack
    ) public onlyOwner {
        sellRewardFee = reward;
        sellMarketingFee = marketing;
        sellLiquidityFee = liquidity;
        sellStakePoolFee = staking;
        sellBuyBackFee = buyBack;

        sellTotalFees = reward.add(marketing).add(liquidity).add(buyBack).add(
            staking
        );
        require(sellTotalFees <= 20, "Fees should be less than 20%");
    }

    // update swap percentages
    function updateSwapPercentages(
        uint256 reward,
        uint256 marketing,
        uint256 liquidity
    ) public onlyOwner {
        rewardSwap = reward;
        marketingSwap = marketing;
        liquiditySwap = liquidity;
        totalSwap = reward.add(marketing).add(liquidity);
    }

    // switch Trading
    function enableTrading() public onlyOwner {
        tradingOpen = true;
    }

    function setEnableAntiBot(bool _enable) external onlyOwner {
        antiBotEnabled = _enable;
    }

    function whitelistPreSale(address _preSale) public onlyOwner {
        isFeeExempt[_preSale] = true;
        isDividendExempt[_preSale] = true;
        isAuthorized[_preSale] = true;
    }

    // manual claim for the greedy humans
    function ___claimRewards(bool tryAll) public {
        dividendTracker.claimDividend();
        if (tryAll) {
            try dividendTracker.process(distributorGas) {} catch {}
        }
    }

    // manually clear the queue
    function claimProcess() public {
        try dividendTracker.process(distributorGas) {} catch {}
    }

    function isRewardExclude(address _wallet) public view returns (bool) {
        return isDividendExempt[_wallet];
    }

    function isFeeExclude(address _wallet) public view returns (bool) {
        return isFeeExempt[_wallet];
    }

    function checkMaxSellExempt(address _wallet) public view returns (bool) {
        return isMaxSellExempt[_wallet];
    }

    function swapBackInBnb() internal swapping {
        uint256 contractTokenBalance = _balances[address(this)];
        uint256 tokensToLiquidity = contractTokenBalance.mul(liquiditySwap).div(
            totalSwap
        );
        uint256 tokensToSwap = contractTokenBalance.sub(tokensToLiquidity);
        uint256 tokensSwapFee = totalSwap.sub(liquiditySwap);
        swapTokensForTokens(tokensToSwap, REWARD);
        uint256 swappedTokensAmount = IERC20(REWARD).balanceOf(address(this));

        uint256 tokensToReward = swappedTokensAmount.mul(rewardSwap).div(
            tokensSwapFee
        );
        uint256 tokensToMarketing = swappedTokensAmount.mul(marketingSwap).div(
            tokensSwapFee
        );
        uint256 tokensToBuyBack = swappedTokensAmount.sub(tokensToReward).sub(
            tokensToMarketing
        );
        if (tokensToReward > 0) {
            // send token to reward
            IERC20(REWARD).transfer(address(dividendTracker), tokensToReward);
            try dividendTracker.deposit(tokensToReward) {} catch {}
        }
        if (tokensToMarketing > 0) {
            try
                IERC20(REWARD).transfer(marketingFeeReceiver, tokensToMarketing)
            {} catch {}
        }
        if (tokensToBuyBack > 0) {
            try
                IERC20(REWARD).transfer(buyBackFeeReceiver, tokensToBuyBack)
            {} catch {}
        }
        if (tokensToLiquidity > 0) {
            // add liquidity
            swapAndLiquify(tokensToLiquidity);
        }
    }

    function swapAndLiquify(uint256 tokens) private {
        // split the contract balance into halves
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

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

        emit AutoLiquify(newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        _approve(address(this), address(router), tokenAmount);
        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function swapTokensForTokens(uint256 tokenAmount, address tokenToSwap)
        private
    {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = router.WETH();
        path[2] = tokenToSwap;
        _approve(address(this), address(router), tokenAmount);
        // make the swap
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of tokens
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        _approve(address(this), address(router), tokenAmount);

        // add the liquidity
        router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            autoLPReceiver,
            block.timestamp
        );
    }

    function setIsDividendExempt(address holder, bool exempt)
        external
        onlyOwner
    {
        require(holder != address(this) && holder != pair);
        isDividendExempt[holder] = exempt;
        if (exempt) {
            dividendTracker.setShare(holder, 0);
        } else {
            dividendTracker.setShare(holder, _balances[holder]);
        }
    }

    function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
        isFeeExempt[holder] = exempt;
    }

    function addAuthorizedWallets(address holder, bool exempt)
        external
        onlyOwner
    {
        isAuthorized[holder] = exempt;
    }

    function setMarketingWallet(address _marketingFeeReceiver)
        external
        onlyOwner
    {
        marketingFeeReceiver = _marketingFeeReceiver;
    }

    function setBuyBackWallet(address _wallet) external onlyOwner {
        buyBackFeeReceiver = _wallet;
    }

    function setLpReceiver(address _wallet) external onlyOwner {
        autoLPReceiver = _wallet;
    }

    function setStakePoolAddress(address _stakePool) external onlyOwner {
        stakePoolAddress = _stakePool;
    }

    function setMaxSellLimit(uint256 amount) external onlyOwner {
        require(amount >= 100000000, "Amount should be greater than 0.1%");
        maxSellLimit = amount * (10**9);
    }

    function setSwapBackSettings(bool _enabled, uint256 _amount)
        external
        onlyOwner
    {
        swapEnabled = _enabled;
        swapThreshold = _amount;
    }

    function setDistributionCriteria(
        uint256 _minPeriod,
        uint256 _minDistribution
    ) external onlyOwner {
        dividendTracker.setDistributionCriteria(_minPeriod, _minDistribution);
    }

    function setDistributorSettings(uint256 gas) external onlyOwner {
        require(gas < 750000);
        distributorGas = gas;
    }

    function purgeBeforeSwitch() public onlyOwner {
        dividendTracker.purge(msg.sender);
    }

    function includeMeinRewards() public {
        require(
            !isDividendExempt[msg.sender],
            "You are not allowed to get rewards"
        );
        try
            dividendTracker.setShare(msg.sender, _balances[msg.sender])
        {} catch {}

        emit IncludeInReward(msg.sender);
    }

    function switchToken(address rewardToken, bool isIncludeHolders)
        public
        onlyOwner
    {
        require(rewardToken != WBNB, "Can not reward BNB in this tracker");
        REWARD = rewardToken;
        // get current shareholders list
        address[] memory currentHolders = dividendTracker.getShareHoldersList();
        dividendTracker = new DividendDistributor(address(router), rewardToken);
        if (isIncludeHolders) {
            // add old share holders to new tracker
            for (uint256 i = 0; i < currentHolders.length; i++) {
                try
                    dividendTracker.setShare(
                        currentHolders[i],
                        _balances[currentHolders[i]]
                    )
                {} catch {}
            }
        }

        emit ChangeRewardTracker(rewardToken);
    }
}
