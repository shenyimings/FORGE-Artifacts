// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Ownable.sol";
import "./interfaces/interfaces.sol";


contract HulkToken is ERC20, Ownable {
    using SafeMath for uint256;
    struct FeeType {
        uint256 bnb;
        uint256 busd;
        uint256 marketing;
        uint256 liquidity;
        uint256 burn;
    }

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    address BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;

    bool private swapping;

    IRewardDividendTracker public dividendTracker;

    uint8 _decimals = 18;
    uint256 public maxBuyTranscationAmount = 1000000000000000 * (10**uint256(_decimals));
    uint256 public maxSellTransactionAmount = 1000000000000000 * (10**uint256(_decimals));
    uint256 public maxWalletToken = 1000000000000000 * (10**uint256(_decimals)); // 100% of total supply
    uint256 public swapTokensAtAmount = 2000000000 * (10**uint256(_decimals));
    bool public enableSwapAndLiquify = false;


    FeeType public fee = FeeType(100, 300, 400, 300, 100);
    uint256 public totalFees = fee.bnb + fee.busd + fee.marketing + fee.liquidity + fee.burn;
    uint256 public sellFeeMultiplier = 150;
    uint256 public sellFeeDenominator = 100;
    uint256 constant public DENOMINATOR = 10_000;
    address public marketingWallet = 0x74715f53D56b0f242579Ae661FC0D7023CA76423;


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
        uint256 bnbReceived,
        uint256 tokensIntoLiqudity
    );

    event SendDividends(
        uint256 amount,
        string currency
    );

    event SwapBNBForTokens(
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

    constructor() ERC20("HulkToken", "HULK") {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);//mainnet
//      IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);//testnet
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
        _mint(owner(), 10_000_000_000 * (10**uint256(_decimals)));
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    receive() external payable {}

    function setSellFeeMultiplier(uint256 value) external onlyOwner {
        require(value >= 100 && value <= 300, 'Multiplier should be in 100-300 range');
        emit UpdateSellFeeMultiplier(sellFeeMultiplier, value);
        sellFeeMultiplier = value;
    }

    function setSwapTokensAtAmount(uint256 value) external onlyOwner {
        swapTokensAtAmount = value * (10**uint256(_decimals));
    }

    function setEnableSwapAndLiquify(bool status) external onlyOwner {
        enableSwapAndLiquify = status;
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

    function updateFees(uint256 busd, uint256 bnb, uint256 marketing, uint256 liquidity, uint256 burn) public onlyOwner {
        totalFees = bnb + busd + marketing + liquidity + burn;
        require(totalFees <= 4000, "All tax must be <= 4000");
        emit UpdateFees(fee.busd, busd, fee.bnb, bnb, fee.marketing, marketing, fee.liquidity, liquidity, fee.burn, burn);
        fee.bnb = bnb;
        fee.busd = busd;
        fee.marketing = marketing;
        fee.liquidity = liquidity;
        fee.burn = burn;
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
            uint256 totalFeeWithoutBurn = totalFees - fee.burn;
            uint256 onePart = swapTokensAtAmount / totalFeeWithoutBurn;
            uint256 halfOfLiquidity = onePart.mul(fee.liquidity).div(2);

            uint256 swapToBNB = swapTokensAtAmount - halfOfLiquidity; // all without half of liquidity part

            swapTokensForBNB(swapToBNB);
            uint256 contractBNBBalance = address(this).balance;

            onePart = contractBNBBalance / (totalFeeWithoutBurn - (fee.liquidity / 2));
            //            uint256 bnb;
            //            uint256 busd;
            //            uint256 marketing;
            //            uint256 liquidity;
            uint256 bnbForBUSD = onePart * fee.busd;
            uint256 bnbForMarketing = onePart * fee.marketing;
            uint256 bnbForLiquidity = onePart * fee.liquidity / 2;
            uint256 bnbForBNB = contractBNBBalance - bnbForBUSD - bnbForLiquidity - bnbForMarketing;

            if (bnbForMarketing > 0) {
                transferToMarketing(bnbForMarketing);
            }

            if (bnbForLiquidity > 0) {
                addLiquidity(halfOfLiquidity, bnbForLiquidity);
                emit SwapAndLiquify(halfOfLiquidity, bnbForLiquidity, halfOfLiquidity);
            }

            if (bnbForBNB > 0) {
                (bool success,) = address(dividendTracker).call{value: bnbForBNB}("");

                if(success) {
                    emit SendDividends(bnbForBNB, "BNB");
                }
            }

            if (bnbForBUSD > 0 ) {
                swapAndSendDividends(bnbForBUSD, BUSD);
            }

            swapping = false;
        }

        bool takeFee = !swapping && !_isExcludedFromFees[from];

        if(takeFee) {
            uint256 fees;
            if (to == uniswapV2Pair) {
                fees = amount * totalFees * sellFeeMultiplier / sellFeeDenominator / DENOMINATOR;
            } else {
                fees = amount * totalFees / DENOMINATOR;
            }

            uint256 burnFee = fees * fee.burn / totalFees;

            amount -= fees;
            super._transfer(from, address(this), fees);
            super._transfer(address(this), deadAddress, burnFee);
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

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: bnbAmount}(
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

        emit SwapBNBForTokens(amount, path);
    }

    function swapAndSendDividends(uint256 bnbAmount, address dividendToken) private {
        swapBNBForDividendTokens(bnbAmount, address(this), dividendToken);
        uint256 dividends = IERC20(dividendToken).balanceOf(address(this));
        bool success = IERC20(dividendToken).transfer(address(dividendTracker), dividends);

        if (success) {
            dividendTracker.distributeDividendsBUSD(dividends);
            emit SendDividends(dividends, "BUSD");
        }
    }

    // TEST !!!!!! ONLY!!!!!
    function sendDividendsDirectlyOnlyForTest(uint256 amount, address dividendToken) external onlyOwner {
        bool success = IERC20(dividendToken).transfer(address(dividendTracker), amount);

        if (success) {
            dividendTracker.distributeDividendsBUSD(amount);
            emit SendDividends(amount, "BUSD");
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

    function withdrawStuckTokens(address token, uint256 amount, address recipient) external onlyOwner {
        IERC20(token).transfer(recipient, amount);
    }

    function withdrawStuckBnb(uint256 amount, address payable recipient) external onlyOwner {
        (bool sent,) = recipient.call{value: amount}("");
        require(sent, 'Error on withdraw BNB from contract');
    }


    // EVENTS

    event UpdateFees(
        uint256 oldBusd, uint256 newBusd,
        uint256 oldBnb, uint256 newBnb,
        uint256 oldMarketing, uint256 newMarketing,
        uint256 oldLiquidity, uint256 newLiquidity,
        uint256 oldBurn, uint256 newBurn
    );
}
