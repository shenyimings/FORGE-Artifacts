// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./CatForceDividendTracker.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract CatForce is ERC20, Ownable {

    IUniswapV2Router02 public uniswapV2Router;
    address public immutable uniswapV2Pair;

    bool private inSwapAndLiquify;

    bool public swapAndLiquifyEnabled = true;

    CatForceDividendTracker public dividendTracker;

    uint256 public maxSellTransactionAmount;
    uint256 public swapTokensAtAmount;

    // use by default 300,000 gas to process auto-claiming dividends
    uint256 public gasForProcessing = 300000;

    IERC20 public immutable Busd;
    address public marketingWallet = 0x40b0624f00830B6dB55e33171DBdE2f56A42d151;

    // exlcude from fees and max transaction amount
    mapping(address => bool) public isExcludedFromFees;

    mapping(address => bool) private isExcludedFromMaxTx;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;

    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event SwapAndLiquifyEnabledUpdated(bool enabled);

    struct balances {
        uint256 marketing_balance;
        uint256 lp_balance;
        uint256 rewards_balance;
    }

    struct feeRatesStruct {
        uint64 marketing;
        uint64 liquidity;
        uint64 rewards;
        uint64 total;
    }

    balances public contractBalance;

    feeRatesStruct public buyFees = feeRatesStruct({ marketing: 5, liquidity: 5, rewards: 5, total: 15 });

    feeRatesStruct public sellFees = feeRatesStruct({ marketing: 6, liquidity: 6, rewards: 6, total: 18 });

    event SwapAndLiquify(uint256 tokensIntoLiqudity, uint256 ethReceived);

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
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor(IUniswapV2Router02 _uniswapV2Router, IERC20 _Busd) ERC20("CatForce", "CFO") {
        dividendTracker = new CatForceDividendTracker(_Busd);
        Busd = _Busd;
        // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
            address(this),
            _uniswapV2Router.WETH()
        );

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

        // exclude from receiving dividends
        dividendTracker.excludeFromDividends(address(dividendTracker));
        dividendTracker.excludeFromDividends(address(this));
        dividendTracker.excludeFromDividends(owner());
        dividendTracker.excludeFromDividends(0x000000000000000000000000000000000000dEaD);

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);

        // exclude from max tx
        isExcludedFromMaxTx[owner()] = true;
        isExcludedFromMaxTx[address(this)] = true;

        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        uint256 supply = 10**9 * (10**18); //1B tokens
        maxSellTransactionAmount=supply/1000; //0.1% of supply 1M tokens
        swapTokensAtAmount=supply/2000; //0.05% of supply 500k tokens

        _mint(owner(), supply);
    }

    receive() external payable {}

    function updateUniswapV2Router(address newAddress) public onlyOwner {
        require(newAddress != address(uniswapV2Router), "CatForce: The router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function setExcludeFromMaxTx(address _address, bool value) public onlyOwner {
        isExcludedFromMaxTx[_address] = value;
    }

    function setExcludeFromAll(address _address) public onlyOwner {
        isExcludedFromMaxTx[_address] = true;
        isExcludedFromFees[_address] = true;
        dividendTracker.excludeFromDividends(_address);
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(
            pair != uniswapV2Pair,
            "CatForce: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(
            automatedMarketMakerPairs[pair] != value,
            "CatForce: Automated market maker pair is already set to that value"
        );
        automatedMarketMakerPairs[pair] = value;

        if (value) {
            dividendTracker.excludeFromDividends(pair);
        }

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        require(
            newValue >= 200000 && newValue <= 500000,
            "CatForce: gasForProcessing must be between 200,000 and 500,000"
        );
        require(newValue != gasForProcessing, "CatForce: Cannot update gasForProcessing to same value");
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

    function withdrawableDividendOf(address account) public view returns (uint256) {
        return dividendTracker.withdrawableDividendOf(account);
    }

    function dividendTokenBalanceOf(address account) public view returns (uint256) {
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
        (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) = dividendTracker.process(gas);
        emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, false, gas, tx.origin);
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

    //this will be used to exclude from dividends the presale smart contract address
    function excludeFromDividends(address account) external onlyOwner {
        dividendTracker.excludeFromDividends(account);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        feeRatesStruct memory appliedFee;
        if (automatedMarketMakerPairs[from]) {
            appliedFee = buyFees;
        } else {
            appliedFee = sellFees;
        }

        if (automatedMarketMakerPairs[to] && (!isExcludedFromMaxTx[from]) && (!isExcludedFromMaxTx[to])) {
            require(amount <= maxSellTransactionAmount, "Sell transfer amount exceeds the maxSellTransactionAmount.");
        }

        if (
            contractBalance.marketing_balance >= swapTokensAtAmount &&
            !inSwapAndLiquify &&
            !automatedMarketMakerPairs[from] &&
            swapAndLiquifyEnabled
        ) {
            uint256 tokensBalance = balanceOf(address(this));
            swapTokensForBusd(swapTokensAtAmount, marketingWallet);
            uint256 tokensSwapped = tokensBalance - balanceOf(address(this));
            contractBalance.marketing_balance -= tokensSwapped;
        }

        if (
            contractBalance.lp_balance >= swapTokensAtAmount &&
            !inSwapAndLiquify &&
            !automatedMarketMakerPairs[from] &&
            swapAndLiquifyEnabled
        ) {
            swapAndLiquify(swapTokensAtAmount);
        }

        if (
            contractBalance.rewards_balance >= swapTokensAtAmount &&
            !inSwapAndLiquify &&
            !automatedMarketMakerPairs[from] &&
            swapAndLiquifyEnabled
        ) {
            uint256 tokensBalance = balanceOf(address(this));
            swapAndSendDividends(swapTokensAtAmount);
            uint256 tokensSwapped = tokensBalance - balanceOf(address(this));
            contractBalance.rewards_balance -= tokensSwapped;
        }

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (!isExcludedFromFees[from] && !isExcludedFromFees[to]) {
            uint256 fees = (amount * appliedFee.total) / 100;
            uint256 marketing = (amount * appliedFee.marketing) / 100;
            uint256 lp = (amount * appliedFee.liquidity) / 100;
            uint256 rewards = fees - marketing - lp;
            contractBalance.marketing_balance += marketing;
            contractBalance.lp_balance += lp;
            contractBalance.rewards_balance += rewards;

            amount -= fees;

            super._transfer(from, address(this), fees);
        }

        super._transfer(from, to, amount);

        try dividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
        try dividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}

        if (!inSwapAndLiquify) {
            uint256 gas = gasForProcessing;

            try dividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
                emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
            } catch {}
        }
    }

    function swapTokensForEth(uint256 tokenAmount, address payable receiver) private lockTheSwap {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        if (allowance(address(this), address(uniswapV2Router)) < tokenAmount) {
            _approve(address(this), address(uniswapV2Router), type(uint256).max);
        }

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            receiver,
            block.timestamp
        );
    }

    function swapTokensForBusd(uint256 tokenAmount, address receiver) private lockTheSwap {
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        path[2] = address(Busd);

        if (allowance(address(this), address(uniswapV2Router)) < tokenAmount) {
            _approve(address(this), address(uniswapV2Router), type(uint256).max);
        }

        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            receiver,
            block.timestamp
        );
    }

    function swapAndLiquify(uint256 tokens) private {
        // split the contract balance into halves
        uint256 half = tokens / 2;
        uint256 otherHalf = tokens - half;

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;
        uint256 tokensBalance = balanceOf(address(this));

        // swap tokens for ETH
        swapTokensForEth(half, payable(this));

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance - initialBalance;

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        uint256 tokensSwapped = tokensBalance - balanceOf(address(this));
        contractBalance.lp_balance -= tokensSwapped;

        emit SwapAndLiquify(tokensSwapped, newBalance);
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private lockTheSwap {
        // approve token transfer to cover all possible scenarios
        if (allowance(address(this), address(uniswapV2Router)) < tokenAmount) {
            _approve(address(this), address(uniswapV2Router), type(uint256).max);
        }

        // add the liquidity
        uniswapV2Router.addLiquidityETH{ value: ethAmount }(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0),
            block.timestamp
        );
    }

    function swapAndSendDividends(uint256 tokens) private {
        swapTokensForBusd(tokens, address(this));
        uint256 dividends = Busd.balanceOf(address(this));
        bool success = Busd.transfer(address(dividendTracker), dividends);

        if (success) {
            dividendTracker.distributeERC20Dividends(dividends);
            emit SendDividends(tokens, dividends);
        }
    }

    //in case reserves lose the peg to the address balance in tokens
    function resetBalancer() external onlyOwner {
        uint256 _contract_balance = balanceOf(address(this));

        contractBalance.marketing_balance = _contract_balance / 3;
        uint256 twoThirds = _contract_balance - contractBalance.marketing_balance;
        contractBalance.lp_balance = twoThirds / 2;
        contractBalance.rewards_balance = twoThirds - contractBalance.lp_balance;
    }

    function rescueBNBFromContract() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setBuyFees(uint64 marketing,uint64 liquidity,uint64 rewards) external onlyOwner{
        buyFees.marketing=marketing;
        buyFees.liquidity=liquidity;
        buyFees.rewards=rewards;
        buyFees.total=marketing+liquidity+rewards;
        require(buyFees.total<=100,"buy fees can't go over 100%");
    }

    function setSellFees(uint64 marketing,uint64 liquidity,uint64 rewards) external onlyOwner{
        sellFees.marketing=marketing;
        sellFees.liquidity=liquidity;
        sellFees.rewards=rewards;
        sellFees.total=marketing+liquidity+rewards;
        require(sellFees.total<=100,"sell fees can't go over 100%");
    }
    function setMaxSellTransactionAmount(uint256 amount) external onlyOwner{
        maxSellTransactionAmount=amount;
    }

    function setswapTokensAtAmount(uint256 amount) external onlyOwner{
        swapTokensAtAmount=amount;
    }
}