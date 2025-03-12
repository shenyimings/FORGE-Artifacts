// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./ERC20Dividends.sol";
import "./IUniswapV2Router02.sol";
import "./IUniswapV2Factory.sol";

contract PlayHub is ERC20Dividends, Pausable, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    mapping(address => bool) public _isAllowedDuringDisabled;
    mapping(address => bool) public _isIgnoredAddress;

    // Anti-bot and anti-whale mappings and variables for launch
    mapping(address => uint256) private _holderLastTransferTimestamp; // to hold last Transfers temporarily during launch
    bool public transferDelayEnabled = true;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping (address => bool) public ammPairs;

    // exlcude from fees and max transaction amount
    mapping (address => bool) private _isExcludedFromFees;

    // to track last sell to reduce sell penalty over time by 10% per week the holder sells *no* tokens.
    mapping (address => uint256) public _holderLastSellDate;

    uint256 public maxSellTransactionAmount; /// MAX TRANSACTION that can be sold

    uint256 public _maxSellPercent = 99; // Set the maximum percent allowed on sale per a single transaction

    uint256 public _sellFeeLiquidity = 2; // in percent
    uint256 public _sellFeeDividends = 3; // in percent
    uint256 public _sellFeeOperations = 3; // in percent
    uint256 public _sellFeeBurn = 2; // in percent

    uint256 public _buyFeeLiquidity = 2; // in percent
    uint256 public _buyFeeDividends = 4; // in percent
    uint256 public _buyFeeOperations = 4; // in percent
    uint256 public _buyFeeBurn = 0; // in percent

    // trackers for contract Tokens
    uint256 public tokensLiquidity = 0;
    uint256 public tokensOperations = 0;
    uint256 public ethOperations = 0;

    address public liquidityWallet;
    address public operationsWallet;

    bool public isOperationsETH = false;
    bool public isETHCollecting = false;
    uint256 public minETHToTransfer = 10**17; // 0.1 BNB

    bool private processing = false;

    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event LiquidityWalletUpdated(address indexed newLiquidityWallet, address indexed oldLiquidityWallet);
    event OperationsWalletUpdated(address indexed newLiquidityWallet, address indexed oldLiquidityWallet);

    event BuyFeesUpdated(uint256 newLiquidityFee, uint256 newDividendsFee, uint256 newOperationsFee, uint256 newBurnFee);
    event SellFeesUpdated(uint256 newLiquidityFee, uint256 newDividendsFee, uint256 newOperationsFee, uint256 newBurnFee);

    event BurnFeeUpdated(uint256 newFee, uint256 oldFee);

    event Received(address indexed sender, uint256 value);

    event TradeAttemptOnInitialLocked(address indexed from, address indexed to, uint256 amount);

    // event ProcessLiquidity(
    //     uint256 tokensSwapped,
    //     uint256 ethReceived,
    //     uint256 tokensIntoLiqudity
    // );

    // event ProcessOperations(
    //     uint256 tokensSwapped,
    //     uint256 ethReceived,
    //     uint256 tokensIntoLiqudity
    // );

    constructor() ERC20("PlayHub", "PLH") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(MODERATOR_ROLE, _msgSender());

        liquidityWallet = _msgSender();
        operationsWallet = _msgSender();

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // Mainnet 
        // IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1); // Testnet 

         // Create a uniswap pair for this new token
        // address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        //     .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        // uniswapV2Pair = _uniswapV2Pair;

        // _setEnabledAMMPair(_uniswapV2Pair, true);

        _dividendsClaimWait = 3600;

        // exclude from receiving dividends
        super._excludeFromDividends(address(this));
        super._excludeFromDividends(liquidityWallet);
        super._excludeFromDividends(address(0x000000000000000000000000000000000000dEaD)); // dead address should NOT take tokens!!!
        super._excludeFromDividends(address(_uniswapV2Router));

        // exclude from paying fees or having max transaction amount
        excludeFromFees(_msgSender(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(liquidityWallet), true);
        excludeFromFees(address(operationsWallet), true);
        
        _isAllowedDuringDisabled[address(this)] = true;
        _isAllowedDuringDisabled[_msgSender()] = true;
        _isAllowedDuringDisabled[liquidityWallet] = true;
        _isAllowedDuringDisabled[address(uniswapV2Router)] = true;

        _mint(msg.sender, 1 * 10 ** 9 * 10 ** decimals());

        _minimumBalanceForDividends = totalSupply() / 100000;
        maxSellTransactionAmount = totalSupply() / 1000;

        _pause();
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function pause() public onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function _burn(address account, uint256 amount) internal override {
        require(account != address(0), "ERC20: burn from the zero address");
        _beforeTokenTransfer(account, address(0), amount);
        super._transfer(account, address(0), amount);
        emit Transfer(account, address(0), amount);
        _afterTokenTransfer(account, address(0), amount);
    }

    // @dev ADMIN start -------------------------------------
    
    // remove transfer delay after launch
    function disableTransferDelay() external onlyRole(ADMIN_ROLE) {
        transferDelayEnabled = false;
    }
    
    // updates the maximum amount of tokens that can be bought or sold by holders
    function updateMaxTxn(uint256 maxTxnAmount) external onlyRole(ADMIN_ROLE) {
        maxSellTransactionAmount = maxTxnAmount;
    }

    // updates the default router for selling tokens
    function updateUniswapV2Router(address newAddress) external onlyRole(ADMIN_ROLE) {
        require(newAddress != address(uniswapV2Router), "The router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
    }

    // excludes wallets from max txn and fees.
    function excludeFromFees(address account, bool excluded) public onlyRole(MODERATOR_ROLE) {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    // allows multiple exclusions at once
    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) external onlyRole(MODERATOR_ROLE) {
        for(uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }
    
    function addToWhitelist(address wallet, bool status) external onlyRole(MODERATOR_ROLE) {
        _isAllowedDuringDisabled[wallet] = status;
    }
    
    function setIsBot(address wallet, bool status) external onlyRole(MODERATOR_ROLE) {
        _isIgnoredAddress[wallet] = status;
    }
    
    // allow adding additional AMM pairs to the list
    function setEnabledAMMPair(address pair, bool value) external onlyRole(ADMIN_ROLE) {
        require(pair != uniswapV2Pair, "The PancakeSwap pair cannot be removed from market maker pairs");
        _setEnabledAMMPair(pair, value);
    }
    
    // sets the wallet that receives LP tokens to lock
    function updateLiquidityWallet(address newLiquidityWallet) external onlyRole(ADMIN_ROLE) {
        require(newLiquidityWallet != liquidityWallet, "The liquidity wallet is already this address");
        excludeFromFees(newLiquidityWallet, true);
        emit LiquidityWalletUpdated(newLiquidityWallet, liquidityWallet);
        liquidityWallet = newLiquidityWallet;
    }
    
    // updates the operations wallet (marketing, charity, etc.)
    function updateOperationsWallet(address newOperationsWallet) external onlyRole(ADMIN_ROLE) {
        require(newOperationsWallet != operationsWallet, "The operations wallet is already this address");
        excludeFromFees(newOperationsWallet, true);
        emit OperationsWalletUpdated(newOperationsWallet, operationsWallet);
        operationsWallet = newOperationsWallet;
    }
    
    // rebalance Buy fees
    function updateBuyFees(uint256 liquidityPrc, uint256 dividendsPrc, uint256 operationsPrc, uint256 burnPrc) external onlyRole(ADMIN_ROLE) {
        require(liquidityPrc <= 5, "Liquidity fee must be under 5%");
        require(dividendsPrc <= 5, "Dividends fee must be under 5%");
        require(operationsPrc <= 5, "Operations fee must be under 5%");
        require(burnPrc <= 5, "Burn fee must be under 5%");
        emit BuyFeesUpdated(liquidityPrc, dividendsPrc, operationsPrc, burnPrc);
        _buyFeeLiquidity = liquidityPrc;
        _buyFeeDividends = dividendsPrc;
        _buyFeeOperations = operationsPrc;
        _buyFeeBurn = burnPrc;
    }

    // rebalance Sell fees
    function updateSellFees(uint256 liquidityPrc, uint256 dividendsPrc, uint256 operationsPrc, uint256 burnPrc) external onlyRole(ADMIN_ROLE) {
        require(liquidityPrc <= 5, "Liquidity fee must be under 5%");
        require(dividendsPrc <= 5, "Dividends fee must be under 5%");
        require(operationsPrc <= 5, "Operations fee must be under 5%");
        require(burnPrc <= 5, "Burn fee must be under 5%");
        emit BuyFeesUpdated(liquidityPrc, dividendsPrc, operationsPrc, burnPrc);
        _sellFeeLiquidity = liquidityPrc;
        _sellFeeDividends = dividendsPrc;
        _sellFeeOperations = operationsPrc;
        _sellFeeBurn = burnPrc;
    }

    function setMaxSellPercent(uint256 maxSellPercent) public onlyRole(ADMIN_ROLE) {
        require(maxSellPercent < 100, "Max sell percent must be under 100%");
        _maxSellPercent = maxSellPercent;
    }

    function setOperationsInBNB(bool operationsInBNB) public onlyRole(ADMIN_ROLE) {
        require(operationsInBNB != isOperationsETH, "Already set to same value.");
        isOperationsETH = operationsInBNB;
    }

    function setOperationsBNBCollecting(bool operationsCollectingBNB) public onlyRole(ADMIN_ROLE) {
        require(operationsCollectingBNB != isETHCollecting, "Already set to same value.");
        isETHCollecting = operationsCollectingBNB;
    }

    function updateOperationsMinBNB(uint256 minBNB) external onlyRole(ADMIN_ROLE) {
        require(minBNB != minETHToTransfer, "Already set to same value.");
        minETHToTransfer = minBNB;
    }

    // @dev VIEWS ------------------------------------
    
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    // function getNumberOfDividendTokenHolders() external view returns(uint256) {
    //     // TODO: requires implementation
    // }
    
    function getDividendsMinimum() external view returns (uint256) {
        return _minimumBalanceForDividends;
    }
    
    function getDividendsClaimWait() external view returns(uint256) {
        return _dividendsClaimWait;
    }

    function getTotalDividends() external view returns (uint256) {
        return totalDividends;
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }

    function withdrawableDividendOf(address account) public view returns(uint256) {
        return _withdrawableDividendOf(account);
    }

    function dividendsPaidTo(address account) public view returns(uint256) {
        return paidDividendsTo[account];
    }

    function withdrawDividends(address account) public {
        maybeProcessDividendsFor(account);
    }

    /// EXTERNAL STUFF

    function excludeFromDividends(address holder) external onlyRole(MODERATOR_ROLE) {
        super._excludeFromDividends(holder);
    }

    function includeInDividends(address holder) external onlyRole(MODERATOR_ROLE) {
        super._includeInDividends(holder);
    }

    function updateDividendsClaimWait(uint256 newClaimWait) external onlyRole(ADMIN_ROLE) {
        super._updateDividendsClaimWait(newClaimWait);
    }

    function updateDividendsMinimum(uint256 minimumToEarnDivs) external onlyRole(ADMIN_ROLE) {
        super._updateDividendsMinimum(minimumToEarnDivs);
    }

    // Liquidity utils

    function addLiquidityBNB() external payable whenNotPaused {
        uint256 ethHalf = msg.value / 2;
        uint256 otherHalf = msg.value - ethHalf;

        uint256 tokensBefore = balanceOf(_msgSender());

        bool origFeeStatus = _isExcludedFromFees[_msgSender()];
        _isExcludedFromFees[_msgSender()] = true;

        swapEthForTokens(ethHalf);

        _isExcludedFromFees[_msgSender()] = origFeeStatus;

        uint256 tokensAfter = balanceOf(_msgSender());

        uint256 tokensAmount = tokensAfter - tokensBefore;
        super._transfer(_msgSender(), address(this), tokensAmount);


        uint256 liqTokens;
        uint256 liqETH;
        uint256 liq;
        (liqTokens, liqETH, liq) = addUserLiquidity(tokensAmount, otherHalf);

        uint256 remainingETH = msg.value - ethHalf - liqETH;
        uint256 remainingTokens = tokensAmount - liqTokens;

        if (remainingTokens > 0) {
            super._transfer(address(this), _msgSender(), remainingTokens);
        }

        if (remainingETH > 0) {
            (bool success,) = _msgSender().call{value:remainingETH}(new bytes(0));
            require(success, "ETH Transfer Failed");
        }
    }

    // Token Functions

    function _setEnabledAMMPair(address pair, bool value) private {
        require(ammPairs[pair] != value, "Automated market maker pair is already set to that value");
        ammPairs[pair] = value;

        if(value) {
            super._excludeFromDividends(pair);
        }
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(!_isIgnoredAddress[to] || !_isIgnoredAddress[from], "To/from address is ignored");

        if(paused()) {
            if (!_isAllowedDuringDisabled[from] && !_isAllowedDuringDisabled[to]) {
                emit TradeAttemptOnInitialLocked(from, to, amount);
            }

            require(_isAllowedDuringDisabled[to] || _isAllowedDuringDisabled[from], "Trading is currently disabled");

            if(ammPairs[to] && _isAllowedDuringDisabled[from]) {
                require((hasRole(ADMIN_ROLE, from) || hasRole(ADMIN_ROLE, to)) || _isAllowedDuringDisabled[from], "Only dev can trade against PCS during migration");
            }
        }

        // early exit with no other logic if transfering 0 (to prevent 0 transfers from triggering other logic)
        if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        // Prevent buying more than 1 txn per block at launch. Bot killer. Will be removed shortly after launch.
        if (transferDelayEnabled) {
            if (!hasRole(ADMIN_ROLE, to) && to != address(uniswapV2Router) && to != address(uniswapV2Pair) && !_isExcludedFromFees[to] && !_isExcludedFromFees[from]){
                require(_holderLastTransferTimestamp[to] < block.timestamp, "_transfer: Transfer Delay enabled.  Please try again later.");
                _holderLastTransferTimestamp[to] = block.timestamp;
            }
        }

        // set last sell date to first purchase date for new wallet
        if(!isContract(to) && !_isExcludedFromFees[to]){
            if(_holderLastSellDate[to] == 0){
                _holderLastSellDate[to] == block.timestamp;
            }
        }
        
        // update sell date on buys to prevent gaming the decaying sell tax feature.  
        // Every buy moves the sell date up 1/3rd of the difference between last sale date and current timestamp
        if(!isContract(to) && ammPairs[from] && !_isExcludedFromFees[to]){
            if(_holderLastSellDate[to] >= block.timestamp){
                _holderLastSellDate[to] = _holderLastSellDate[to] + ((block.timestamp - _holderLastSellDate[to]) / 3);
            }
        }
        
        if(ammPairs[to]){
            if(!_isExcludedFromFees[from]) {
                require(amount <= maxSellTransactionAmount, "Max Tx amount exceeded");
                uint256 maxPermittedAmount = balanceOf(from) * _maxSellPercent / 100; // Maximum sell % per one single transaction, to ensure some loose change is left in the holders wallet .
                if (amount > maxPermittedAmount) {
                    amount = maxPermittedAmount;
                }
            }
        }

        // maybe pay dividends to both parties
        maybeProcessDividendsFor(from);
        maybeProcessDividendsFor(to);

        bool takeFee = (ammPairs[from] || ammPairs[to]); // tax only buy and sell
        if(_isExcludedFromFees[from] || _isExcludedFromFees[to] || from == address(this)) {
            takeFee = false;
        }

        if(takeFee) {
            uint256 liquidityAmount = 0;
            uint256 dividendsAmount = 0;
            uint256 operationsAmount = 0;
            uint256 burnAmount = 0;

            // if sell, multiply by holderSellFactor (decaying sell penalty by 10% every 2 weeks without selling)
            if(ammPairs[to]) {
                liquidityAmount = amount * _sellFeeLiquidity / 100;
                dividendsAmount = amount * _sellFeeDividends / 100;
                operationsAmount = amount * _sellFeeOperations / 100;
                burnAmount = amount * _sellFeeBurn / 100;

                _holderLastSellDate[from] = block.timestamp; // update last sale time              
            }
            else if (ammPairs[from]) {
                liquidityAmount = amount * _buyFeeLiquidity / 100;
                dividendsAmount = amount * _buyFeeDividends / 100;
                operationsAmount = amount * _buyFeeOperations / 100;
                burnAmount = amount * _buyFeeBurn / 100;
            }

            uint256 feesAmount = liquidityAmount + dividendsAmount + operationsAmount + burnAmount;
            amount = amount - feesAmount;

            super._transfer(from, address(this), feesAmount);

            addDividends(dividendsAmount);

            tokensLiquidity += liquidityAmount;
            tokensOperations += operationsAmount;
            if (!ammPairs[from] && !processing) {
                processing = true;
                processLiquidity();
                processOperations();
                processing = false;
            }
            
            if (burnAmount > 0) {
                _burn(address(this), burnAmount);
            }
        }

        super._transfer(from, to, amount);
        
        updateDividendability(from);
        updateDividendability(to);
    }

    function processLiquidity() private {
        uint256 tokens = tokensLiquidity;
        uint256 halfTokensForSwap = tokens / 2;
        uint256 otherHalf = tokens - halfTokensForSwap;

        uint256 initialBalance = address(this).balance;

        swapTokensForEth(halfTokensForSwap);

        uint256 addedBalance = address(this).balance - initialBalance;

        addLiquidity(otherHalf, addedBalance);
        
        tokensLiquidity -= tokens;
        // emit ProcessLiquidity(halfTokensForSwap, addedBalance, otherHalf);
    }

    function processOperations() private {
        uint256 tokenAmount = tokensOperations;
        if (isOperationsETH) {
            uint256 initialBalance = address(this).balance;
            swapTokensForEth(tokenAmount);
            uint256 addedBalance = address(this).balance - initialBalance;

            if (isETHCollecting) {
                ethOperations += addedBalance;
                if (ethOperations >= minETHToTransfer) {
                    bool success;
                    (success,) = payable(operationsWallet).call{value: ethOperations}("");
                    require(success, "processOperations: Unable to send BNB to Operations Wallet");
                    ethOperations = 0;
                }
            }
            else {
                bool success;
                (success,) = payable(operationsWallet).call{value: addedBalance}("");
                require(success, "processOperations: Unable to send BNB to Operations Wallet");
            }
        }
        else {
            super._transfer(address(this), operationsWallet, tokenAmount);
        }
        tokensOperations -= tokenAmount;
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

    function swapEthForTokens(uint256 ethAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: ethAmount}(
            0, // accept any amount of tokens
            path,
            _msgSender(),
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
            liquidityWallet,
            block.timestamp
        );
    }

    function addUserLiquidity(uint256 tokenAmount, uint256 ethAmount) private returns(uint256 liqTokens, uint256 liqETH, uint256 liq) {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        (liqTokens, liqETH, liq) = uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            _msgSender(),
            block.timestamp
        );
    }

    function recoverContractBNB(uint256 recoverRate) public onlyRole(ADMIN_ROLE){
        uint256 bnbAmount = address(this).balance;
        if(bnbAmount > 0){
            sendToOperationsWallet(bnbAmount * recoverRate / 100);
        }
    }

    function recoverContractTokens(uint256 recoverRate) public onlyRole(ADMIN_ROLE){
        uint256 tokenAmount = balanceOf(address(this));
        if(tokenAmount > 0){
            super._transfer(address(this), operationsWallet, tokenAmount * recoverRate / 100);
        }
    }

	function sendToOperationsWallet(uint256 amount) private {
        payable(operationsWallet).transfer(amount);
    }
}