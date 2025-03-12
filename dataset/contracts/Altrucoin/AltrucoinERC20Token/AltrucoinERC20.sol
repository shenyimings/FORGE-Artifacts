// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.7.5;

import "./SafeMath.sol";

import "./IERC20.sol";
import "./IOHM.sol";
import "./IERC20Permit.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Router01.sol";
import "./IUniswapV2Router02.sol";

import "./ERC20Permit.sol";
import "./OlympusAccessControlled.sol";

contract AltrucoinERC20Token is ERC20Permit, IOHM, OlympusAccessControlled {
    using SafeMath for uint256;

    //--------VARIABLES---------//

    // Multisig Protocol Wallets
    address payable public developmentAddress = payable(0x6EC3D658A79fEbB2Fa87a92C66Fd2A3ddd495B74); // Multisig Protocol Wallet
    address payable public charityAddress = payable(0x8cd3282F41ae28Ea2efBcEA59dA7392503DcD46b); // Multisig Protocol Wallet
    address payable public vaultAddress = payable(0x12Fc3CCd4C8BCA5c03a49397B136223552eB0763); //TODO Replace after vault launch 
    address payable public liquidityAddress = payable(address(this)); 

    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private blacklist; 

    // Protocol Fees
    uint256 public burnFee = 100;
    uint256 public charityFee = 100;
    uint256 public vaultFee = 400;
    uint256 public devFee = 400;
    uint256 public liquidityFee = 0;
    uint256 public divisorNum = 10000; 

    //Minimums before sending tokens from contract to destinations
    uint256 private burnMinSend = 0;
    uint256 private charityMinSend = 0;
    uint256 private vaultMinSend = 0;
    uint256 private devMinSend = 0;

    //Running totals 
    uint256 private burnRunningTotal = 0;
    uint256 private charityRunningTotal = 0;
    uint256 private devRunningTotal = 0;
    uint256 private vaultRunningTotal = 0;

    //Liquidity swaping variables
    uint256 private _startTimeForSwap;
    uint256 private _intervalMinutesForSwap = 1 * 1 minutes;
    uint256 public minimumTokensBeforeSwap = 1; //Breaks if set to 0

    //Mode settings
    bool private _bmode = true;
    bool public tradingOpen = false;

    //Pancakeswap variables
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    IERC20 private feeOutToken;
    
    //Swap and liquify settings
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = false;
    

    //--------EVENTS--------//
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event Bmode(bool enabled);
    event SwapAndLiquifyBNB(
        uint256 BNBSwapped,
        uint256 TokensReceived,
        uint256 tokensIntoLiqudity
    );
    event SwapAndLiquifyTokens(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    
    event SwapETHForTokens(
        uint256 amountIn,
        address[] path
    );
    
    event SwapTokensForETH(
        uint256 amountIn,
        address[] path
    );

    event SwapStakingTokensForSecondTokens(
        uint256 amountIn,
        address[] path
    );
    
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    constructor(address _authority) 
    ERC20("Altrucoin", "ALTRU", 18) 
    ERC20Permit("Altrucoin") 
    OlympusAccessControlled(IOlympusAuthority(_authority)) {

        //IOHM(address(this)).mint(msg.sender, 250000000);

        feeOutToken = IERC20(0x55d398326f99059fF775485246999027B3197955); // BSC BEP20 USDT MAINNET

        //feeOutToken = IERC20(0x337610d27c682E347C9cD60BD4b3b107C9d34dDd); // TETSNET BSC BEP20 USDT
        
        //MAINNET PCS Router: 0x10ED43C718714eb63d5aA57B78B54704E256024E
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        // TESTNET PCS Router: 0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        //IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

        // Protocol Multisig Wallets
        _isExcludedFromFee[authority.governor()] = true;
        _isExcludedFromFee[liquidityAddress] = true;
        _isExcludedFromFee[developmentAddress] = true;
        _isExcludedFromFee[vaultAddress] = true;
        _isExcludedFromFee[charityAddress] = true;

        _startTimeForSwap = block.timestamp;
    }

    function mint(address account_, uint256 amount_) external override onlyVault {
        _mint(account_, amount_);
    }

    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account_, uint256 amount_) external override {
        _burnFrom(account_, amount_);
    }

    function _burnFrom(address account_, uint256 amount_) internal {
        uint256 decreasedAllowance_ = allowance(account_, msg.sender).sub(amount_, "ERC20: burn amount exceeds allowance");

        _approve(account_, msg.sender, decreasedAllowance_);
        _burn(account_, amount_);
    }

    function transfer(address recipient, uint256 amount) public override (ERC20, IERC20) returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override (ERC20, IERC20) returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
    
    function _transfer(address from, address to, uint256 amount) internal override (ERC20) {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        //Blacklist, trading open and max TX checks
        if(from != authority.governor() && to != authority.governor() && ! _isExcludedFromFee[to] && ! _isExcludedFromFee[from]) {
            if(_bmode == true){
                require(blacklist[from] != true, "No blacklist transactions during antiblacklistmode.");
            }
            if(tradingOpen == false){
                require( _isExcludedFromFee[to] || _isExcludedFromFee[from], "Trading paused temporarily.");
            }
        }
        
        // If any account belongs to _isExcludedFromFee account then send without fees
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            _beforeTokenTransfer(from, to, amount);

            _balances[from] = _balances[from].sub(amount, "ERC20: transfer amount exceeds balance");
            _balances[to] = _balances[to].add(amount);

            emit Transfer(from, to, amount);
        }

        else{ //Transfer and take fees

            //Calculate Fees
            uint256 vaultAmount = amount.mul(vaultFee).div(divisorNum);
            uint256 charityAmount = amount.mul(charityFee).div(divisorNum);
            uint256 developmentAmount = amount.mul(devFee).div(divisorNum);
            uint256 liquidityAmount = amount.mul(liquidityFee).div(divisorNum);
            uint256 burnAmount = amount.mul(burnFee).div(divisorNum);

            //Send all fees as 1 tx to token contract to save gas
            uint256 feeTotal = charityAmount.add(developmentAmount).add(vaultAmount).add(liquidityAmount).add(burnAmount);
            if(feeTotal > 0){
                _beforeTokenTransfer(from, address(this), feeTotal);

                //All fees to contract
                _balances[from] = _balances[from].sub(feeTotal, "ERC20: transfer amount exceeds balance");
                _balances[liquidityAddress] = _balances[liquidityAddress].add(feeTotal);
            }

            //Add to thresholds
            vaultRunningTotal = vaultRunningTotal.add(vaultAmount);
            charityRunningTotal = charityRunningTotal.add(charityAmount);
            devRunningTotal = devRunningTotal.add(developmentAmount);
            burnRunningTotal = burnRunningTotal.add(burnAmount);

            //Send to vault only if above threshold to save gas
            if(vaultRunningTotal >= vaultMinSend){
                IERC20(address(this)).transfer(vaultAddress, vaultRunningTotal);
                vaultRunningTotal = 0;
            }
            //Swap and send tokens to charity wallet only if above threshold to save gas
            if(charityRunningTotal >= charityMinSend){
                swapStakingTokensForSecondTokens(charityRunningTotal, address(this), feeOutToken, charityAddress);
                charityRunningTotal = 0;
            }
            //swap and send tokens to dev address only if above threshold to save gas
            if(devRunningTotal >= devMinSend){
                swapStakingTokensForSecondTokens(devRunningTotal, address(this), feeOutToken, developmentAddress);
                devRunningTotal = 0; 
            }
            //Burn tokens only if above threshold to save gas
            if(burnRunningTotal >= burnMinSend){
                IOHM(address(this)).burn(burnRunningTotal);
                burnRunningTotal = 0; 
            }

            // Sell tokens for ETH
            if (!inSwapAndLiquify && swapAndLiquifyEnabled && balanceOf(uniswapV2Pair) > 0 && to == uniswapV2Pair) {
                //Check to see if enough tokens for swap and liquify
                uint256 contractTokenBalance = balanceOf(address(this)).sub(vaultRunningTotal).sub(charityRunningTotal).sub(devRunningTotal).sub(burnRunningTotal);    

                if (contractTokenBalance >= minimumTokensBeforeSwap && _startTimeForSwap + _intervalMinutesForSwap <= block.timestamp) {
                    _startTimeForSwap = block.timestamp;
                    contractTokenBalance = minimumTokensBeforeSwap;
                    swapAndLiquify(contractTokenBalance);
                }  
            }

            //Send remaining tokens to user
            uint256 sendAmount = amount.sub(feeTotal);
            _beforeTokenTransfer(from, to, sendAmount);

            require(_balances[from] >= sendAmount, "ERC20: transfer exceeds balance");
            _balances[from] = _balances[from].sub(sendAmount);
            _balances[to] = _balances[to].add(sendAmount);

            emit Transfer(from, to, sendAmount);
        }
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {

        if(liquidityFee != 0){
            // split the contract balance into halves
            uint256 half = contractTokenBalance.div(2);
            uint256 otherHalf = contractTokenBalance.sub(half);

            // capture the contract's current ETH balance.
            // this is so that we can capture exactly the amount of ETH that the
            // swap creates, and not make the liquidity event include any ETH that
            // has been manually sent to the contract
            uint256 initialBalance = address(this).balance;

            // swap tokens for ETH
            swapTokensForEth(half);

            // how much ETH did we just swap into?
            uint256 newBalance = address(this).balance.sub(initialBalance);

            // add liquidity to pancakeswap
            addLiquidity(otherHalf, newBalance);
            
            emit SwapAndLiquify(half, newBalance, otherHalf);
        }
    }

    /*------------FEE EXCLUDING FUNCITONS---------*/
    
    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }
    
    function excludeFromFee(address account) public onlyGovernor {
        _isExcludedFromFee[account] = true;
    }
    
    function includeInFee(address account) public onlyGovernor {
        _isExcludedFromFee[account] = false;
    }

    /*------------BLACKLIST FUNCTIONS---------*/

    // Toggle trading enabled
    function setTradingOpen(bool _status) public onlyGovernor {
        tradingOpen = _status;
    }

    //Toggle blacklist mode
    function setBmode(bool _enabled) public onlyGovernor {
        _bmode = _enabled;
        emit Bmode(_enabled);
    }

    //Add to blacklist
    function setBlacklist(address[] memory blacklist_) public onlyGovernor {
        for (uint i = 0; i < blacklist_.length; i++) {
            blacklist[blacklist_[i]] = true;
        }
    }
    //Remove from blacklist
    function delBlacklist(address notblacklist) public onlyGovernor {
        blacklist[notblacklist] = false;
    }

    function checkIfOnBlacklist(address _address) view public onlyGovernor returns(bool){
        return blacklist[_address];
    }


    /*------------SWAPANDLIQUIFY CONTROLS---------*/

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyGovernor {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    // newMinutes is in minutes
    function SetSwapMinutes(uint256 newMinutes) external onlyGovernor {
        _intervalMinutesForSwap = newMinutes * 1 minutes;
    }

    function setMinimumTokensBeforeSwap(uint256 _minimumTokensBeforeSwap) external onlyGovernor {
        minimumTokensBeforeSwap = _minimumTokensBeforeSwap;
    }
    

    /*------------TX FEE CONTROLS---------*/
    
    // 10000 makes 100 = 1% on all fees
    function setFeeDivisorNum(uint256 divisorNumSet) external onlyGovernor {
        divisorNum = divisorNumSet;
    }
    // 100 = 1%
    function setDevFeePercent(uint256 devFeeSet, uint256 burnFeeSet, uint256 charityFeeSet, uint256 vaultFeeSet, uint256 liquidityFeeSet) external onlyGovernor() {
        devFee = devFeeSet;
        burnFee = burnFeeSet;
        charityFee = charityFeeSet;
        vaultFee = vaultFeeSet;
        liquidityFee = liquidityFeeSet;
    }

    //Fee min sends (this saves gas for users on normal transactions)
    function setMinSends(uint256 _burnMinSend, uint256 _charityMinSend, uint256 _vaultMinSend, uint256 _devMinSend) external onlyGovernor {
        burnMinSend = _burnMinSend;
        charityMinSend = _charityMinSend;
        vaultMinSend = _vaultMinSend;
        devMinSend = _devMinSend;
    }


    /*------------FEE DESTINATION ADDRESSES---------*/

    function setDevelopmentAddress(address _developmentAddress) external onlyGovernor {
        developmentAddress = payable(_developmentAddress);
        _isExcludedFromFee[developmentAddress] = true;
    }

    function setCharityAddress(address _charityAddress) external onlyGovernor {
        charityAddress = payable(_charityAddress);
        _isExcludedFromFee[charityAddress] = true;
    }

    function setVaultAddress(address _vaultAddress) external onlyGovernor {
        vaultAddress = payable(_vaultAddress);
        _isExcludedFromFee[vaultAddress] = true;
    }

    function setLiquidityAddress(address _liquidityAddress) external onlyGovernor {
        liquidityAddress = payable(_liquidityAddress);
        _isExcludedFromFee[liquidityAddress] = true;
    }

    //Set the BEP20 token used for charity and development fees
    function setFeeOutTokenAddress(address _feeOutToken) external onlyGovernor {
        feeOutToken = IERC20(_feeOutToken);
    }
    

    //--------PRESALE FUNCTIONS---------//

    function prepareForPreSale() external onlyGovernor {
        //All modes false
        setSwapAndLiquifyEnabled(false);
        setBmode(false);
        setTradingOpen(false);

        //Turn off all fees
        burnFee = 0;
        charityFee = 0;
        vaultFee = 0;
        devFee = 0;
        liquidityFee = 0;
    }

    function afterPreSale() external onlyGovernor {
        //Turn on modes
        setSwapAndLiquifyEnabled(true); //swap and liquify
        setBmode(true); //blacklist

        //Set fees
        burnFee = 100;
        charityFee = 100;
        vaultFee = 400;
        devFee = 400;
        liquidityFee = 0;

        //change min sends after testing
        burnMinSend = 150000000000000000000000;
        charityMinSend = 250000000000000000000000;
        vaultMinSend = 150000000000000000000000;
        devMinSend = 250000000000000000000000;

        minimumTokensBeforeSwap = 150000000000000000000000;

        //Turn on trading
        setTradingOpen(true);
    }


    //--------PANCAKESWAP SWAP FUNCTIONS----------------//

    //Swap Altrucoin for BNB
    function swapTokensForEth(uint256 tokenAmount) private {
        // Generate the uniswap pair path of token -> WETH
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // Make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // Accept any amount of ETH
            path,
            address(this), // The contract
            block.timestamp
        );
        
        emit SwapTokensForETH(tokenAmount, path);
    }

    //Swap from firstToken to tokenSwapping
    function swapStakingTokensForSecondTokens(uint256 amount, address firstToken, IERC20 tokenSwapping, address destination) private {
        // Generate the pancakeswap pair path of token -> WETH
        address[] memory path = new address[](3);
        path[0] = address(firstToken);
        path[1] = uniswapV2Router.WETH();
        path[2] = address(tokenSwapping);

        _approve(address(this), address(uniswapV2Router), amount);
      // Make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0, // Accept any amount of Tokens
            path,
            address(destination), // Vault address
            block.timestamp.add(300)
        );
        
        emit SwapStakingTokensForSecondTokens(amount, path);
    }

    //Swap from BNB to Altrucoin, tokens end up on contract
    function swapETHForTokensToHere(uint256 amount) private {
        // Generate the uniswap pair path of token -> WETH
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

      // Make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // Accept any amount of Tokens
            path,
            address(this), // Contract address
            block.timestamp.add(300)
        );
        
        emit SwapETHForTokens(amount, path);
    }


    /*------------LIQUIDITY SWAPING FUNCTIONS---------*/

    //Add liquidity on PCS
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // Approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // Add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // Slippage is unavoidable
            0, // Slippage is unavoidable
            authority.governor(), //Contract Owner
            block.timestamp
        );
    }

    //Create additional liquidity using BNB tokens in contract
    function manualSwapAndLiquifyBNB(uint256 bnbLiquifyAmount) external lockTheSwap onlyGovernor {
        // split the contract balance into halves
        uint256 half = bnbLiquifyAmount.div(2); // WBNB
        uint256 otherHalf = bnbLiquifyAmount.sub(half); // WBNB not swapped

        // capture the contract's current Token balance.
        // this is so that we can capture exactly the amount of Tokens that the
        // swap creates, and not make the liquidity event include any Tokens that
        // has been manually sent to the contract
        uint256 initialTokenBalance = balanceOf(address(this));

        // swap ETH for Tokens
        swapETHForTokensToHere(half); 

        // how much Tokens did we just swap into?
        uint256 newTokenBalance = balanceOf(address(this)).sub(initialTokenBalance);

        // add liquidity to uniswap
        addLiquidity(newTokenBalance, otherHalf);
        
        emit SwapAndLiquifyBNB(half, newTokenBalance, otherHalf);
    }

    //Create additional liquidity using BankerDoge tokens in contract
    function manualSwapAndLiquifyTokens(uint256 tokenLiquifyAmount) external lockTheSwap onlyGovernor{
        // split the contract balance into halves
        uint256 half = tokenLiquifyAmount.div(2); //staking tokens to be swaped
        uint256 otherHalf = tokenLiquifyAmount.sub(half); //staking tokens not swapped

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half);

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquifyTokens(half, newBalance, otherHalf);
    }
    

    /*------------SAFETY FUNCTIONS---------*/

    // Recommended to add by certik: For stuck tokens (as a result of slight miscalculations/rounding errors) 
    function SweepStuck(uint256 _amount) external onlyGovernor {
        payable(authority.governor()).transfer(_amount);
    }

    // for stuck tokens of other types
    function transferForeignToken(address _token, address _to) public onlyGovernor returns(bool _sent){
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        _sent = IERC20(_token).transfer(_to, _contractBalance);
    }


    /*-------------LIQUIDITY POOL CONTROL FUNCTIONS-----------*/

    function changeRouterVersion(address _router) public onlyGovernor returns(address _pair) {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_router);
        
        _pair = IUniswapV2Factory(_uniswapV2Router.factory()).getPair(address(this), _uniswapV2Router.WETH());
        if(_pair == address(0)){
            // Pair doesn't exist
            _pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        }
        uniswapV2Pair = _pair;

        // Set the router of the contract variables
        uniswapV2Router = _uniswapV2Router;
    }

    //Use when new router is released but pair hasnt been created yet.
    //Make sure to add initial liquidity manually after pair is made! Otherwise swapAndLiquify will fail.
    function setRouterAddressAndCreatePair(address newRouter) public onlyGovernor() {
        IUniswapV2Router02 _newPancakeRouter = IUniswapV2Router02(newRouter);
        uniswapV2Pair = IUniswapV2Factory(_newPancakeRouter.factory()).createPair(address(this), _newPancakeRouter.WETH());
        uniswapV2Router = _newPancakeRouter;
    }
    
    //Use when new router is released and pair HAS been created already.
    function setRouterAddress(address newRouter) public onlyGovernor() {
        IUniswapV2Router02 _newPancakeRouter = IUniswapV2Router02(newRouter);
        uniswapV2Router = _newPancakeRouter;
    }
    
    //Use when new router is released and pair HAS been created already.
    function setPairAddress(address newPair) public onlyGovernor() {
        uniswapV2Pair = newPair;
    }
    
    // To receive ETH from uniswapV2Router when swapping
    receive() external payable {}
}
