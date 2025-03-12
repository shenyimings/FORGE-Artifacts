// SPDX-License-Identifier: MIT
// Hayya World Cup 2022
// Email: contact@hayyaworldcup.com
pragma solidity =0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./BaseToken.sol";

contract HayyaWorldCup is ERC20, Ownable, BaseToken {
    using SafeMath for uint256;

    uint256 public constant VERSION = 1;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool private swapping;

    uint256 constant FEE_DENOMINATOR = 10000;

    uint256 private constant BNB_DECIMALS = 18;

    uint256 public maxJackpotLimitMultiplier = 10;

    uint256 private constant MAX_PCT = 10000;
    // PCS takes 0.25% fee on all txs
    uint256 private constant ROUTER_FEE = 25;

    // 55.55% jackpot cashout to last buyer
    uint256 public jackpotCashout = 5555;
    // 90% of jackpot cashout to last buyer
    uint256 public jackpotBuyerShare = 9000;
    // Buys 0.2 BNB will be eligible for the jackpot
    uint256 public jackpotMinBuy = 2 * 10**(BNB_DECIMALS - 1);
    // Jackpot time span is initially set to 5 mins
    uint256 public jackpotTimespan = 5 * 60;
    // Jackpot hard limit, BNB value
    uint256 public jackpotHardLimit = 50 * 10**(BNB_DECIMALS);
    // Jackpot hard limit buyback share
    uint256 public jackpotHardBuyback = 5000;

    uint256 public _jackpotTokens = 0;
    uint256 public _pendingJackpotBalance = 0;

    address private _lastBuyer = address(this);
    uint256 private _lastBuyTimestamp = 0;

    address private _lastAwarded = address(0);
    uint256 private _lastAwardedCash = 0;
    uint256 private _lastAwardedTokens = 0;
    uint256 private _lastAwardedTimestamp = 0;

    uint256 private _lastBigBangCash = 0;
    uint256 private _lastBigBangTokens = 0;
    uint256 private _lastBigBangTimestamp = 0;

    uint256 private _totalJackpotCashedOut = 0;
    uint256 private _totalJackpotTokensOut = 0;
    uint256 private _totalJackpotBuyer = 0;
    uint256 private _totalJackpotBuyback = 0;
    uint256 private _totalJackpotBuyerTokens = 0;
    uint256 private _totalJackpotBuybackTokens = 0;

    address public devWallet = 0xa47a68DEF373d2F6B645Fb0E873514A73310e9C9;
    address public communityWallet = 0xbacEcA8EC848FEEbe04eFBfa6962bA229489e9c8;
    address public marketingWallet = 0x40FF0412C5eC383184d08f117A4c96800b5fa0FD;
    address public buyBackBurnWallet =
        0x0D1f440A882eC76ba58785292Ac205d293383b2E;

    uint256 public swapTokensAtAmount;

    bool public tradingOpen;
    uint256 public launchedAt;
    uint256 public pumptime = 100;
    uint256 public maxSellAtStart;

    uint256 public devFee;
    uint256 public liquidityFee;
    uint256 public jackpotFee;
    uint256 public buyBackBurnFee;
    uint256 public communityFee;
    uint256 public marketingFee;
    uint256 public totalFees;

    // exlcude from fees
    mapping(address => bool) private _isExcludedFromFees;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;

    event UpdateUniswapV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event LiquidityWalletUpdated(
        address indexed newLiquidityWallet,
        address indexed oldLiquidityWallet
    );

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event DevFeeSent(address indexed receiver, uint256 value);
    event CommunityFeeSent(address indexed receiver, uint256 value);
    event BuyBackBurnFeeSent(address indexed receiver, uint256 value);
    event MarketingFeeSent(address indexed receiver, uint256 value);

    event TresuryReceived(address indexed receiver, uint256 indexed amount);

    event JackpotAwarded(address indexed receiver, uint256 amount);
    event BigBang(uint256 cashedOut, uint256 tokensOut);
    event JackpotFund(uint256 bnbSent, uint256 tokenAmount);

    modifier lockTheSwap() {
        swapping = true;
        _;
        swapping = false;
    }

    constructor(
        uint256[6] memory feeSettings // dev, liquidity, jackpot, burn, community, marketing
    ) ERC20("Hayya World Cup", "HYC") {
        devFee = feeSettings[0];
        liquidityFee = feeSettings[1];
        jackpotFee = feeSettings[2];
        buyBackBurnFee = feeSettings[3];
        communityFee = feeSettings[4];
        marketingFee = feeSettings[5];

        totalFees = devFee
            .add(liquidityFee)
            .add(jackpotFee)
            .add(buyBackBurnFee)
            .add(communityFee)
            .add(marketingFee);
        require(totalFees <= 2500, "HYC: Total fee is over 25%");
        swapTokensAtAmount = 100 ether; // Swap at 100 HYC

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            // 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );

        // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;
        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);
        // exclude from paying fees
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(devWallet), true);
        excludeFromFees(address(communityWallet), true);
        excludeFromFees(address(marketingWallet), true);
        excludeFromFees(address(buyBackBurnWallet), true);
        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        // premint 1B tokens to owner
        uint256 totalSupply = 1e9 ether;
        _mint(msg.sender, totalSupply);
        maxSellAtStart = totalSupply.div(10);
    }

    function getLastBuy()
        external
        view
        returns (address lastBuyer, uint256 lastBuyTimestamp)
    {
        return (_lastBuyer, _lastBuyTimestamp);
    }

    function getLastAwardedJackpot()
        external
        view
        returns (
            address lastAwarded,
            uint256 lastAwardedCash,
            uint256 lastAwardedTokens,
            uint256 lastAwardedTimestamp
        )
    {
        return (
            _lastAwarded,
            _lastAwardedCash,
            _lastAwardedTokens,
            _lastAwardedTimestamp
        );
    }

    function getPendingJackpotBalance()
        external
        view
        returns (uint256 pendingJackpotBalance)
    {
        return (_pendingJackpotBalance);
    }

    function getPendingJackpotTokens()
        external
        view
        returns (uint256 pendingJackpotTokens)
    {
        return _jackpotTokens;
    }

    function getLastBigBang()
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (_lastBigBangCash, _lastBigBangTokens, _lastBigBangTimestamp);
    }

    function getJackpot()
        public
        view
        returns (uint256 jackpotTokens, uint256 pendingJackpotAmount)
    {
        return (_jackpotTokens, _pendingJackpotBalance);
    }

    function totalJackpotOut() external view returns (uint256, uint256) {
        return (_totalJackpotCashedOut, _totalJackpotTokensOut);
    }

    function totalJackpotBuyer() external view returns (uint256, uint256) {
        return (_totalJackpotBuyer, _totalJackpotBuyerTokens);
    }

    function totalJackpotBuyback() external view returns (uint256, uint256) {
        return (_totalJackpotBuyback, _totalJackpotBuybackTokens);
    }

    function setMaxSellAtStart(uint256 _maxSellAtStart) external onlyOwner {
        require(_maxSellAtStart <= totalSupply(), "HYC: Max sell at start is over total supply");
        maxSellAtStart = maxSellAtStart;
    }

    function setPumpTime(uint256 _pumpTime) external onlyOwner {
        require(_pumpTime > 0, "HYC: Pump time is zero or less");
        pumptime = _pumpTime;
    }

    function setSwapTokensAtAmount(uint256 amount) external onlyOwner {
        swapTokensAtAmount = amount;
    }

    function setMaxJackpotLimitMultiplier(uint256 _maxJackpotLimitMultiplier)
        external
        onlyOwner
    {
        maxJackpotLimitMultiplier = _maxJackpotLimitMultiplier;
    }

    function setJackpotFee(uint256 value) external onlyOwner {
        jackpotFee = value;
        totalFees = jackpotFee
            .add(liquidityFee)
            .add(buyBackBurnFee)
            .add(devFee)
            .add(communityFee)
            .add(marketingFee);
        require(totalFees <= 25, "Total fee is over 25%");
    }

    function setLiquidityFee(uint256 value) external onlyOwner {
        liquidityFee = value;
        totalFees = liquidityFee
            .add(jackpotFee)
            .add(buyBackBurnFee)
            .add(devFee)
            .add(communityFee)
            .add(marketingFee);
        require(totalFees <= 25, "Total fee is over 25%");
    }

    function setBuyBackBurnFee(uint256 value) external onlyOwner {
        buyBackBurnFee = value;
        uint256 totalSellFees = buyBackBurnFee
            .add(liquidityFee)
            .add(jackpotFee)
            .add(communityFee)
            .add(marketingFee)
            .add(devFee);
        require(totalSellFees <= 25, "Total fee is over 25%");
    }

    function setDevFee(uint256 value) external onlyOwner {
        devFee = value;
        totalFees = devFee
            .add(liquidityFee)
            .add(jackpotFee)
            .add(communityFee)
            .add(marketingFee)
            .add(buyBackBurnFee);
        require(totalFees <= 25, "Total fee is over 25%");
    }

    function setMarketingFee(uint256 value) external onlyOwner {
        marketingFee = value;
        totalFees = devFee
            .add(liquidityFee)
            .add(jackpotFee)
            .add(communityFee)
            .add(buyBackBurnFee)
            .add(marketingFee);
        require(totalFees <= 25, "Total fee is over 25%");
    }

    function setCommunityFee(uint256 value) external onlyOwner {
        communityFee = value;
        totalFees = devFee
            .add(liquidityFee)
            .add(jackpotFee)
            .add(buyBackBurnFee)
            .add(communityFee)
            .add(marketingFee);
        require(totalFees <= 25, "Total fee is over 25%");
    }

    function setJackpotHardBuyback(uint256 _hardBuyback) external onlyOwner {
        jackpotHardBuyback = _hardBuyback;
    }

    function setDevWallet(address _devWallet) external onlyOwner {
        devWallet = _devWallet;
    }

    function setCommunityWallet(address _communityWallet) external onlyOwner {
        communityWallet = _communityWallet;
    }

    function setMarketingWallet(address _marketingWallet) external onlyOwner {
        marketingWallet = _marketingWallet;
    }

    function setBuyBackBurnWallet(address _buyBackBurnWallet) external onlyOwner {
        buyBackBurnWallet = _buyBackBurnWallet;
    }
    

    function setJackpotMinBuy(uint256 _minBuy) external onlyOwner {
        jackpotMinBuy = _minBuy;
    }

    function setJackpotTimespan(uint256 _timespan) external onlyOwner {
        jackpotTimespan = _timespan;
    }

    function setJackpotHardLimit(uint256 _hardlimit) external onlyOwner {
        jackpotHardLimit = _hardlimit;
    }

    function shouldAwardJackpot() public view returns (bool) {
        return
            _lastBuyer != address(0) &&
            _lastBuyer != address(this) &&
            block.timestamp.sub(_lastBuyTimestamp) >= jackpotTimespan;
    }

    function isJackpotEligible(uint256 tokenAmount) public view returns (bool) {
        if (jackpotMinBuy == 0) {
            return true;
        }
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        uint256 tokensOut = uniswapV2Router
        .getAmountsOut(jackpotMinBuy, path)[1].mul(MAX_PCT.sub(ROUTER_FEE)).div(
                // We don't subtract the buy fee since the tokenAmount is pre-tax
                MAX_PCT
            );
        return tokenAmount >= tokensOut;
    }

    function processBigBang() internal lockTheSwap {
        uint256 cashedOut = _pendingJackpotBalance.mul(jackpotHardBuyback).div(
            MAX_PCT
        );
        uint256 tokensOut = _jackpotTokens.mul(jackpotHardBuyback).div(MAX_PCT);
        _lastBigBangTokens = tokensOut;

        payable(buyBackBurnWallet).transfer(cashedOut);
        super._transfer(address(this), buyBackBurnWallet, tokensOut);

        emit BigBang(cashedOut, tokensOut);

        _lastBigBangCash = cashedOut;
        _lastBigBangTimestamp = block.timestamp;

        _pendingJackpotBalance = _pendingJackpotBalance.sub(cashedOut);
        _jackpotTokens = _jackpotTokens;

        _totalJackpotCashedOut = _totalJackpotCashedOut.add(cashedOut);
        _totalJackpotBuyback = _totalJackpotBuyback.add(cashedOut);
        _totalJackpotTokensOut = _totalJackpotTokensOut.add(tokensOut);
        _totalJackpotBuybackTokens = _totalJackpotBuybackTokens.add(tokensOut);
    }

    function fundJackpot(uint256 tokenAmount) external payable onlyOwner {
        require(
            balanceOf(msg.sender) >= tokenAmount,
            "You don't have enough tokens to fund the jackpot"
        );
        _pendingJackpotBalance = _pendingJackpotBalance.add(msg.value);
        if (tokenAmount > 0) {
            super._transfer(msg.sender, address(this), tokenAmount);
            _jackpotTokens = _jackpotTokens.add(tokenAmount);
        }

        emit JackpotFund(msg.value, tokenAmount);
    }

    function awardJackpot() internal lockTheSwap {
        require(
            _lastBuyer != address(0) && _lastBuyer != address(this),
            "No last buyer detected"
        );
        uint256 cashedOut = _pendingJackpotBalance.mul(jackpotCashout).div(
            MAX_PCT
        );

        uint256 tokensOut = _jackpotTokens.mul(jackpotCashout).div(MAX_PCT);
        uint256 buyerShare = cashedOut.mul(jackpotBuyerShare).div(MAX_PCT);
        uint256 tokensToBuyer = tokensOut.mul(jackpotBuyerShare).div(MAX_PCT);
        uint256 toBuyback = cashedOut - buyerShare;
        uint256 tokensToBuyback = tokensOut - tokensToBuyer;

        payable(_lastBuyer).transfer(buyerShare);
        super._transfer(address(this), _lastBuyer, tokensToBuyer);
        payable(buyBackBurnWallet).transfer(toBuyback);
        super._transfer(address(this), buyBackBurnWallet, tokensToBuyback);

        _pendingJackpotBalance = _pendingJackpotBalance.sub(cashedOut);
        _jackpotTokens = _jackpotTokens.sub(tokensOut);

        _lastAwarded = _lastBuyer;
        _lastAwardedCash = cashedOut;
        _lastAwardedTimestamp = block.timestamp;
        _lastAwardedTokens = tokensToBuyer;

        emit JackpotAwarded(_lastBuyer, cashedOut);

        _lastBuyer = payable(address(this));
        _lastBuyTimestamp = 0;

        _totalJackpotCashedOut = _totalJackpotCashedOut.add(cashedOut);
        _totalJackpotTokensOut = _totalJackpotTokensOut.add(tokensOut);
        _totalJackpotBuyer = _totalJackpotBuyer.add(buyerShare);
        _totalJackpotBuyerTokens = _totalJackpotBuyerTokens.add(tokensToBuyer);
        _totalJackpotBuyback = _totalJackpotBuyback.add(toBuyback);
        _totalJackpotBuybackTokens = _totalJackpotBuybackTokens.add(
            tokensToBuyback
        );
    }

    function updateUniswapV2Router(address newAddress) public onlyOwner {
        require(
            newAddress != address(uniswapV2Router),
            "HYC: The router already has that address"
        );
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
        address _uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());
        uniswapV2Pair = _uniswapV2Pair;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(
            _isExcludedFromFees[account] != excluded,
            "HYC: Account is already the value of 'excluded'"
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

    function setAutomatedMarketMakerPair(address pair, bool value)
        public
        onlyOwner
    {
        require(
            pair != uniswapV2Pair,
            "HYC: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(
            automatedMarketMakerPairs[pair] != value,
            "HYC: Automated market maker pair is already set to that value"
        );
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
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

        uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if (
            canSwap &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            from != owner() &&
            to != owner()
        ) {
            swapping = true;
            uint256 swapTokens = contractTokenBalance.mul(liquidityFee).div(
                totalFees
            );
            swapAndLiquify(swapTokens);

            uint256 balanceBefore = address(this).balance;
            swapTokensForEth(contractTokenBalance.sub(swapTokens));
            uint256 totalFeesExceptLiquid = totalFees.sub(liquidityFee);

            uint256 amountBnbReceived = address(this).balance.sub(
                balanceBefore
            );
            payable(devWallet).transfer(
                amountBnbReceived.mul(devFee).div(totalFeesExceptLiquid)
            );
            emit DevFeeSent(
                devWallet,
                amountBnbReceived.mul(devFee).div(totalFeesExceptLiquid)
            );
            payable(communityWallet).transfer(
                amountBnbReceived.mul(communityFee).div(totalFeesExceptLiquid)
            );
            emit CommunityFeeSent(
                communityWallet,
                amountBnbReceived.mul(communityFee).div(totalFeesExceptLiquid)
            );
            payable(buyBackBurnWallet).transfer(
                amountBnbReceived.mul(buyBackBurnFee).div(totalFeesExceptLiquid)
            );
            emit BuyBackBurnFeeSent(
                buyBackBurnWallet,
                amountBnbReceived.mul(buyBackBurnFee).div(totalFeesExceptLiquid)
            );
            payable(marketingWallet).transfer(
                amountBnbReceived.mul(marketingFee).div(totalFeesExceptLiquid)
            );
            emit MarketingFeeSent(
                marketingWallet,
                amountBnbReceived.mul(marketingFee).div(totalFeesExceptLiquid)
            );
            uint256 amountToFundJackpot = amountBnbReceived.mul(jackpotFee).div(
                totalFeesExceptLiquid
            );
            _jackpotTokens = 0;
            _pendingJackpotBalance = _pendingJackpotBalance.add(
                amountToFundJackpot
            );
            emit JackpotFund(amountToFundJackpot, 0);

            swapping = false;
        }

        if (_pendingJackpotBalance >= jackpotHardLimit) {
            processBigBang();
        } else if (shouldAwardJackpot()) {
            awardJackpot();
        }

        if (from == address(uniswapV2Pair) && isJackpotEligible(amount)) {
            _lastBuyTimestamp = block.timestamp;
            _lastBuyer = to;
        }

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if (
            takeFee &&
            (automatedMarketMakerPairs[from] || automatedMarketMakerPairs[to])
        ) {
            require(tradingOpen, "HYC: Trading is not open");
            uint256 totalFeesTokens = amount.mul(totalFees).div(FEE_DENOMINATOR);
            if (block.number - launchedAt <= 3) {
                totalFeesTokens = amount.mul(8000).div(FEE_DENOMINATOR);
            } else {
                if (automatedMarketMakerPairs[to]) {
                    if (block.number - launchedAt <= pumptime) {
                        require(amount < maxSellAtStart, "dont dump");
                        totalFeesTokens = amount.mul(600).div(FEE_DENOMINATOR);
                    }
                }
            }
            _jackpotTokens = _jackpotTokens.add(
                totalFeesTokens.mul(jackpotFee).div(totalFees)
            );

            amount = amount.sub(totalFeesTokens);
            super._transfer(from, address(this), totalFeesTokens);
        }

        super._transfer(from, to, amount);
    }

    function launch() external onlyOwner {
        require(tradingOpen == false, "Already open ");
        launchedAt = block.number;
        tradingOpen = true;
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

        emit SwapAndLiquify(half, newBalance, otherHalf);
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
            address(0),
            block.timestamp
        );
    }

    function burn(uint256 amount) public {
        require(
            balanceOf(msg.sender) >= amount,
            "ERC20: burn: insufficient balance"
        );
        super._burn(msg.sender, amount);
    }

    receive() external payable {}
}
