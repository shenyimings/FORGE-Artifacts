// SPDX-License-Identifier: Unlicensed 
// This contract is not open source and can not be used/forked without permission
// Custom Contract created at GEN: TokensByGen.com for Skeleton Key
// Reflection Rewards - Holders are rewarded with more of the native token

/*

    Skeleton Key [KEY$]

    Skeletonkeytoken.com

    Telegram
    https://t.me/+QMn168BFP5wyZjNh

    Facebook
    https://www.facebook.com/SkeletonKeyToken?mibextid=D4KYlr

    Twitter
    https://x.com/Skeletonkeytokn?s=09

    Custom contract created at GEN: TokensByGen.com

*/

pragma solidity 0.8.19;
 
interface IERC20 {

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Pair {
    function factory() external view returns (address);
}

interface IUniswapV2Router02 {

    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}



contract SkeletonKey is Context, IERC20 {  

    // Contract Wallets
    address public _owner = 0x1a6DC28FB7f9CaE01e6ca5733e720d189b7A4103; 
    address public Wallet_Liquidity = 0x74C2025F1DFCfE8A517d3Fef040157C76e33E2B7;
    address payable public Wallet_Discretion = payable(0x339DB8A55F0aee632c2049Dd465E09383e6caAf3);
    address payable public Wallet_Marketing = payable(0x3c8B1aa140DA77E50312ab37b51e7567Eb3cc122);
    address public constant Wallet_Burn = 0x000000000000000000000000000000000000dEaD;

    // Token Info
    string private  _name = "Skeleton Key";
    string private  _symbol = "KEY$";
    uint256 private _decimals = 9; 
    uint256 private _tTotal = 1_000_000_000 * 10 ** _decimals;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;
    uint256 private constant MAX = ~uint256(0);

    // Project links
    string private _website;
    string private _telegram;
    string private _lplock;

    // Wallet and transaction limits
    uint256 private max_Hold;
    uint256 private max_Tran;

    // Fees
    uint8 public _fee__Marketing  = 6;
    uint8 public _fee__Liquidity  = 1;
    uint8 public _fee__Discretion = 1;
    uint8 public _fee__Reflection = 2;

    // Total Fee for Swap
    uint8 private _SwapFeeTotal = 8;

    // Set factory
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;


    constructor () {

        max_Hold = _tTotal;
        max_Tran = _tTotal;

        // Whitelist owner so they can add initial liquidity 
        _isWhiteListed[_owner] = true;

        // Wallets excluded from holding limits
        _isLimitExempt[_owner] = true;
        _isLimitExempt[address(this)] = true;
        _isLimitExempt[Wallet_Burn] = true;

        // Wallets excluded from fees
        _isExcludedFromFee[_owner] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[Wallet_Burn] = true;

        // Exclude from rewards
        _isExcludedFromRewards[Wallet_Burn] = true;
        _isExcludedFromRewards[address(this)] = true;
        _excluded.push(Wallet_Burn);
        _excluded.push(address(this));

        _tOwned[address(this)] = _tTotal;
        _rOwned[address(this)] = _rTotal;
      
        emit Transfer(address(0), address(this), _tTotal);
        emit OwnershipTransferred(address(0), _owner);

    }

    // Events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event updated_Wallet_Limits(uint256 max_Tran, uint256 max_Hold);
    event updated_fees(uint8 Marketing, uint8 Liquidity, uint8 Fund, uint8 Reflection);
    event updated_SwapAndLiquify_Enabled(bool Swap_and_Liquify_Enabled);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TokenCreated(address indexed Token_CA);
    event LiquidityAdded(uint256 Tokens_Amount, uint256 BNB_Amount);


    // Restrict function to contract owner only 
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    // Address mappings
    mapping (address => uint256) private _tOwned;                               // Tokens Owned
    mapping (address => uint256) private _rOwned;                               // Reflected balance
    mapping (address => mapping (address => uint256)) private _allowances;      // Allowance to spend another wallets tokens
    mapping (address => bool) public _isExcludedFromFee;                        // Wallets that do not pay fees
    mapping (address => bool) public _isExcludedFromRewards;                    // Excluded from RFI rewards
    mapping (address => bool) public _isWhiteListed;                            // Wallets that have access before trade is open
    mapping (address => bool) public _isLimitExempt;                            // Wallets that are excluded from HOLD and TRANSFER limits
    mapping (address => bool) public _isPair;                                   // Address is liquidity pair
    address[] private _excluded;                                                // Array of wallets excluded from rewards

    // Fee Processing Triggers
    uint256 private swapTrigger = 11; 
    uint256 private swapCounter = 1;    
    
    // Fee processing (SwapAndLiquify) Switch                  
    bool public processingFees;
    bool public feeProcessingEnabled; 

    // Launch Settings
    bool public Trade_Open;
    bool public no_Fee_Transfers = true;   // True at launch (Wallet to wallet transfers do not incur a fee)
    bool public noFeeWhenProcessing;        // False at launch (The sell that triggers fee processing still needs to pay the transaction fee)

    // Fee Tracker
    bool private takeFee;


    // Project info
    function Project_Information() external view returns(address Owner_Wallet,
                                                       uint256 Transaction_Limit,
                                                       uint256 Max_Wallet,
                                                       uint256 Fee_When_Buying,
                                                       uint256 Fee_When_Selling,
                                                       string memory Website,
                                                       string memory Telegram,
                                                       string memory Liquidity_Lock,
                                                       string memory Contract_Created_By) {
                                                           
        string memory Creator = "www.TokensByGen.com";

        uint256 Total_fee =  _fee__Liquidity    +
                             _fee__Reflection   +
                             _fee__Marketing    +
                             _fee__Discretion;

        uint256 _max_Hold = max_Hold / 10 ** _decimals;
        uint256 _max_Tran = max_Tran / 10 ** _decimals;

        if (_max_Tran > _max_Hold) {

            _max_Tran = _max_Hold;
        }


        // Return Token Data
        return (_owner,
                _max_Tran,
                _max_Hold,
                Total_fee,
                Total_fee,
                _website,
                _telegram,
                _lplock,
                Creator);

    }
    
    // Set Buy and Sell Fees
    function Launch_01_Set_Fees(

        uint8 Marketing, 
        uint8 Liquidity, 
        uint8 Discretion,
        uint8 Reflection

        ) external onlyOwner {

        // Buyer Protection: Max Fee 10%
        require (Marketing + Liquidity + Discretion +  Reflection <= 10, "FEE1");  // Max fee 10%

        // Update Fees
        _fee__Marketing   = Marketing;
        _fee__Liquidity   = Liquidity;
        _fee__Discretion  = Discretion;
        _fee__Reflection  = Reflection;

        // Fees For Processing
        _SwapFeeTotal = _fee__Marketing + _fee__Liquidity + _fee__Discretion;

        emit updated_fees(_fee__Marketing, _fee__Liquidity, _fee__Discretion, _fee__Reflection);
    
    }

    /*
    
    ------------------------------------------
    SET MAX TRANSACTION AND MAX HOLDING LIMITS
    ------------------------------------------

    Solidity can only accept whole numbers.
    Enter value as a factor of 10

        1 = 0.1%
        5 = 0.5%
        10 = 1%

    */

    function Launch_02_Set_Wallet_Limits(

        uint256 Max_Transaction_Percent__MultiplyByTen,
        uint256 Max_Wallet_Percent__MultiplyByTen

        ) external onlyOwner {

        require(Max_Transaction_Percent__MultiplyByTen >= 1, "Min1"); // Must be at leaset 1 (0.1%)
        require(Max_Wallet_Percent__MultiplyByTen >= 1, "Min1"); // Must be at leaset 1 (0.1%)

            max_Tran = _tTotal * Max_Transaction_Percent__MultiplyByTen / 100 / 10;
            max_Hold = _tTotal * Max_Wallet_Percent__MultiplyByTen / 100 / 10;

        emit updated_Wallet_Limits(max_Tran, max_Hold);

    }

    function Launch_03_Launch_Directly_On_PancakeSwap(uint256 percent_of_supply) external payable onlyOwner {


        require(percent_of_supply <= 100, "P100"); // Max permitted is 100

        uint256 tokensIntoLP = _tTotal * percent_of_supply / 100;


    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // BSC MAIN



        // Create initial liquidity pair with BNB on PancakeSwap factory
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;


        // Set as pair and make limit exempt
        _isPair[uniswapV2Pair] = true; 
        _isLimitExempt[uniswapV2Pair] = true;

        _approve(address(this), address(uniswapV2Router), _tTotal);
        uniswapV2Router.addLiquidityETH{value: msg.value}(address(this),tokensIntoLP,0,0,owner(),block.timestamp);
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router),type(uint256).max);

