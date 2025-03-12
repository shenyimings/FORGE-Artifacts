/**

                                        &@@@@@@@@@@@@@@@@@@@%                                       
                                 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                                
                            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                           
                        @@@@@@@@@@@@@@@@@@@@(***********#@@@@@@@@@@@@@@@@@@@@                       
                     @@@@@@@@@@@@@@@*****************************@@@@@@@@@@@@@@@                    
                   @@@@@@@@@@@@@@@@@**************************@@@@@@@@@@@@@@@@@@@@                  
                *@@@@@@@@@@@@@@@@@@@************************@@@@@@@@@@@@@@@@@@@@@@@@                
               @@@@@@@@@@**@@@@@@@@@*****################@@@@@@@@@@@@@******@@@@@@@@@@              
             @@@@@@@@@@****@@@@@@@@@###################@@@@@@@@@@@@@**********@@@@@@@@@@            
            @@@@@@@@@******@@@@@@@@@################&@@@@@@@@@@@@#####**********@@@@@@@@@           
          &@@@@@@@@&///////@@@@@@@@@##############@@@@@@@@@@@@@##########********@@@@@@@@@/         
         @@@@@@@@@////////#@@@@@@@@@###########%@@@@@@@@@@@@%##############////////@@@@@@@@/        
         @@@@@@@@///////###@@@@@@@@@###########@@@@@@@@@@@###################///////@@@@@@@@        
        @@@@@@@@//////#####@@@@@@@@@###########@@@@@@@@@#######################/////(@@@@@@@@       
       &@@@@@@@@/////######@@@@@@@@@###########@@@@@@#######@@@@@@@@@@@@@#######/////@@@@@@@@/      
       @@@@@@@@/////#######@@@@@@@@@###########@@@@#######@@@@@@@@@@@@%##########/////@@@@@@@@      
       @@@@@@@@////########@@@@@@@@@###########@########@@@@@@@@@@@@##############////@@@@@@@@      
       @@@@@@@@////########@@@@@@@@@@@###############@@@@@@@@@@@@@################////@@@@@@@@      
       @@@@@@@@///#########@@@@@@@@@@@@@@##########@@@@@@@@@@@@##########@#########///@@@@@@@@      
       @@@@@@@@///############@@@@@@@@@@@@@@@###&@@@@@@@@@@@@#########@@@@#########//(@@@@@@@@      
       %@@@@@@@@//###############@@@@@@@@@@@@@@@@@@@@@@@@@##########@@@@@@#########//@@@@@@@@,      
        @@@@@@@@(/(((((((((((((((((((@@@@@@@@@@@@@@@@@@@(((((((((&@@@@@@@@(((((((((/%@@@@@@@@       
         @@@@@@@@//(((((((((((((((((((((@@@@@@@@@@@@@@(((((((((((@@@@@@@@@((((((((//@@@@@@@@        
         &@@@@@@@@/((((((((((((((@(((((((((@@@@@@@@((((((((((((((@@@@@@@@@((((((((/@@@@@@@@,        
          #@@@@@@@@@(((((((((((((@@@@#((((((((%@@((((((((((((((((@@@@@@@@@(((((((@@@@@@@@@,         
            @@@@@@@@@((((((((((((@@@@@@@@((((((((((((((((((((((((@@@@@@@@@((((((@@@@@@@@@           
             @@@@@@@@@@((((((((((@@@@@@@@@(((((((((((((((((((((((@@@@@@@@@((((@@@@@@@@@@            
               @@@@@@@@@@///////(@@@@@@@@@///////////////////////@@@@@@@@@/(@@@@@@@@@@              
                .@@@@@@@@@@@/////@@@@@@@@@///////////////////////@@@@@@@@@@@@@@@@@@@                
                   @@@@@@@@@@@@&/@@@@@@@@@///////////////////////@@@@@@@@@@@@@@@@@                  
                     @@@@@@@@@@@@@@@@@@@@@//////////////////////(@@@@@@@@@@@@@@&                    
                        &@@@@@@@@@@@@@@@@@@@@///////////@@@@@@@@@@@@@@@@@@@@#                       
                            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                           
                                 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                                
                                        *@@@@@@@@@@@@@@@@@@@.                                       
                                                                                                    

🌐 https://metaglx.com/
💬 https://telegram.me/MetaGLX
💻 https://discord.gg/uEwGcHPZRQ
🐤 https://twitter.com/MetaGLX

*/


// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.6;

import "./DividendPayingToken.sol";
import "./SafeMath.sol";
import "./IterableMapping.sol";
import "./Ownable.sol";
import "./IDex.sol";


contract MetaGLX is ERC20, Ownable {
    using SafeMath for uint256;

    IRouter public router;
    address public  pair;
    
    address constant public prizePoolWallet = 0x29Be9131198B23fae0241a300F768168cd496052;

    address public immutable BUSD = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
        
    bool private swapping;    
    bool public swapEnabled = true;
    bool public autoBoostEnabled = false;
    
    uint256 public autoBoostThreshold = 1 ether; //initially set to 1 BNB

    MetaGLXDividendTracker public dividendTracker;

    uint256 public swapTokensAtAmount = 50000000 * 10**decimals();
    uint256 public maxWalletBalance = 2e13 * 10**decimals();  // 2% of total supply
    uint256 public maxTxAmount = 5e12 * 10**decimals();    // 0.5% of total supply

    uint256 public  BUSDRewardsFee = 50;
    uint256 public  marketingFee = 20;
    uint256 public  iBNBFee = 20;
    uint256 public  liquidityFee = 20;
    uint256 public  prizePoolFee = 30;
    uint256 public  autoBoost = 0;
    uint256 public  totalFees = BUSDRewardsFee.add(marketingFee).add(iBNBFee).add(liquidityFee).add(autoBoost);
    
    address public marketingWallet = 0x59561a4d664220408d3F4eA023Ada69D759c84e6;
    address public iBNBWallet = 0x2Dda7c99973Cba879ed67601F7bf65316874A7a7;
    address public liquidityWallet = 0x195cAc6c953032c11498717106E8726efE81929D;
    address public nullAddress = 0x000000000000000000000000000000000000dEaD;
    
    // use by default 300,000 gas to process auto-claiming dividends
    uint256 public gasForProcessing = 300000;

    mapping (address => bool) private _isExcludedFromFees;
    mapping (address => bool) public _isBlacklisted;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping (address => bool) public automatedMarketMakerPairs;

    event UpdateDividendTracker(address indexed newAddress, address indexed oldAddress);

    event Updaterouter(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event SwapETHForTokens(
        uint256 amountIn,
        address[] path
    );

    event SendDividends(
        uint256 tokensSwapped,
        uint256 amount
    );

    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

     modifier lockTheSwap {
        swapping = true;
        _;
        swapping = false;
    }

    constructor()  ERC20("MetaGLX", "MGLX") {
        
        dividendTracker = new MetaGLXDividendTracker();

        IRouter _router = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
         // Create a Pancakeswap pair for this new token
        address _pair = IFactory(_router.factory())
            .createPair(address(this), _router.WETH());

        router = _router;
        pair = _pair;

        _setAutomatedMarketMakerPair(_pair, true);

        // exclude from receiving dividends
        dividendTracker.excludeFromDividends(address(dividendTracker), true);
        dividendTracker.excludeFromDividends(owner(), true);
        dividendTracker.excludeFromDividends(address(this), true);
        dividendTracker.excludeFromDividends(prizePoolWallet, true);
        dividendTracker.excludeFromDividends(nullAddress, true);

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(prizePoolWallet, true);
        excludeFromFees(nullAddress, true);
        excludeFromFees(marketingWallet, true);
        excludeFromFees(iBNBWallet, true);

        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(owner(), 1e15 * (10**9));
    }

    receive() external payable {

    }


    function updateDividendTracker(address newAddress) public onlyOwner {
        require(newAddress != address(dividendTracker), "MetaGLX: The dividend tracker already has that address");

        MetaGLXDividendTracker newDividendTracker = MetaGLXDividendTracker(payable(newAddress));

        require(newDividendTracker.owner() == address(this), "MetaGLX: The new dividend tracker must be owned by the MetaGLX token contract");

        newDividendTracker.excludeFromDividends(address(newDividendTracker), true);
        newDividendTracker.excludeFromDividends(owner(), true);
        newDividendTracker.excludeFromDividends(address(this), true);
        newDividendTracker.excludeFromDividends(prizePoolWallet, true);
        newDividendTracker.excludeFromDividends(nullAddress, true);
        newDividendTracker.excludeFromDividends(address(router), true);

        emit UpdateDividendTracker(newAddress, address(dividendTracker));

        dividendTracker = newDividendTracker;
    }

    function updateRouter(address newAddress) public onlyOwner {
        require(newAddress != address(router), "MetaGLX: The router already has that address");
        emit Updaterouter(newAddress, address(router));
        router = IRouter(newAddress);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromFees[account] != excluded, "MetaGLX: Account is already the value of 'excluded'");
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function setAutomatedMarketMakerPair(address newPair, bool value) public onlyOwner {
        _setAutomatedMarketMakerPair(newPair, value);
    }

    function excludeFromDividends(address account, bool value) external onlyOwner{
        dividendTracker.excludeFromDividends(account, value);
    }

    function _setAutomatedMarketMakerPair(address newPair, bool value) private {
        require(automatedMarketMakerPairs[newPair] != value, "MetaGLX: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[newPair] = value;

        if(value) {
            dividendTracker.excludeFromDividends(newPair, value);
        }

        emit SetAutomatedMarketMakerPair(newPair, value);
    }

    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        require(newValue >= 200000 && newValue <= 500000, "MetaGLX: gasForProcessing must be between 200,000 and 500,000");
        require(newValue != gasForProcessing, "MetaGLX: Cannot update gasForProcessing to same value");
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function updateClaimWait(uint256 claimWait) external onlyOwner {
        dividendTracker.updateClaimWait(claimWait);
    }

    function getClaimWait() external view returns(uint256) {
        return dividendTracker.claimWait();
    }

    function getMinimumBalanceForRewards() external view returns(uint256) {
        return dividendTracker.minimumTokenBalanceForDividends();
    }

    function isExcludedFromDividends(address account) public view returns(bool) {
        return dividendTracker.excludedFromDividends(account);
    }

    function getTotalDividendsDistributed() external view returns (uint256) {
        return dividendTracker.totalDividendsDistributed();
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }

    function withdrawableDividendOf(address account) public view returns(uint256) {
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
            uint256,
            uint256,
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
            uint256,
            uint256,
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
    
    function setFees(uint256 _BUSDFee, uint256 _marketFee, uint256 _iBNBFee, uint256 _liqFee, uint256 _autoBoostFee, uint256 _prizePoolFee) external onlyOwner{
        require(_BUSDFee + _marketFee + _liqFee + _autoBoostFee <= 350, "Fees must be <= 35%");
        BUSDRewardsFee = _BUSDFee;
        marketingFee = _marketFee;
        iBNBFee = _iBNBFee;
        liquidityFee = _liqFee;
        autoBoost = _autoBoostFee;
        prizePoolFee = _prizePoolFee;
        totalFees = BUSDRewardsFee + marketingFee + iBNBFee + liquidityFee + autoBoost;
    }
    
    function setMarketingWallet(address newWallet) external onlyOwner{
        marketingWallet = newWallet;
    }

    function setiBNBWallet(address newWallet) external onlyOwner{
        iBNBWallet = newWallet;
    }
    
    function setLiquidityWallet(address newWallet) external onlyOwner{
        liquidityWallet = newWallet;
    }
    
    function setSwapTokensAtAmount(uint256 amount) external onlyOwner{
        swapTokensAtAmount = amount * 10**decimals();
    }
    
    function setMaxWalletBalance(uint256 amount) external onlyOwner{
        maxWalletBalance = amount * 10**decimals();
    }
    
    function setMinTokensToGetrewards(uint256 amount) external onlyOwner{
        dividendTracker.setMinimumBalanceForRewards(amount * 10**decimals());
    }
    
    function setBlacklistAccount(address account, bool state) external onlyOwner{
        require(_isBlacklisted[account] != state, "Value already set");
        _isBlacklisted[account] = state;
    }
    
    function setMaxTxAmount(uint256 amount) external onlyOwner{
        require(amount > 200_000 * 10**decimals(), "Amount must be > 200M");
        maxTxAmount = amount * 10**decimals();
    }

    function setSwapEnabled(bool value) external onlyOwner{
        swapEnabled = value;
    }
    
    function setAutoBoostEnabled(bool value) external onlyOwner{
        autoBoostEnabled = value;
    }
    
    function setAutoBoostThreshold(uint256 amount) external onlyOwner{
        autoBoostThreshold = amount * 10**18;
    }
    
    function rescueBNB(uint256 weiAmount) external onlyOwner{
        require(address(this).balance >= weiAmount, "Insufficient BNB");
        payable(msg.sender).transfer(weiAmount);
    }
    
    function rescueBEP20(address tokenAdd, uint256 amount) external onlyOwner{
        IERC20(tokenAdd).transfer(msg.sender, amount);
    }
    
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(!_isBlacklisted[from] && !_isBlacklisted[to], "You are blacklisted");
        
        if(!automatedMarketMakerPairs[to] && !_isExcludedFromFees[from] && !_isExcludedFromFees[to] && to != nullAddress){
            require(balanceOf(to).add(amount) <= maxWalletBalance, "Balance is exceeding maxWalletBalance");
        }
        
        if(!_isExcludedFromFees[from] && !_isExcludedFromFees[to]){
            require(amount <= maxTxAmount, "Amount is exceeding maxTxAmount");
        }
        
        if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        if(swapEnabled && !swapping && !automatedMarketMakerPairs[from] && !_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            uint256 balance = address(this).balance;
            if (automatedMarketMakerPairs[to] && autoBoostEnabled && balance >= autoBoostThreshold) {
                triggerAutoBoost(autoBoostThreshold);
            }
            
            bool canSwap = contractTokenBalance >= swapTokensAtAmount;
            
            if (canSwap) {
                swapAndLiquify(swapTokensAtAmount.mul(totalFees - BUSDRewardsFee).div(totalFees));

                if(BUSDRewardsFee > 0){
                    uint256 sellTokens = swapTokensAtAmount.mul(BUSDRewardsFee).div(totalFees);
                    swapAndSendDividends(sellTokens);
                }
            }

        }

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }
        

        if(takeFee) {
            uint256 fees = amount * totalFees / 1000;
            uint256 prizePoolAmt = amount * prizePoolFee / 1000;
            
            amount = amount.sub(fees).sub(prizePoolAmt);
            super._transfer(from, address(this), fees);
            super._transfer(from, prizePoolWallet, prizePoolAmt);
        }
        super._transfer(from, to, amount);

        try dividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
        try dividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}

        if(!swapping) {
            uint256 gas = gasForProcessing;

            try dividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
                emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
            }
            catch {

            }
        }
    }
    
    function triggerAutoBoost(uint256 amount) private lockTheSwap{
        if (amount > 0) {
            swapETHForTokens(amount);
        }
    }
    
    function swapAndLiquify(uint256 tokens) private lockTheSwap{
        // Split the contract balance into halves
        uint256 denominator = (liquidityFee + marketingFee + iBNBFee + autoBoost) * 2;
        uint256 tokensToAddLiquidityWith = tokens * liquidityFee / denominator;
        uint256 toSwap = tokens - tokensToAddLiquidityWith;

        uint256 initialBalance = address(this).balance;

        swapTokensForEth(toSwap);

        uint256 deltaBalance = address(this).balance - initialBalance;
        uint256 unitBalance= deltaBalance / (denominator - liquidityFee);
        uint256 BNBToAddLiquidityWith = unitBalance * liquidityFee;

        if(BNBToAddLiquidityWith > 0){
            // Add liquidity to pancakeswap
            addLiquidity(tokensToAddLiquidityWith, BNBToAddLiquidityWith);
        }

        // Send BNB to marketing wallet
        uint256 marketingAmt = unitBalance * 2 * marketingFee;
        if(marketingAmt > 0) payable(marketingWallet).transfer(marketingAmt);

        // Send BNB to iBNB wallet
        uint256 iBNBAmt = unitBalance * 2 * iBNBFee;
        if(iBNBAmt > 0) payable(iBNBWallet).transfer(iBNBAmt);
    }
    
    function swapETHForTokens(uint256 amount) private {
        // generate the pancakeswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(this);
 
      // make the swap
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            prizePoolWallet, // prizePool address
            block.timestamp.add(300)
        );
 
        emit SwapETHForTokens(amount, path);
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {

        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(router), tokenAmount);

        // add the liquidity
        router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            liquidityWallet, 
            block.timestamp
        );

    }

    function swapTokensForEth(uint256 tokenAmount) private {

        // generate the pancakeswap pair path of token -> weth
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
    function swapTokensForBUSD(uint256 tokenAmount) private {

        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = router.WETH();
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

    function swapAndSendDividends(uint256 tokens) private lockTheSwap{
        swapTokensForBUSD(tokens);
        uint256 dividends = IERC20(BUSD).balanceOf(address(this));
        bool success = IERC20(BUSD).transfer(address(dividendTracker), dividends);

        if (success) {
            dividendTracker.distributeBUSDDividends(dividends);
            emit SendDividends(tokens, dividends);
        }
    }
}

contract MetaGLXDividendTracker is Ownable, DividendPayingToken {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using IterableMapping for IterableMapping.Map;

    IterableMapping.Map private tokenHoldersMap;
    uint256 public lastProcessedIndex;

    mapping (address => bool) public excludedFromDividends;

    mapping (address => uint256) public lastClaimTimes;

    uint256 public claimWait;
    uint256 public minimumTokenBalanceForDividends;

    event ExcludeFromDividends(address indexed account);
    event ClaimWaitUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event Claim(address indexed account, uint256 amount, bool indexed automatic);

    constructor()  DividendPayingToken("MetaGLX_Dividend_Tracker", "MetaGLX_Dividend_Tracker") {
        claimWait = 3600;
        minimumTokenBalanceForDividends = 10e9 * (10**9); //must hold 10,000,000,000 tokens
    }

    function _transfer(address, address, uint256) internal pure override{
        require(false, "MetaGLX_Dividend_Tracker: No transfers allowed");
    }

    function withdrawDividend() public pure override {
        require(false, "MetaGLX_Dividend_Tracker: withdrawDividend disabled. Use the 'claim' function on the main MetaGLX contract.");
    }

    function excludeFromDividends(address account, bool value) external onlyOwner {
        require(excludedFromDividends[account] != value);
        excludedFromDividends[account] = value;
      if(value == true){
        _setBalance(account, 0);
        tokenHoldersMap.remove(account);
      }
      else{
        _setBalance(account, balanceOf(account));
        tokenHoldersMap.set(account, balanceOf(account));
      }
    }

    function updateClaimWait(uint256 newClaimWait) external onlyOwner {
        require(newClaimWait >= 3600 && newClaimWait <= 86400, "MetaGLX_Dividend_Tracker: claimWait must be updated to between 1 and 24 hours");
        require(newClaimWait != claimWait, "MetaGLX_Dividend_Tracker: Cannot update claimWait to same value");
        emit ClaimWaitUpdated(newClaimWait, claimWait);
        claimWait = newClaimWait;
    }
    
    function setMinimumBalanceForRewards(uint256 amount) external onlyOwner{
        minimumTokenBalanceForDividends = amount;
    }

    function getLastProcessedIndex() external view returns(uint256) {
        return lastProcessedIndex;
    }

    function getNumberOfTokenHolders() external view returns(uint256) {
        return tokenHoldersMap.keys.length;
    }

    function getAccount(address _account)
        public view returns (
            address account,
            int256 index,
            int256 iterationsUntilProcessed,
            uint256 withdrawableDividends,
            uint256 totalDividends,
            uint256 lastClaimTime,
            uint256 nextClaimTime,
            uint256 secondsUntilAutoClaimAvailable) {
        account = _account;

        index = tokenHoldersMap.getIndexOfKey(account);

        iterationsUntilProcessed = -1;

        if(index >= 0) {
            if(uint256(index) > lastProcessedIndex) {
                iterationsUntilProcessed = index.sub(int256(lastProcessedIndex));
            }
            else {
                uint256 processesUntilEndOfArray = tokenHoldersMap.keys.length > lastProcessedIndex ?
                                                        tokenHoldersMap.keys.length.sub(lastProcessedIndex) :
                                                        0;


                iterationsUntilProcessed = index.add(int256(processesUntilEndOfArray));
            }
        }


        withdrawableDividends = withdrawableDividendOf(account);
        totalDividends = accumulativeDividendOf(account);

        lastClaimTime = lastClaimTimes[account];

        nextClaimTime = lastClaimTime > 0 ?
                                    lastClaimTime.add(claimWait) :
                                    0;

        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ?
                                                    nextClaimTime.sub(block.timestamp) :
                                                    0;
    }

    function getAccountAtIndex(uint256 index)
        public view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
        if(index >= tokenHoldersMap.size()) {
            return (0x0000000000000000000000000000000000000000, -1, -1, 0, 0, 0, 0, 0);
        }

        address account = tokenHoldersMap.getKeyAtIndex(index);

        return getAccount(account);
    }

    function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
        if(lastClaimTime > block.timestamp)  {
            return false;
        }

        return block.timestamp.sub(lastClaimTime) >= claimWait;
    }

    function setBalance(address payable account, uint256 newBalance) external onlyOwner {
        if(excludedFromDividends[account]) {
            return;
        }

        if(newBalance >= minimumTokenBalanceForDividends) {
            _setBalance(account, newBalance);
            tokenHoldersMap.set(account, newBalance);
        }
        else {
            _setBalance(account, 0);
            tokenHoldersMap.remove(account);
        }

        processAccount(account, true);
    }

    function process(uint256 gas) public returns (uint256, uint256, uint256) {
        uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;

        if(numberOfTokenHolders == 0) {
            return (0, 0, lastProcessedIndex);
        }

        uint256 _lastProcessedIndex = lastProcessedIndex;

        uint256 gasUsed = 0;

        uint256 gasLeft = gasleft();

        uint256 iterations = 0;
        uint256 claims = 0;

        while(gasUsed < gas && iterations < numberOfTokenHolders) {
            _lastProcessedIndex++;

            if(_lastProcessedIndex >= tokenHoldersMap.keys.length) {
                _lastProcessedIndex = 0;
            }

            address account = tokenHoldersMap.keys[_lastProcessedIndex];

            if(canAutoClaim(lastClaimTimes[account])) {
                if(processAccount(payable(account), true)) {
                    claims++;
                }
            }

            iterations++;

            uint256 newGasLeft = gasleft();

            if(gasLeft > newGasLeft) {
                gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
            }

            gasLeft = newGasLeft;
        }

        lastProcessedIndex = _lastProcessedIndex;

        return (iterations, claims, lastProcessedIndex);
    }

    function processAccount(address payable account, bool automatic) public onlyOwner returns (bool) {
        uint256 amount = _withdrawDividendOfUser(account);

        if(amount > 0) {
            lastClaimTimes[account] = block.timestamp;
            emit Claim(account, amount, automatic);
            return true;
        }

        return false;
    }
}
