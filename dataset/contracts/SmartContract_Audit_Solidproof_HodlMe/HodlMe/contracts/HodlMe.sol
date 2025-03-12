//SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "./standard/ERC20.sol";
import "./standard/Ownable.sol";
import "./standard/SafeMath.sol";
import "./interface/IPancakeRouter02.sol";
import "./interface/IPancakeFactory.sol";
import "./HodlMeDividendTracker.sol";
import "./HodlMeGame.sol";

contract HodlMe is ERC20, Ownable {
    using SafeMath for uint256;

    IPancakeRouter02 public pancakeRouter;
    address public pancakePair;
    bool private swapping;

    HodlMeGame public hodlMeGameInstance;
    bool public gameIsEnabled;

    HodlMeDividendTracker public dividendTracker;
    address public charityWallet = 0xE611B29d50a64142047Ad5005C1728f4F8cE15eb;
    address public marketingWallet = 0x864fCFcf4175e593aB4979A05d7c02412B75dab0;

    uint256 public swapTokensAtAmount = 625000000 * (10**decimals());

    uint256 public sellDividendFee = 30;

    uint256 public buyCharityFee = 1;
    uint256 public buyMarketingFee = 5;
    uint256 public buyLiquidityFee = 6;

    uint256 public accDividendFee = 0;
    uint256 public accCharityFee = 0;
    uint256 public accMarketingFee = 0;
    uint256 public accLiquidityFee = 0;

    uint256 public maxHoldingAmount;

    uint256 public bnbAmountLiquidityFee = 0;
    uint256 public hodlMeAmountLiquidityFee = 0;

    // use by default 300,000 gas to process auto-claiming dividends
    uint256 public gasForProcessing = 300000;

    /****************/
    bool public tradingEnabled = true;
    bool public swappingEnabled = true;

    event UpdateSwappingStatus(bool status);
    event UpdateTradingStatus(bool status);

    // exlcude from fees and max transaction amount
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcludedFromMaxHoldLimit;

    // addresses that can make transfers before trading is enabled
    mapping(address => bool) private canTransferBeforeTradingIsEnabled;

    event UpdateDividendTracker(address indexed newAddress, address indexed oldAddress);
    event UpdateWallets(address oldCharity, address newCharity, address oldMarketing, address newMarketing);
    event UpdatePancakeRouter(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event GasForProcessingUpdated(
        uint256 indexed newValue,
        uint256 indexed oldValue
    );

    event SetBuyFees(
        uint256 BuyCharityFee,
        uint256 BuyMarketingFee,
        uint256 BuyLiquidityFee
    );
    event SetSellFees(uint256 SellDividendFee);

    event SetSwapTokensAtAmount(uint256 OldAmount, uint256 NewAmount);

    // events for last sell
    event SetMaxHoldingAmount(uint256 OldPercent, uint256 NewPercent);

    event StartSwapTokensForEth(uint256 tokenAmountToBeSwapped);
    event FinishSwapTokensForEth(uint256 ethAmountSwapped);
    event CalculatedBNBForEachRecipient(
        uint256 forCharity,
        uint256 forMarketing,
        uint256 forLiquidity,
        uint256 forDividends
    );
    event ErrorInProcess(address msgSender);
    event SwapAndSendTo(uint256 tokensSwapped, uint256 amount, string to);

    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    constructor() ERC20("hodlMe", "HODM") {
        dividendTracker = new HodlMeDividendTracker();
        updatePancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        // exclude from receiving dividends
        dividendTracker.excludeFromDividends(address(dividendTracker));
        dividendTracker.excludeFromDividends(address(this));
        dividendTracker.excludeFromDividends(address(0));

        _isExcludedFromMaxHoldLimit[address(0)] = true;

        excludeFromAllLimits(owner(), true);
        excludeFromAllLimits(address(this), true);
        excludeFromAllLimits(charityWallet, true);
        excludeFromAllLimits(marketingWallet, true);

        canTransferBeforeTradingIsEnabled[owner()] = true;

        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(owner(), 10**11 * (10**decimals()));
        maxHoldingAmount = totalSupply().div(100).mul(5);
    }


    function setGameIsEnabled(bool _gameIsEnabled) public onlyOwner{
        gameIsEnabled = _gameIsEnabled;
    }

    function setHodlMeGameAddress(address _hodlMeGameAddress) public onlyOwner {
        hodlMeGameInstance = HodlMeGame(_hodlMeGameAddress);
        excludeFromAllLimits(_hodlMeGameAddress, true);
    }

    function updatePancakeRouter(address newAddress) public onlyOwner {
        require(
            newAddress != address(pancakeRouter),
            "HodlMe: The router already has that address"
        );
        emit UpdatePancakeRouter(newAddress, address(pancakeRouter));
        pancakeRouter = IPancakeRouter02(newAddress);
        address _pancakePair = IPancakeFactory(pancakeRouter.factory())
            .createPair(address(this), pancakeRouter.WETH());
        pancakePair = _pancakePair;

        dividendTracker.excludeFromDividends(address(pancakeRouter));
        dividendTracker.excludeFromDividends(pancakePair);

        excludeFromAllLimits(newAddress, true);
        _isExcludedFromMaxHoldLimit[pancakePair] = true;
    }

    receive() external payable {}

    function excludeFromAllLimits(address account, bool status)
        public
        onlyOwner
    {
        _isExcludedFromFees[account] = status;
        _isExcludedFromMaxHoldLimit[account] = status;
    }

    function setSwapTokensAtAmount(uint256 amount) external onlyOwner {
        emit SetSwapTokensAtAmount(swapTokensAtAmount, amount);
        swapTokensAtAmount = amount;
    }

    function setMaxHoldingAmount(uint256 amount) external onlyOwner {
        emit SetMaxHoldingAmount(maxHoldingAmount, amount);
        maxHoldingAmount = amount;
    }

    function setBuyFees(
        uint256 _BuyCharityFee,
        uint256 _BuyMarketingFee,
        uint256 _BuyLiquidityFee
    ) external onlyOwner {
        buyCharityFee = _BuyCharityFee;
        buyMarketingFee = _BuyMarketingFee;
        buyLiquidityFee = _BuyLiquidityFee;

        uint256 totalFees = buyCharityFee + buyMarketingFee + buyLiquidityFee;
        require(totalFees < 51, "Too much");
        emit SetBuyFees(buyCharityFee, buyMarketingFee, buyLiquidityFee);
    }

    function setSellFees(uint256 _SellDividendFee) external onlyOwner {
        sellDividendFee = _SellDividendFee;
        require(sellDividendFee < 51, "Too much");
        emit SetSellFees(_SellDividendFee);
    }

    function setWallets(address newCharityAddress, address newMarketingAddress) external onlyOwner {
        require(newCharityAddress != address(0), "Charity Zero address");
        require(newMarketingAddress != address(0), "Marketing Zero address");
        emit UpdateWallets(charityWallet, newCharityAddress, marketingWallet, newMarketingAddress);
        charityWallet = newCharityAddress;
        marketingWallet = newMarketingAddress;
    }

    function setCanTransferBeforeTradingIsEnabled(address account, bool status)
        external
        onlyOwner
    {
        canTransferBeforeTradingIsEnabled[account] = status;
    }

    function excludeFromDividends(address account) external onlyOwner {
        dividendTracker.excludeFromDividends(account);
    }

    function isExcludedFromDividends(address account)
        external
        view
        returns (bool)
    {
        return dividendTracker.excludedFromDividends(account);
    }

    function updateDividendTracker(address newAddress) public onlyOwner {
        require(
            newAddress != address(dividendTracker),
            "HodlMe: The dividend tracker already has that address"
        );

        HodlMeDividendTracker newDividendTracker = HodlMeDividendTracker(
            payable(newAddress)
        );

        require(
            newDividendTracker.owner() == address(this),
            "HodlMe: The new dividend tracker must be owned by the HodlMe token contract"
        );

        newDividendTracker.excludeFromDividends(address(newDividendTracker));
        newDividendTracker.excludeFromDividends(address(this));
        newDividendTracker.excludeFromDividends(address(pancakeRouter));

        emit UpdateDividendTracker(newAddress, address(dividendTracker));

        dividendTracker = newDividendTracker;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(
            _isExcludedFromFees[account] != excluded,
            "HodlMe: Account is already the value of 'excluded'"
        );
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(
        address[] calldata accounts,
        bool excluded
    ) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        require(
            newValue >= 200000 && newValue <= 500000,
            "HodlMe: gasForProcessing must be between 200,000 and 500,000"
        );
        require(
            newValue != gasForProcessing,
            "HodlMe: Cannot update gasForProcessing to same value"
        );
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function updateClaimWait(uint256 claimWait) external onlyOwner {
        dividendTracker.updateClaimWait(claimWait);
    }

    function updateMinimumTokenBalanceForDividends(uint256 newTokenBalance)
        external
        onlyOwner
    {
        dividendTracker.updateMinimumTokenBalanceForDividends(newTokenBalance);
    }

    function getClaimWait() external view returns (uint256) {
        return dividendTracker.claimWait();
    }

    function getTotalDividendsDistributed() external view returns (uint256) {
        return dividendTracker.totalDividendsDistributed();
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function isExcludedFromMaxHoldLimit(address account)
        public
        view
        returns (bool)
    {
        return _isExcludedFromMaxHoldLimit[account];
    }

    function withdrawableDividendOf(address account)
        public
        view
        returns (uint256)
    {
        return dividendTracker.withdrawableDividendOf(account);
    }

    function dividendTokenBalanceOf(address account)
        public
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

    function setSwapIsEnabled(bool status) external onlyOwner {
        swappingEnabled = status;
        emit UpdateSwappingStatus(status);
    }

    function setTradingIsEnabled(bool status) external onlyOwner {
        tradingEnabled = status;
        emit UpdateTradingStatus(status);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (!tradingEnabled) {
            require(
                canTransferBeforeTradingIsEnabled[from],
                "HodlMe: This account cannot send tokens until trading is enabled"
            );
        }

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        bool canSwap = balanceOf(address(this)) >= swapTokensAtAmount;

        if (
            tradingEnabled &&
            canSwap &&
            !swapping &&
            swappingEnabled &&
            msg.sender != pancakePair
        ) {
            swapping = true;
            uint256 swapAmountTotal = accCharityFee
                .add(accLiquidityFee)
                .add(accMarketingFee)
                .add(accDividendFee);
            swapAndDistributeBNB(swapAmountTotal);
            swapping = false;
        }

        bool takeFee = tradingEnabled && !swapping;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }
        if (takeFee) {
            uint256 forDividends;
            uint256 forCharity;
            uint256 forMarketing;
            uint256 forLiquidity;

            if (to == pancakePair) {
                forDividends = amount.mul(sellDividendFee).div(100);
            } else {
                forCharity = amount.mul(buyCharityFee).div(100);
                forMarketing = amount.mul(buyMarketingFee).div(100);
                forLiquidity = amount.mul(buyLiquidityFee).div(100);
            }

            accCharityFee = accCharityFee.add(forCharity);
            accLiquidityFee = accLiquidityFee.add(forLiquidity);
            accMarketingFee = accMarketingFee.add(forMarketing);
            accDividendFee = accDividendFee.add(forDividends);

            uint256 fees = forLiquidity.add(forDividends).add(forCharity).add(
                forMarketing
            );
            amount = amount.sub(fees);
            super._transfer(from, address(this), fees);
        }

        if (!_isExcludedFromMaxHoldLimit[to]) {
            require(
                balanceOf(to).add(amount) <= maxHoldingAmount,
                "Holding limit!"
            );
        }

        super._transfer(from, to, amount);

        try dividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
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
            } catch {
                emit ErrorInProcess(msg.sender);
            }
        }

        if(gameIsEnabled && msg.sender != pancakePair){
           hodlMeGameInstance.endUserGames(msg.sender);
        }
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        emit StartSwapTokensForEth(tokenAmount);
        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeRouter.WETH();

        _approve(address(this), address(pancakeRouter), tokenAmount);

        uint256 halfOfLiquidityFee = accLiquidityFee.div(2);

        uint256[] memory amounts = pancakeRouter.getAmountsOut(
            halfOfLiquidityFee,
            path
        );

        hodlMeAmountLiquidityFee = amounts[0];
        bnbAmountLiquidityFee = amounts[1];

        // make the swap
        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount - halfOfLiquidityFee,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );

        pancakeRouter.addLiquidityETH{value: amounts[1]}(
            address(this),
            halfOfLiquidityFee,
            0,
            0,
            address(this),
            block.timestamp
        );

        emit FinishSwapTokensForEth(address(this).balance);
    }

    function swapAndDistributeBNB(uint256 tokens) private {
        swapTokensForEth(tokens);

        uint256 balance = address(this).balance;
        uint256 accTotal = accDividendFee
            .add(accCharityFee)
            .add(accMarketingFee)
            .add(accLiquidityFee);
        uint256 forCharity = balance.mul(accCharityFee).div(accTotal);
        uint256 forMarketing = balance.mul(accMarketingFee).div(accTotal);
        uint256 forLiquidity = balance.mul(accLiquidityFee).div(accTotal);
        uint256 forDividends = balance.sub(forCharity).sub(forMarketing).sub(
            forLiquidity
        );

        emit CalculatedBNBForEachRecipient(
            forCharity,
            forMarketing,
            forLiquidity,
            forDividends
        );

        (bool success, ) = address(charityWallet).call{value: forCharity}("");

        if (success) {
            emit SwapAndSendTo(accMarketingFee, forMarketing, "CHARITY");
            accCharityFee = 0;
        }

        (success, ) = address(marketingWallet).call{value: forMarketing}("");

        if (success) {
            emit SwapAndSendTo(accMarketingFee, forMarketing, "MARKETING");
            accMarketingFee = 0;
        }

        accLiquidityFee = 0;

        (success, ) = address(dividendTracker).call{value: forDividends}("");

        if (success) {
            emit SwapAndSendTo(accDividendFee, forDividends, "DIVIDENDS");
            accDividendFee = 0;
        }
    }
}