            if(percent_of_supply != 100) { 

                // Flush remaining tokens to owner wallet
                IERC20(address(this)).transfer(owner(), balanceOf(address(this)));
            }
        }


    // Open Trade
    function Launch_04_Open_Trade() external onlyOwner {

        require(!Trade_Open, "TradeOpen"); // Trade is already open - Trade can not be paused 
        feeProcessingEnabled = true;
        Trade_Open = true;

        // Exclude pair from reflection rewards
        if (!_isExcludedFromRewards[uniswapV2Pair]){

            if(_rOwned[uniswapV2Pair] > 0) {
                _tOwned[uniswapV2Pair] = tokenFromReflection(_rOwned[uniswapV2Pair]);
            }

            _isExcludedFromRewards[uniswapV2Pair] = true;
            _excluded.push(uniswapV2Pair);
            }

    }


    /*

    --------------
    FEE PROCESSING 
    --------------

    */


    // Add Liquidity Pair - required for correct fee calculations 
    function Process_Add_Liquidity_Pair(

        address Wallet_Address,
        bool true_or_false)

        external onlyOwner {

        _isPair[Wallet_Address] = true_or_false;
        _isLimitExempt[Wallet_Address] = true_or_false;

    } 

    /*
    
    ---------------------------------
    NO FEE WALLET TO WALLET TRANSFERS
    ---------------------------------

    Default = true

    Having no fee on wallet-to-wallet transfers means that people can move tokens between wallets, 
    or send them to friends etc without incurring a fee. 

    If false, the 'Buy' fee will apply to all wallet to wallet transfers.

    */


    function Process_No_Fee_Wallet_Transfers(bool true_or_false) external onlyOwner {

        no_Fee_Transfers = true_or_false;

    }


    // Auto Fee Processing Switch (SwapAndLiquify)
    function Process_Trigger_Automatic(bool true_or_false) external onlyOwner {
        feeProcessingEnabled = true_or_false;
        emit updated_SwapAndLiquify_Enabled(true_or_false);
    }
    
    function Process_Trigger_Count(uint256 Transaction_Count) external onlyOwner {

        swapTrigger = Transaction_Count + 1; // Reset to 1 (not 0) to save gas
    }

    // Manually Process Fees
    function Process_Trigger_Now (uint256 Percent_of_Tokens_to_Process) external onlyOwner {

        require(!processingFees, "E15"); // Already in swap, try later

        if (Percent_of_Tokens_to_Process > 100){Percent_of_Tokens_to_Process = 100;}
        uint256 tokensOnContract = balanceOf(address(this));
        uint256 sendTokens = tokensOnContract * Percent_of_Tokens_to_Process / 100;
        processFees(sendTokens);

    } 

    /*

    --------------------------
    REMOVE FEE WHEN PROCESSING
    --------------------------

    Default = false

    When the contract needs to process fees the 'sell fee' displayed on a DEX will include the sell fee and the price drop caused by the contract sell.
    Setting this to true will help to mitigate that increase. For details see https://www.youtube.com/watch?v=PKyACFILwhI 

    */


    // Remove fee for wallet that triggers processing
    function Process_Remove_Fee_When_Processing(bool true_or_false) external onlyOwner {

        noFeeWhenProcessing = true_or_false;

    }

    function Process_Rescue_Tokens(

        address random_Token_Address,
        uint256 number_of_Tokens

        ) external onlyOwner {

            require (random_Token_Address != address(this), "E16"); // Can not remove the native token
            IERC20(random_Token_Address).transfer(msg.sender, number_of_Tokens);
            
    }

    /*

    --------------
    UPDATE PROJECT
    --------------

    */

    function Project_Update_Links_LP_Lock(

        string memory LP_Lock_URL

        ) external onlyOwner{

        _lplock = LP_Lock_URL;

    }

    function Project_Update_Links_Telegram(

        string memory Telegram_Group

        ) external onlyOwner{

        _telegram = Telegram_Group;

    }

    function Project_Update_Links_Website(

        string memory Website_URL

        ) external onlyOwner{

        _website = Website_URL;

    }

    function Project_Update_Wallet_Discretion(

        address payable Fund_Wallet

        ) external onlyOwner {

        // Update Fund  Wallet
        require(Fund_Wallet != address(0), "E07"); // Enter a valid BSC Address
        Wallet_Discretion = payable(Fund_Wallet);

    }

    function Project_Update_Wallet_Liquidity(

        address Liquidity_Collection_Wallet

        ) external onlyOwner {

        // Update LP Collection Wallet
        require(Liquidity_Collection_Wallet != address(0), "E07"); // Enter a valid BSC Address
        Wallet_Liquidity = Liquidity_Collection_Wallet;

    }

    function Project_Update_Wallet_Marketing(

        address payable Marketing_Wallet

        ) external onlyOwner {

        // Update Marketing Wallet
        require(Marketing_Wallet != address(0), "E08"); // Enter a valid BSC Address
        Wallet_Marketing = payable(Marketing_Wallet);

    }


    /*

    ------------------
    REFLECTION REWARDS
    ------------------

    The following functions are used to exclude or include a wallet in the reflection rewards.
    By default, all wallets are included. 

    Wallets that are excluded:

            The Burn address 
            The Liquidity Pair
            The Contract Address

    ----------------------------------------
    *** WARNING - DoS 'OUT OF GAS' Risk! ***
    ----------------------------------------

    A reflections contract needs to loop through all excluded wallets to correctly process several functions. 
    This loop can break the contract if it runs out of gas before completion.

    To prevent this, keep the number of wallets that are excluded from rewards to an absolute minimum. 
    In addition to the default excluded wallets, you may need to exclude the address of any locked tokens.

    */

    // Wallet will not get reflections
    function Rewards_Exclude_Wallet(address account) public onlyOwner() {
        require(!_isExcludedFromRewards[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcludedFromRewards[account] = true;
        _excluded.push(account);
    }


    // Wallet will get reflections - DEFAULT
    function Rewards_Include_Wallet(address account) external onlyOwner() {
        require(_isExcludedFromRewards[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcludedFromRewards[account] = false;
                _excluded.pop();
                break;
            }
        }
    }
    



    /*

    ---------------
    WALLET SETTINGS
    ---------------

    */


    // Exclude From Transaction and Holding Limits
    function Wallet_Exempt_From_Limits(

        address Wallet_Address,
        bool true_or_false

        ) external onlyOwner {  
        _isLimitExempt[Wallet_Address] = true_or_false;
    }

    // Exclude From Fees
    function Wallet_Exclude_From_Fees(

        address Wallet_Address,
        bool true_or_false

        ) external onlyOwner {
        _isExcludedFromFee[Wallet_Address] = true_or_false;

    }

    // Grant Pre-Launch Access (Whitelist)
    function Wallet_Pre_Launch_Access(

        address Wallet_Address,
        bool true_or_false

        ) external onlyOwner {    
        _isWhiteListed[Wallet_Address] = true_or_false;
    }





    /* 

    ----------------------------
    CONTRACT OWNERSHIP FUNCTIONS
    ----------------------------

    Before renouncing ownership, set the freeWalletTransfers to false 

    */

  
    // Renounce Ownership
    function ownership_RENOUNCE() public virtual onlyOwner {

        // Remove old owner status 
        _isLimitExempt[owner()]     = false;
        _isExcludedFromFee[owner()] = false;
        _isWhiteListed[owner()]     = false;

        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    // Transfer to New Owner
    function ownership_TRANSFER(address payable newOwner) public onlyOwner {

        require(newOwner != address(0), "ZEROADD"); // Enter a valid BSC wallet

        // Revoke old owner status
        _isLimitExempt[owner()]     = false;
        _isExcludedFromFee[owner()] = false;
        _isWhiteListed[owner()]     = false;

        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;

        // Set up new owner status 
        _isLimitExempt[owner()]     = true;
        _isExcludedFromFee[owner()] = true;
        _isWhiteListed[owner()]     = true;

    }


    /*

    -----------------------------
    BEP20 STANDARD AND COMPLIANCE
    -----------------------------

    */

    function owner() public view returns (address) {
        return _owner;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint256) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcludedFromRewards[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
   
    function tokenFromReflection(uint256 _rAmount) internal view returns(uint256) {
        require(_rAmount <= _rTotal, "rAmount can not be greater than rTotal");
        uint256 currentRate =  _getRate();
        return _rAmount / currentRate;
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }


    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }
    
    function send_BNB(address _to, uint256 _amount) internal returns (bool SendSuccess) {
                                
        (SendSuccess,) = payable(_to).call{value: _amount}("");

    }

    function getCirculatingSupply() public view returns (uint256) {
        return (_tTotal - balanceOf(address(Wallet_Burn)));
    }



    /*

    ---------------
    TOKEN TRANSFERS
    ---------------

    */

    function _transfer(
        address from,
        address to,
        uint256 amount
      ) private {




        require(balanceOf(from) >= amount, "TO1"); // Sender does not have enough tokens!

       

        if (!Trade_Open && from != address(this)){

            require(_isWhiteListed[from] || _isWhiteListed[to], "TO2");  // Trade closed, only whitelisted wallets can move tokens


        }

        // Wallet Limit
        if (!_isLimitExempt[to] && from != owner()) {

            uint256 heldTokens = balanceOf(to);
            require((heldTokens + amount) <= max_Hold, "WL"); // Over max wallet limit

        }

        // Transaction limit - To send over the transaction limit the sender AND the recipient must be limit exempt
        if (!_isLimitExempt[to] || !_isLimitExempt[from]){

            require(amount <= max_Tran, "TL"); // Over max transaction limit
            
        }



        // Compliance and safety checks
        require(from != address(0), "FROM0"); // Not a valid BSC wallet address
        require(to != address(0), "TO0"); // Not a valid BSC wallet address
        require(amount > 0, "AMT0"); // Amount must be greater than 0

      
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to] || (no_Fee_Transfers && !_isPair[to] && !_isPair[from])){
            takeFee = false;
        } else {
            takeFee = true;
        }

        // Trigger Fee Processing
        if (_isPair[to] && !processingFees && feeProcessingEnabled) {

            // Check Transaction Count
            if(swapCounter >= swapTrigger){

                // Check Contract Tokens
                uint256 contractTokens = balanceOf(address(this));

                if (contractTokens > 0) {

                    // Check if fee is removed during processing
                    if (noFeeWhenProcessing && takeFee){takeFee = false;}

                    // Limit Swap to Max Transaction
                    if (contractTokens <= max_Tran) {

                        processFees (contractTokens);

                        } else {

                        processFees (max_Tran);

                    }
                }
            }  
        }


        _tokenTransfer(from, to, amount, takeFee);




    }


    /*
    
    ------------
    PROCESS FEES
    ------------

    */

    function processFees(uint256 Tokens) private {

        // Lock Swap
        processingFees = true;

        // Totals for buy and sell fees
        uint8 _LiquidityTotal   = _fee__Liquidity * 2;
        uint8 _FundTotal        = _fee__Discretion * 2;
        uint8 _FeesTotal        = _SwapFeeTotal * 2;

        // Calculate tokens for swap
        uint256 LP_Tokens       = Tokens * _LiquidityTotal / _FeesTotal / 2;
        uint256 Swap_Tokens     = Tokens - LP_Tokens;

        // Swap Tokens
        uint256 contract_BNB    = address(this).balance;
        swapTokensForBNB(Swap_Tokens);
        uint256 returned_BNB    = address(this).balance - contract_BNB;

        // Avoid Rounding Errors on LP Fee if Odd Number
        uint256 fee_Split       = _FeesTotal * 2 - _LiquidityTotal;

        // Process the Fund Wallet
        if (_FundTotal > 0 ) {

            uint256 BNB_Fund = returned_BNB * _FundTotal * 2 / fee_Split;
            if (BNB_Fund > 0){

            send_BNB(Wallet_Discretion, BNB_Fund);
            }

        }

        // Add Auto Liquidity 
        if (_LiquidityTotal > 0 ) {

            uint256 BNB_Liquidity = returned_BNB * _LiquidityTotal / fee_Split;
            addLiquidity(LP_Tokens, BNB_Liquidity);
            emit SwapAndLiquify(LP_Tokens, BNB_Liquidity, LP_Tokens);
        
        }

        
        // Flush Remaining BNB to Marketing Wallet
        contract_BNB = address(this).balance;

        if (contract_BNB > 0){

            send_BNB(Wallet_Marketing, contract_BNB);
        }


        // Reset Counter
        swapCounter = 1;

        // Unlock Swap
        processingFees = false;


    }

    // Swap tokens for BNB
    function swapTokensForBNB(uint256 tokenAmount) private {

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, 
            path,
            address(this),
            block.timestamp
        );
    }

    // Add liquidity and send Cake LP tokens to liquidity collection wallet
    function addLiquidity(uint256 tokenAmount, uint256 BNBAmount) private {

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.addLiquidityETH{value: BNBAmount}(
            address(this),
            tokenAmount,
            0, 
            0,
            Wallet_Liquidity, 
            block.timestamp
        );
    } 

    /*
    
    ----------------------------------
    TRANSFER TOKENS AND CALCULATE FEES
    ----------------------------------

    */


    // Transfer Tokens and Calculate Fees
    function _tokenTransfer(address sender, address recipient, uint256 tAmount, bool Fee) private {

    
    uint256 tReflect;
    uint256 tSwapFeeTotal;
        
        if (Fee){

                // Take fees
                tSwapFeeTotal   = tAmount * _SwapFeeTotal     / 100;
                tReflect        = tAmount * _fee__Reflection  / 100;

                } else {

                tSwapFeeTotal   = 0;
                tReflect        = 0;

        }

        uint256 tTransferAmount = tAmount - (tSwapFeeTotal + tReflect);


        // Calculate reflected fees for RFI
        uint256 RFI = _getRate(); 

        uint256 rAmount         = tAmount       * RFI;
        uint256 rReflect        = tReflect      * RFI;
        uint256 rSwapFeeTotal   = tSwapFeeTotal * RFI;

        uint256 rTransferAmount = rAmount - (rReflect + rSwapFeeTotal);


        // Remove tokens from sender
        _rOwned[sender] -= rAmount;
        if(_isExcludedFromRewards[sender]){
            _tOwned[sender] -= tAmount;
        }

        // Send tokens to recipient or remove from supply
        _rOwned[recipient] += rTransferAmount;

                if(_isExcludedFromRewards[recipient]){
                    _tOwned[recipient] += tTransferAmount;
                }

        emit Transfer(sender, recipient, tTransferAmount);

        // Take reflections
        if(tReflect > 0){

            _rTotal -= rReflect;
            _tFeeTotal += tReflect;
        }

        // Take fees that require processing during swap and liquify
        if(tSwapFeeTotal > 0){

            _rOwned[address(this)] += rSwapFeeTotal;
            if(_isExcludedFromRewards[address(this)]){_tOwned[address(this)] += tSwapFeeTotal;}
            emit Transfer(sender, address(this), tSwapFeeTotal);

            // Increase the transaction counter
            if(swapCounter < swapTrigger){
                unchecked{swapCounter++;}
            }
                
        }

    }


    // This function is required so that the contract can receive BNB during fee processing
    receive() external payable {}

}



/*


    Custom Token Created by GEN www.TokensByGen.com for Skeleton Key
    This contract is not open source - Can not be used or forked without permission.
    

*/