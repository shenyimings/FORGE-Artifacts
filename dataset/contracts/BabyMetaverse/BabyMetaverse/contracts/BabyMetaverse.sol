// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Ownable.sol";
import "./interfaces/interfaces.sol";


contract BabyMetaverse is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    address BTCB = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
    address ETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;

    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;

    bool private swapping;

    IRewardDividendTracker public dividendTracker;

    uint8 _decimals = 9;
    uint256 public maxBuyTranscationAmount = 1000000000000000 * (10**uint256(_decimals));
    uint256 public maxSellTransactionAmount = 1000000000000000 * (10**uint256(_decimals));
    uint256 public maxWalletToken = 1000000000000000 * (10**uint256(_decimals)); // 100% of total supply
    uint256 public swapTokensAtAmount = 2000000000 * (10**uint256(_decimals));
    bool public enableSwapAndLiquify = false;

    uint256 public ethFee = 400;
    uint256 public btcbFee = 400;
    uint256 public accumulatedForBTCB;
    uint256 public marketingFee = 300;
    uint256 public liquidityFee = 100;
    uint256 public ethMultiplier = 100;
    uint256 public totalFees = ethFee + btcbFee + marketingFee + liquidityFee;
    uint256 public sellFeeMultiplier = 150;
    uint256 public sellFeeDenominator = 100;
    uint256 constant public DENOMINATOR = 10_000;
    address public marketingWallet = 0xffaE71185B7996AC3799346E3a3D13c4aEDf8b07;


    // use by default 300,000 gas to process auto-claiming dividends
    uint256 public gasForProcessing = 300000;

    // exlcude from fees and max transaction amount
    mapping (address => bool) private _isExcludedFromFees;
    mapping (address => bool) public _isExcludedFromMaxTX;
    mapping (address => bool) public _isExcludedFromMaxHold;

    event UpdateSellFeeMultiplier(uint256 oldValue, uint256 newValue);
    event UpdateDividendTracker(address indexed newAddress, address indexed oldAddress);
    event UpdateMarketingAddress(address newAddress, address oldAddress);

    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeFromMaxTX(address indexed account, bool isExcluded);
    event ExcludeFromMaxHold(address indexed account, bool isExcluded);

    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
    event ExcludedMaxSellTransactionAmount(address indexed account, bool isExcluded);

    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event SendDividends(
        uint256 amount,
        string currency
    );

    event SwapETHForTokens(
        uint256 amountIn,
        address[] path
    );

    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    constructor() ERC20("BabyMetaverse", "$BMETA") {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
//         IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
        // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;


        // exclude from receiving dividends



        // exclude from paying fees or having max transaction amount
        excludeFromFees(address(this), true);
        excludeFromFees(owner(), true);
        excludeFromFees(address(_uniswapV2Router), true);

        _isExcludedFromMaxHold[uniswapV2Pair] = true;
        _isExcludedFromMaxHold[owner()] = true;
        _isExcludedFromMaxHold[address(this)] = true;

        _isExcludedFromMaxTX[owner()] = true;
        _isExcludedFromMaxTX[address(this)] = true;


        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(owner(), 1000000000000000 * (10**uint256(_decimals)));
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    receive() external payable {

    }



    function setSellFeeMultiplier(uint256 value) external onlyOwner {
        require(value >= 100 && value <= 300, 'Multiplier should be in 100-300 range');
        emit UpdateSellFeeMultiplier(sellFeeMultiplier, value);
        sellFeeMultiplier = value;
    }

    function setSwapTokensAtAmount(uint256 value) external onlyOwner {
        swapTokensAtAmount = value * (10**uint256(_decimals));
    }

    function setEnableSwapAndLiquify(bool value) external onlyOwner {
        enableSwapAndLiquify = value;
    }

    function setMarketingWallet(address _marketingWallet) external onlyOwner {
        emit UpdateMarketingAddress(_marketingWallet, marketingWallet);
        marketingWallet = _marketingWallet;
    }

    function setMaxBuyTransaction(uint256 maxTxn) external onlyOwner {
        maxBuyTranscationAmount = maxTxn * (10**uint256(_decimals));
    }

    function setMaxSellTransaction(uint256 maxTxn) external onlyOwner {
        maxSellTransactionAmount = maxTxn * (10**uint256(_decimals));
    }

    function setMaxWalletToken(uint256 maxToken) external onlyOwner {
        maxWalletToken = maxToken * (10**uint256(_decimals));
    }

    function updateDividendTracker(address newAddress) public onlyOwner {
        require(newAddress != address(dividendTracker), "The dividend tracker already has that address");

        IRewardDividendTracker newDividendTracker = IRewardDividendTracker(payable(newAddress));

        require(newDividendTracker.owner() == address(this), "The new dividend tracker must be owned by the token contract");


        newDividendTracker.excludeFromDividends(address(newDividendTracker));
        newDividendTracker.excludeFromDividends(address(this));
        newDividendTracker.excludeFromDividends(address(uniswapV2Router));
        newDividendTracker.excludeFromDividends(uniswapV2Pair);
        newDividendTracker.excludeFromDividends(deadAddress);
        newDividendTracker.excludeFromDividends(address(0));

        emit UpdateDividendTracker(newAddress, address(dividendTracker));

        dividendTracker = newDividendTracker;
    }

    function updateDividendRewardFee(uint256 btcb, uint256 eth) public onlyOwner {
        require(eth + btcb <= 3000, "Dividend reward tax must be <= 3000");
        require(btcb >= 4 * ethMultiplier, "BTCB fee must be >= 400");
        totalFees = totalFees - (ethFee + btcbFee) + (eth + btcb);
        ethFee = eth;
        btcbFee = btcb;

    }

    function updateMarketingFee(uint256 newFee) public onlyOwner {
        require(newFee <= 4000, "Marketing tax must be less than 4000");
        totalFees = totalFees - marketingFee + newFee;
        marketingFee = newFee;
    }

    function updateUniswapV2Router(address newAddress) public onlyOwner {
        require(newAddress != address(uniswapV2Router), "The router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
    }

    function excludeFromMaxHold(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromMaxHold[account] != excluded, "Account is already the value of 'excluded'");
        _isExcludedFromMaxHold[account] = excluded;

        emit ExcludeFromMaxHold(account, excluded);
    }

    function excludeFromMaxTX(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromMaxTX[account] != excluded, "Account is already the value of 'excluded'");
        _isExcludedFromMaxTX[account] = excluded;

        emit ExcludeFromMaxTX(account, excluded);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromFees[account] != excluded, "Account is already the value of 'excluded'");
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        require(newValue >= 200000 && newValue <= 500000, "gasForProcessing must be between 200,000 and 500,000");
        require(newValue != gasForProcessing, "Cannot update gasForProcessing to same value");
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function updateClaimWait(uint256 claimWait) external onlyOwner {
        dividendTracker.updateClaimWait(claimWait);
    }

    function getClaimWait() external view returns(uint256) {
        return dividendTracker.claimWait();
    }

    function getTotalDividendsDistributed() external view returns (AdditionalTypes.Tokens memory) {
        return dividendTracker.totalDividendsDistributed();
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }

    function withdrawableDividendOf(address account) public view returns(AdditionalTypes.Tokens memory) {
        return dividendTracker.withdrawableDividendOf(account);
    }

    function dividendTokenBalanceOf(address account) public view returns (uint256) {
        return dividendTracker.balanceOf(account);
    }

    function getAccountDividendsInfo(address account)
    external view returns (
        address,
        int256,
        int256,
        AdditionalTypes.Tokens memory,
        AdditionalTypes.Tokens memory,
        uint256,
        uint256,
        uint256) {
        return dividendTracker.getAccount(account);
    }

    function getAccountDividendsInfoAtIndex(uint256 index)
    external view returns (
        address,
        int256,
        int256,
        AdditionalTypes.Tokens memory,
        AdditionalTypes.Tokens memory,
        uint256,
        uint256,
        uint256) {
        return dividendTracker.getAccountAtIndex(index);
    }

    function processDividendTracker(uint256 gas) external {
        (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) = dividendTracker.process(gas);
        emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, false, gas, tx.origin);
    }

    function claim() external {
        dividendTracker.processAccount(payable(msg.sender), false);
    }

    function getLastProcessedIndex() external view returns(uint256) {
        return dividendTracker.getLastProcessedIndex();
    }

    function getNumberOfDividendTokenHolders() external view returns(uint256) {
        return dividendTracker.getNumberOfTokenHolders();
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (!_isExcludedFromMaxHold[to]) {
            require(
                balanceOf(to) + amount <= maxWalletToken,
                "Exceeds maximum wallet token amount."
            );
        }

        if (!_isExcludedFromMaxTX[to] && from == uniswapV2Pair) {
            require(
                amount <= maxBuyTranscationAmount,
                "Transfer amount exceeds the maxTxAmount."
            );
        } else if (!_isExcludedFromMaxTX[from] && to == uniswapV2Pair) {
            require(
                amount <= maxSellTransactionAmount,
                "Sell transfer amount exceeds the maxSellTransactionAmount."
            );
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        if (from != uniswapV2Pair && enableSwapAndLiquify && contractTokenBalance >= swapTokensAtAmount && !swapping) {
            swapping = true;

            uint256 getAccumulatedForBTCB = accumulatedForBTCB;
            if (getAccumulatedForBTCB > swapTokensAtAmount / 2) {
                getAccumulatedForBTCB = swapTokensAtAmount / 2;
            }

            uint256 feeWithoutBTCB = swapTokensAtAmount - getAccumulatedForBTCB;
            uint256 onePart = feeWithoutBTCB / (totalFees - btcbFee);
            uint256 halfOfLiquidity = onePart.mul(liquidityFee).div(2);

            uint256 swapToBNB = swapTokensAtAmount - halfOfLiquidity; // all without half of liquidity part

            swapTokensForBNB(swapToBNB);
            uint256 contractBNBBalance = address(this).balance;
            uint256 bnbForBTCB = contractBNBBalance * getAccumulatedForBTCB / swapToBNB;
            uint256 bnbWithoutBTCB = contractBNBBalance - bnbForBTCB;
            onePart = bnbWithoutBTCB / (totalFees - btcbFee - (liquidityFee / 2));
            uint256 bnbForLiquidity = onePart * liquidityFee / 2;
            uint256 bnbForMarketing = onePart * marketingFee;
            uint256 bnbForETH= bnbWithoutBTCB - bnbForMarketing - bnbForLiquidity;

            if (bnbForMarketing > 0) {
                transferToMarketing(bnbForMarketing);
            }

            if (bnbForLiquidity > 0) {
                addLiquidity(halfOfLiquidity, bnbForLiquidity);
                emit SwapAndLiquify(halfOfLiquidity, bnbForLiquidity, halfOfLiquidity);
            }

            if (bnbForETH > 0) {
                swapAndSendDividends(bnbForETH, ETH);
            }

            if (bnbForBTCB > 0 ) {
                swapAndSendDividends(bnbForBTCB, BTCB);
                accumulatedForBTCB = accumulatedForBTCB - getAccumulatedForBTCB;
            }

            swapping = false;
        }

        bool takeFee = !swapping && !_isExcludedFromFees[from];

        if(takeFee) {
            uint256 minusBTCBFee;
            uint256 fees;

            if (from == uniswapV2Pair) {
                uint256 ethAmount = amountInETH(amount);
                if (ethAmount > 4) {
                    ethAmount = 4;
                }

                minusBTCBFee = ethAmount * ethMultiplier;
                fees = amount * (totalFees - minusBTCBFee) / DENOMINATOR;

                accumulatedForBTCB += fees * (btcbFee - minusBTCBFee) / (totalFees - minusBTCBFee);
            } else {
                fees = amount * totalFees * sellFeeMultiplier / sellFeeDenominator / DENOMINATOR;
                accumulatedForBTCB += fees * btcbFee / totalFees;
            }

            amount -= fees;

            super._transfer(from, address(this), fees);
        }

        super._transfer(from, to, amount);

        try dividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
        try dividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}

        if(!swapping && from != uniswapV2Pair) {
            uint256 gas = gasForProcessing;

            try dividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
                emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
            } catch {}
        }
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
            address(this),
            block.timestamp
        );

    }

    function swapTokensForBNB(uint256 tokenAmount) private {
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

    function swapBNBForDividendTokens(uint256 amount, address recipient, address dividendToken) private {
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = dividendToken;

        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            recipient,
            block.timestamp.add(300)
        );

        emit SwapETHForTokens(amount, path);
    }

    function swapAndSendDividends(uint256 bnbAmount, address dividendToken) private {
        swapBNBForDividendTokens(bnbAmount, address(this), dividendToken);
        uint256 dividends = IERC20(dividendToken).balanceOf(address(this));
        bool success = IERC20(dividendToken).transfer(address(dividendTracker), dividends);

        if (success) {
            if (dividendToken == BTCB) {
                dividendTracker.distributeDividendsBTCB(dividends);
                emit SendDividends(dividends, "BTCB");
            } else {
                dividendTracker.distributeDividendsETH(dividends);
                emit SendDividends(dividends, "ETH");
            }
        }
    }


    function transferToMarketing(uint256 amount) private {
        payable(marketingWallet).transfer(amount);
    }

    function amountInETH(uint256 amount) public view returns(uint256) {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        uint256[] memory res = uniswapV2Router.getAmountsOut(amount, path);
        return res[1];
    }

    function updateEthMultiplier(uint256 _ethMultiplier) external onlyOwner {
        require(btcbFee >= 4 * _ethMultiplier, "Discount cant be greater than BTCB fee");
        ethMultiplier = _ethMultiplier;
    }

    function sendTokens(address _token, uint256 _amount) public onlyOwner {
        IERC20(_token).transfer(msg.sender, _amount);
    }
}
