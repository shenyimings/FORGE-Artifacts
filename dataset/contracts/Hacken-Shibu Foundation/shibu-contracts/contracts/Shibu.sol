// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.6;

import "./libraries/DividendPayingToken.sol";
import "./libraries/Ownable.sol";
import "./interfaces/ICoinswap.sol";
import "./ShibuDividendTracker.sol";

contract Shibu is BEP20, Ownable {

    IRouter public router;
    address public pair;

    address public constant deadWallet = 0x000000000000000000000000000000000000dEaD;

    address constant public BUSD = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    bool private swapping;
    bool public swapEnabled = true;
    bool public autoBoostEnabled = false;

    uint256 public autoBoostThreshold = 1 ether; //initially set to 1 BNB

    ShibuDividendTracker public dividendTracker;

    uint256 public swapTokensAtAmount = 25000 * 10**decimals();
    uint256 public maxWalletBalance = 2e13 * 10**decimals(); // 2% of total supply
    uint256 public maxTxAmount = 25e11 * 10**decimals(); // 0.25% of total supply

    uint256 public BUSDRewardsFee = 25;
    uint256 public charityFee = 10;
    uint256 public liquidityFee = 10;
    uint256 public burnFee = 15;
    uint256 public autoBoost = 0;
    uint256 public totalFees = BUSDRewardsFee + charityFee + liquidityFee + autoBoost;

    address public charityWallet = 0x6719B4EfA20b7cF5Dc0d5A1a0Bac600c68884Dfd;
    address public liquidityWallet = 0x6719B4EfA20b7cF5Dc0d5A1a0Bac600c68884Dfd;

    // use by default 500,000 gas to process auto-claiming dividends
    uint256 public gasForProcessing = 500000;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public _isBlacklisted;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;

    event UpdateDividendTracker(
        address indexed newAddress,
        address indexed oldAddress
    );
    event UpdateRouter(address indexed newAddress, address indexed oldAddress);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event BlackListAccountAdded(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event BUSDRewardsFeeUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event CharityFeeUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event LiquidityFeeUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event AutoBoostFeeUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event BurnFeeUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event SwapTokensAtAmountUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event MaxWalletBalanceUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event MaxTxAmountUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event AutoBoostThresholdUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event SwapEnabledUpdated(bool newValue, bool oldValue);
    event AutoBoostEnabledUpdated(bool newValue, bool oldValue);
    event MinBalanceForRewardsUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event GasForProcessingUpdated(
        uint256 indexed newValue,
        uint256 indexed oldValue
    );

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiqudity
    );

    event SwapBNBForTokens(uint256 amountIn, address[] path);

    event SendDividends(uint256 tokensSwapped, uint256 amount);

    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    modifier lockTheSwap() {
        swapping = true;
        _;
        swapping = false;
    }

    constructor() BEP20("SHIBU", "SHIBU") {
        dividendTracker = new ShibuDividendTracker();

        IRouter _router = IRouter(0x34DBe8E5faefaBF5018c16822e4d86F02d57Ec27); //Coinswap router address
        // Create a Coinswap pair for this new token
        address _pair = IFactory(_router.factory()).createPair(
            address(this),
            _router.WBNB()
        );

        router = _router;
        pair = _pair;

        _setAutomatedMarketMakerPair(_pair, true);

        // exclude from receiving dividends
        dividendTracker.excludeFromDividends(address(dividendTracker), true);
        dividendTracker.excludeFromDividends(address(this), true);
        dividendTracker.excludeFromDividends(deadWallet, true);
        dividendTracker.excludeFromDividends(owner(), true);

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(charityWallet, true);
        excludeFromFees(deadWallet, true);

        /*
            _mint is an internal function in BEP20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(owner(), 1e12 * (10**9));
    }

    receive() external payable {}

    function updateDividendTracker(address newAddress) external onlyOwner {
        require(
            newAddress != address(dividendTracker),
            "SHIBU: The dividend tracker already has that address"
        );

        ShibuDividendTracker newDividendTracker = ShibuDividendTracker(
            payable(newAddress)
        );

        require(
            newDividendTracker.owner() == address(this),
            "SHIBU: The new dividend tracker must be owned by the SHIBU token contract"
        );

        newDividendTracker.excludeFromDividends(
            address(newDividendTracker),
            true
        );
        newDividendTracker.excludeFromDividends(address(this), true);
        newDividendTracker.excludeFromDividends(owner(), true);
        newDividendTracker.excludeFromDividends(address(router), true);

        emit UpdateDividendTracker(newAddress, address(dividendTracker));

        dividendTracker = newDividendTracker;
    }

    function updateRouter(address newAddress) external onlyOwner {
        require(
            newAddress != address(router),
            "SHIBU: The router already has that address"
        );
        emit UpdateRouter(newAddress, address(router));
        router = IRouter(newAddress);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(
            _isExcludedFromFees[account] != excluded,
            "SHIBU: Account is already the value of 'excluded'"
        );
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(
        address[] calldata accounts,
        bool excluded
    ) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function setAutomatedMarketMakerPair(address newPair, bool value)
    external
    onlyOwner
    {
        _setAutomatedMarketMakerPair(newPair, value);
    }

    function excludeFromDividends(address account, bool value)
    external
    onlyOwner
    {
        dividendTracker.excludeFromDividends(account, value);
    }

    function _setAutomatedMarketMakerPair(address newPair, bool value) private {
        require(
            automatedMarketMakerPairs[newPair] != value,
            "SHIBU: Automated market maker pair is already set to that value"
        );
        automatedMarketMakerPairs[newPair] = value;

        if (value) {
            dividendTracker.excludeFromDividends(newPair, value);
        }

        emit SetAutomatedMarketMakerPair(newPair, value);
    }

    function updateGasForProcessing(uint256 newValue) external onlyOwner {
        require(
            newValue >= 200000 && newValue <= 1000000,
            "SHIBU: gasForProcessing must be between 200,000 and 10,00,000"
        );
        require(
            newValue != gasForProcessing,
            "SHIBU: Cannot update gasForProcessing to same value"
        );
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function updateClaimWait(uint256 claimWait) external onlyOwner {
        dividendTracker.updateClaimWait(claimWait);
    }

    function getClaimWait() external view returns (uint256) {
        return dividendTracker.claimWait();
    }

    function getTotalDividendsDistributed() external view returns (uint256) {
        return dividendTracker.totalDividendsDistributed();
    }

    function isExcludedFromFees(address account) external view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function withdrawableDividendOf(address account)
    public
    view
    returns (uint256)
    {
        return dividendTracker.withdrawableDividendOf(account);
    }

    function dividendTokenBalanceOf(address account)
    external
    view
    returns (uint256)
    {
        return dividendTracker.balanceOf(account);
    }

    function getAccountDividendsInfo(address account)
    external
    view
    returns (
        address,
        int256,
        int256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    )
    {
        return dividendTracker.getAccount(account);
    }

    function getAccountDividendsInfoAtIndex(uint256 index)
    external
    view
    returns (
        address,
        int256,
        int256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    )
    {
        return dividendTracker.getAccountAtIndex(index);
    }

    function processDividendTracker(uint256 gas) external {
        (
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex
        ) = dividendTracker.process(gas);
        emit ProcessedDividendTracker(
            iterations,
            claims,
            lastProcessedIndex,
            false,
            gas,
            tx.origin
        );
    }

    function claim() external {
        dividendTracker.processAccount(payable(msg.sender), false);
    }

    function getLastProcessedIndex() external view returns (uint256) {
        return dividendTracker.getLastProcessedIndex();
    }

    function getNumberOfDividendTokenHolders() external view returns (uint256) {
        return dividendTracker.getNumberOfTokenHolders();
    }

    function setFees(
        uint256 _BUSDFee,
        uint256 _charityFee,
        uint256 _liqFee,
        uint256 _autoBoostFee,
        uint256 _burnFee
    ) external onlyOwner {
        require(
            _BUSDFee + _charityFee + _liqFee + _autoBoostFee <= 350,
            "Fees must be <= 35%"
        );
        emit BUSDRewardsFeeUpdated(_BUSDFee, BUSDRewardsFee);
        BUSDRewardsFee = _BUSDFee;

        emit CharityFeeUpdated(_charityFee, charityFee);
        charityFee = _charityFee;

        emit LiquidityFeeUpdated(_liqFee, liquidityFee);
        liquidityFee = _liqFee;

        emit AutoBoostFeeUpdated(_autoBoostFee, autoBoost);
        autoBoost = _autoBoostFee;

        emit BurnFeeUpdated(_burnFee, burnFee);
        burnFee = _burnFee;

        totalFees = BUSDRewardsFee + charityFee + liquidityFee + autoBoost;
    }

    function setCharityWallet(address newWallet) external onlyOwner {
        charityWallet = newWallet;
    }

    function setLiquidityWallet(address newWallet) external onlyOwner {
        liquidityWallet = newWallet;
    }

    function setSwapTokensAtAmount(uint256 amount) external onlyOwner {
        uint256 newValue = amount * 10**decimals();

        emit SwapTokensAtAmountUpdated(newValue, swapTokensAtAmount);

        swapTokensAtAmount = newValue;
    }

    function setMaxWalletBalance(uint256 amount) external onlyOwner {
        uint256 newValue = amount * 10**decimals();

        emit MaxWalletBalanceUpdated(newValue, maxWalletBalance);

        maxWalletBalance = newValue;
    }

    function setMinTokensToGetrewards(uint256 amount) external onlyOwner {
        uint256 newValue = amount * 10**decimals();
        uint256 oldValue = dividendTracker.minimumTokenBalanceForDividends();

        emit MinBalanceForRewardsUpdated(newValue, oldValue);
        dividendTracker.setMinimumBalanceForRewards(newValue);
    }

    function setBlacklistAccount(address account, bool state)
    external
    onlyOwner
    {
        require(_isBlacklisted[account] != state, "Value already set");
        emit BlackListAccountAdded(account, state);

        _isBlacklisted[account] = state;
    }

    function setMaxTxAmount(uint256 amount) external onlyOwner {
        require(amount > 200_000 * 10**decimals(), "Amount must be > 200M");

        uint256 newValue = amount * 10**decimals();

        emit MaxTxAmountUpdated(newValue, maxTxAmount);

        maxTxAmount = newValue;
    }

    function setSwapEnabled(bool value) external onlyOwner {
        emit SwapEnabledUpdated(value, swapEnabled);
        swapEnabled = value;
    }

    function setAutoBoostEnabled(bool value) external onlyOwner {
        emit AutoBoostEnabledUpdated(value, autoBoostEnabled);
        autoBoostEnabled = value;
    }

    function setAutoBoostThreshold(uint256 amount) external onlyOwner {
        uint256 newValue = amount * 10**18;
        emit AutoBoostThresholdUpdated(newValue, autoBoostThreshold);
        autoBoostThreshold = newValue;
    }

    function rescueBNB(uint256 weiAmount) external onlyOwner {
        require(address(this).balance >= weiAmount, "Insufficient BNB");
        payable(msg.sender).transfer(weiAmount);
    }

    function rescueBEP20(address tokenAdd, uint256 amount) external onlyOwner {
        IBEP20(tokenAdd).transfer(msg.sender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(to != address(0), "BEP20: transfer to the zero address");
        require(
            !_isBlacklisted[from] && !_isBlacklisted[to],
            "You are blacklisted"
        );

        if (
            !automatedMarketMakerPairs[to] &&
        !_isExcludedFromFees[from] &&
        !_isExcludedFromFees[to] &&
        to != deadWallet
        ) {
            require(
                (balanceOf(to) + amount) <= maxWalletBalance,
                "Balance is exceeding maxWalletBalance"
            );
        }

        if (!_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            require(amount <= maxTxAmount, "Amount is exceeding maxTxAmount");
        }

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        if (
            swapEnabled &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            !_isExcludedFromFees[from] &&
            !_isExcludedFromFees[to]
        ) {
            uint256 balance = address(this).balance;
            if (
                automatedMarketMakerPairs[to] &&
                autoBoostEnabled &&
                balance >= autoBoostThreshold
            ) {
                triggerAutoBoost(autoBoostThreshold);
            }

            bool canSwap = contractTokenBalance >= swapTokensAtAmount;

            if (canSwap) {
                swapAndLiquify(
                    (swapTokensAtAmount * (totalFees - BUSDRewardsFee)) / totalFees
                );

                if (BUSDRewardsFee > 0) {

                    uint256 sellTokens = (swapTokensAtAmount * BUSDRewardsFee) / totalFees;
                    swapAndSendDividends(sellTokens);
                }
            }
        }

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if (takeFee) {
            uint256 fees = (amount * totalFees) / 1000;
            uint256 burnAmt = (amount * burnFee) / 1000;

            amount = amount - fees - burnAmt;
            super._transfer(from, address(this), fees);
            super._transfer(from, deadWallet, burnAmt);
        }
        super._transfer(from, to, amount);

        try
        dividendTracker.setBalance(payable(from), balanceOf(from))
        {} catch {}
        try dividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}

        if (!swapping) {
            uint256 gas = gasForProcessing;

            try dividendTracker.process(gas) returns (
                uint256 iterations,
                uint256 claims,
                uint256 lastProcessedIndex
            ) {
                emit ProcessedDividendTracker(
                    iterations,
                    claims,
                    lastProcessedIndex,
                    true,
                    gas,
                    tx.origin
                );
            } catch {}
        }
    }

    function triggerAutoBoost(uint256 amount) private lockTheSwap {
        if (amount > 0) {
            swapBNBForTokens(amount);
        }
    }

    function swapAndLiquify(uint256 tokens) private lockTheSwap {
        // Split the contract balance into halves
        uint256 denominator = (liquidityFee + charityFee + autoBoost) * 2;
        uint256 tokensToAddLiquidityWith = (tokens * liquidityFee) /
        denominator;
        uint256 toSwap = tokens - tokensToAddLiquidityWith;

        uint256 initialBalance = address(this).balance;

        swapTokensForBnb(toSwap);

        uint256 deltaBalance = address(this).balance - initialBalance;
        uint256 unitBalance = deltaBalance / (denominator - liquidityFee);
        uint256 BNBToAddLiquidityWith = unitBalance * liquidityFee;

        if (BNBToAddLiquidityWith > 0) {
            // Add liquidity to Coinswap
            addLiquidity(tokensToAddLiquidityWith, BNBToAddLiquidityWith);
        }

        // Send BNB to charity
        uint256 charityAmt = unitBalance * 2 * charityFee;
        if (charityAmt > 0) payable(charityWallet).transfer(charityAmt);
    }

    function swapBNBForTokens(uint256 amount) private {
        // generate the Coinswap pair path of Token -> WBNB
        address[] memory path = new address[](2);
        path[0] = router.WBNB();
        path[1] = address(this);

        // make the swap
        router.swapExactBNBForTokensSupportingFeeOnTransferTokens{
        value: amount
        }(
            0, // accept any amount of Tokens
            path,
            deadWallet, // Burn address
            (block.timestamp + 300)
        );

        emit SwapBNBForTokens(amount, path);
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(router), tokenAmount);

        // add the liquidity
        router.addLiquidityBNB{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            liquidityWallet,
            block.timestamp
        );
    }

    function swapTokensForBnb(uint256 tokenAmount) private {
        // generate the Coinswap pair path of Token -> WBNB
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WBNB();

        _approve(address(this), address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForBNBSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp
        );
    }

    function swapTokensForBUSD(uint256 tokenAmount) private {
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = router.WBNB();
        path[2] = BUSD;

        _approve(address(this), address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function swapAndSendDividends(uint256 tokens) private lockTheSwap {
        swapTokensForBUSD(tokens);
        uint256 dividends = IBEP20(BUSD).balanceOf(address(this));
        bool success = IBEP20(BUSD).transfer(
            address(dividendTracker),
            dividends
        );

        if (success) {
            dividendTracker.distributeBUSDDividends(dividends);
            emit SendDividends(tokens, dividends);
        }
    }
}