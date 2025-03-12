// SPDX-License-Identifier: Unlicensed 
// This contract is not open source and can not be used/forked without permission
// Contract created at TokensByGen.com

/*

    Query the "Project_Information" function on 'BSCScan > Contract > Read Contract' for information on this project

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

interface IDividendDistributor {

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external;
    function setShare(address shareholder, uint256 amount) external;
    function deposit() external payable;
    function process(uint256 gas) external;
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

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

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


contract BABY_TOKEN is Context, IERC20 { 

    // Contract Wallets
    address public RWD_Token;
    address public _owner;
    address public Wallet_Liquidity;
    address payable public Wallet_Marketing;
    address payable public Wallet_Affiliate;
    address payable public constant Wallet_DevFee = payable(0xde491C65E507d281B6a3688d11e8fC222eee0975);
    address public constant Wallet_Burn = 0x000000000000000000000000000000000000dEaD;

    // GEN address (for affiliate commission level tracking)
    IERC20 GEN = IERC20(0x5a457fb51bD0F50df9eC9F3d0aeC04CD4B9Ce0BF); 

    // Token Info
    string private  _name;
    string private  _symbol;
    uint256 private _decimals;
    uint256 private _tTotal;

    // Project links
    string private _website;
    string private _telegram;
    string private _lplock;

    // Wallet and transaction limits
    uint256 private max_Hold;
    uint256 private max_Tran;

    // Fees - 1% contract fee until removed
    uint8 public _fee__Buy_Contract = 1;
    uint8 public _fee__Buy_Liquidity;
    uint8 public _fee__Buy_Marketing;
    uint8 public _fee__Buy_Rewards;
    uint8 public _fee__Buy_Burn;

    uint8 public _fee__Sell_Contract = 1;
    uint8 public _fee__Sell_Liquidity;
    uint8 public _fee__Sell_Marketing;
    uint8 public _fee__Sell_Rewards;
    uint8 public _fee__Sell_Burn;

    // Total Fee for Swap
    uint8 private _SwapFeeTotal_Buy = 1;
    uint8 private _SwapFeeTotal_Sell = 1;

    bool public contractFeePaid;

    // Gas Amount
    uint256 distributorGas = 500000;


    // Set factory
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;


    constructor (string memory      _TokenName, 
                 string memory      _TokenSymbol,  
                 uint256            _TotalSupply, 
                 uint256            _Decimals,
                 address            _Reward_Token,
                 address payable    _AffiliateWallet, 
                 address payable    _OwnerWallet) {

        emit TokenCreated(address(this));


        _name               = _TokenName;
        _symbol             = _TokenSymbol;
        _decimals           = _Decimals;
        _tTotal             = _TotalSupply * 10**_Decimals;
        max_Hold            = _tTotal;
        max_Tran            = _tTotal;

        _owner = _OwnerWallet;
        RWD_Token = _Reward_Token;
        Wallet_Liquidity = _owner;
        Wallet_Marketing = payable(_owner);
        Wallet_Affiliate = payable(_AffiliateWallet);

        // Create Reward Tracker Contract
        distributor = new RewardDistributor(RWD_Token);

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

        _tOwned[_owner] = _tTotal;
      
        emit Transfer(address(0), _owner, _tTotal);
        emit OwnershipTransferred(address(0), _owner);

    }

    // Events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event updated_Wallet_Limits(uint256 max_Tran, uint256 max_Hold);
    event updated_Buy_fees(uint8 Marketing, uint8 Liquidity, uint8 Rewards, uint8 Burn, uint8 Contract_Fee);
    event updated_Sell_fees(uint8 Marketing, uint8 Liquidity, uint8 Rewards, uint8 Burn, uint8 Contract_Fee);
    event updated_SwapAndLiquify_Enabled(bool Swap_and_Liquify_Enabled);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TokenCreated(address indexed Token_CA);
    event LiquidityAdded(uint256 Tokens_Amount, uint256 BNB_Amount);


    // Restrict function to contract owner only 
    modifier onlyOwner() {
        require(owner() == _msgSender(), "OWN"); // Ownable: caller is not the owner
        _;
    }

    // Address mappings
    mapping (address => uint256) private _tOwned;                               // Tokens Owned
    mapping (address => mapping (address => uint256)) private _allowances;      // Allowance to spend another wallets tokens
    mapping (address => bool) public _isExcludedFromFee;                        // Wallets that do not pay fees
    mapping (address => bool) public _isWhiteListed;                            // Wallets that have access before trade is open
    mapping (address => bool) public _isLimitExempt;                            // Wallets that are excluded from HOLD and TRANSFER limits
    mapping (address => bool) public _isPair;                                   // Address is liquidity pair
    mapping (address => bool) public _isExcludedFromRewards;                    // Excluded from Rewards
    mapping (address => bool) public _bypassDistribution;                       // Tokens sent from this wallet do not triger distribution (used for airdrops)
    
    // Set Distributor
    RewardDistributor public distributor;

    // Fee Processing Triggers
    uint256 private swapTrigger = 11; 
    uint256 private swapCounter = 1;    
    
    // Fee processing (SwapAndLiquify) Switch                  
    bool public processingFees;
    bool public feeProcessingEnabled; 

    // Launch Settings
    bool public Trade_Open;
    bool public no_Fee_Transfers = true;    // True at launch (Wallet to wallet transfers do not incur a fee)
    bool public burnFromSupply;             // False at launch (Burned tokens are sent to burn wallet, and not removed from supply)

    // Fee Tracker
    bool private takeFee;


    // Project info
    function Project_Information() external view returns(address Owner_Wallet,
                                                       address Rewards_Token,
                                                       uint256 Transaction_Limit,
                                                       uint256 Max_Wallet,
                                                       uint256 Fee_When_Buying,
                                                       uint256 Fee_When_Selling,
                                                       string memory Website,
                                                       string memory Telegram,
                                                       string memory Liquidity_Lock,
                                                       string memory Contract_Created_By) {
                                                           
        string memory Creator = "TokensByGen.com";

        uint256 Total_buy =  _fee__Buy_Contract     +
                             _fee__Buy_Liquidity    +
                             _fee__Buy_Rewards      +
                             _fee__Buy_Marketing    +
                             _fee__Buy_Burn;

        uint256 Total_sell = _fee__Sell_Contract    +
                             _fee__Sell_Liquidity   +
                             _fee__Sell_Rewards     +
                             _fee__Sell_Marketing   +
                             _fee__Sell_Burn;

        uint256 _max_Hold = max_Hold / 10 ** _decimals;
        uint256 _max_Tran = max_Tran / 10 ** _decimals;

        if (_max_Tran > _max_Hold) {

            _max_Tran = _max_Hold;
        }


        // Return Token Data
        return (_owner,
                RWD_Token,
                _max_Tran,
                _max_Hold,
                Total_buy,
                Total_sell,
                _website,
                _telegram,
                _lplock,
                Creator);

    }
    

    function Set_Presale_CA(address Presale_CA) external onlyOwner {

        _isExcludedFromFee[Presale_CA] = true; 
        _isLimitExempt[Presale_CA] = true;
        _isWhiteListed[Presale_CA] = true;

    }

    // Set Buy and Sell Fees
    function Set_Fees(

        uint8 Marketing_on_BUY, 
        uint8 Liquidity_on_BUY, 
        uint8 Rewards_on_BUY,
        uint8 Burn_on_BUY,

        uint8 Marketing_on_SELL,
        uint8 Liquidity_on_SELL,
        uint8 Rewards_on_SELL,
        uint8 Burn_on_SELL

        ) external onlyOwner {

        // Buyer Protection: Max Fee 15% (includes the 1% contract fee until removed)
        require (Marketing_on_BUY + Liquidity_on_BUY + Rewards_on_BUY + Burn_on_BUY + _fee__Buy_Contract <= 15, "F1");  // Max fee 15%

        // Buyer Protection: Max Fee 15% (includes the 1% contract fee until removed)
        require (Marketing_on_SELL + Liquidity_on_SELL + Rewards_on_SELL + Burn_on_SELL + _fee__Sell_Contract <= 15, "F2");  // Max fee 15%

        // Update Fees
        _fee__Buy_Marketing   = Marketing_on_BUY;
        _fee__Buy_Liquidity   = Liquidity_on_BUY;
        _fee__Buy_Rewards     = Rewards_on_BUY;
        _fee__Buy_Burn        = Burn_on_BUY;

        _fee__Sell_Marketing   = Marketing_on_SELL;
        _fee__Sell_Liquidity   = Liquidity_on_SELL;
        _fee__Sell_Rewards     = Rewards_on_SELL;
        _fee__Sell_Burn        = Burn_on_SELL;

        // Fees For Processing
        _SwapFeeTotal_Sell   = _fee__Sell_Marketing + _fee__Sell_Liquidity + _fee__Sell_Rewards + _fee__Buy_Contract;
        _SwapFeeTotal_Buy    = _fee__Buy_Marketing + _fee__Buy_Liquidity + _fee__Buy_Rewards + _fee__Sell_Contract;

        emit updated_Buy_fees(_fee__Buy_Marketing, _fee__Buy_Liquidity, _fee__Buy_Rewards, _fee__Buy_Burn, _fee__Buy_Contract);
        emit updated_Sell_fees(_fee__Sell_Marketing, _fee__Sell_Liquidity, _fee__Sell_Rewards, _fee__Sell_Burn, _fee__Sell_Contract);
    
    }

    /*
    
    ------------------------------------------
    SET MAX TRANSACTION AND MAX HOLDING LIMITS
    ------------------------------------------

    Solidity can only accept whole numbers. 
    If you want to set a limit to 0.5% enter 0 (This is the minimum permitted value)

    */


    function Set_Wallet_Limits(

        uint256 Max_Transaction_Percent,
        uint256 Max_Wallet_Percent

        ) external onlyOwner {

        if (Max_Transaction_Percent < 1){

            // Defaults to 0.5% if 0 is entered
            max_Tran = _tTotal / 200;

        } else {

            max_Tran = _tTotal * Max_Transaction_Percent / 100;

        }


        if (Max_Wallet_Percent < 1){

            // Defaults to 0.5% if 0 is entered
            max_Hold = _tTotal / 200;

        } else {

            max_Hold = _tTotal * Max_Wallet_Percent / 100;

        }

        emit updated_Wallet_Limits(max_Tran, max_Hold);

    }



    // Open Trade
    function Open_Trade() external onlyOwner {

        require(!Trade_Open, "OPN"); // Trade is already open - Trade can not be paused 
        feeProcessingEnabled = true;
        Trade_Open = true;

        // Check if router and pair have been set
        if (uniswapV2Router == IUniswapV2Router02(0x0000000000000000000000000000000000000000)){


    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); 


                    uniswapV2Router = _uniswapV2Router;
        }

        if (uniswapV2Pair == address(0x0000000000000000000000000000000000000000)) {

            address pairCreated = IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(this), uniswapV2Router.WETH());

                // Check if pair has been created
                if (pairCreated == address(0x0000000000000000000000000000000000000000)){

                    // Create and set the pair
                    uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());

                } else {

                    // Set the pair
                    uniswapV2Pair = pairCreated;
                }
            
        }

        // Set as pair and make limit exempt
        if (!_isPair[uniswapV2Pair]){_isPair[uniswapV2Pair] = true;} 
        if (!_isLimitExempt[uniswapV2Pair]){_isLimitExempt[uniswapV2Pair] = true;}

        _isExcludedFromRewards[uniswapV2Pair] = true;
        _isExcludedFromRewards[address(this)] = true;
        _isExcludedFromRewards[_owner] = true;
        _isExcludedFromRewards[Wallet_Burn] = true;

    }


    /*

    --------------
    FEE PROCESSING 
    --------------

    */


    // Add Liquidity Pair - required for correct fee calculations 
    function addLiquidityPair(

        address Wallet_Address,
        bool true_or_false)

        external onlyOwner {

        _isPair[Wallet_Address] = true_or_false;
        _isLimitExempt[Wallet_Address] = true_or_false;

    } 

    /*
    
    ----------------
    BURN FROM SUPPLY
    ----------------

    Default = false

    If false: Burned tokens are sent to the DEAD address
    If true: Burned tokens are not sent to the DEAD address but are removed from the total supply

    */

    function burnFromTotalSupply(bool true_or_false) external onlyOwner {

        burnFromSupply = true_or_false;
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


    function noFeeWalletTransfers(bool true_or_false) external onlyOwner {

        no_Fee_Transfers = true_or_false;

    }


    // Auto Fee Processing Switch (SwapAndLiquify)
    function swapAndLiquifySwitch(bool true_or_false) external onlyOwner {
        feeProcessingEnabled = true_or_false;
        emit updated_SwapAndLiquify_Enabled(true_or_false);
    }
    
    function swapTriggerCount(uint256 Transaction_Count) external onlyOwner {

        swapTrigger = Transaction_Count + 1; // Reset to 1 (not 0) to save gas
    }

    // Manually Process Fees
    function swapAndLiquifyNow(uint256 Percent_of_Tokens_to_Process) external onlyOwner {

        require(!processingFees); // Already in swap, try later

        if (Percent_of_Tokens_to_Process > 100){Percent_of_Tokens_to_Process = 100;}
        uint256 tokensOnContract = balanceOf(address(this));
        uint256 sendTokens = tokensOnContract * Percent_of_Tokens_to_Process / 100;
        processFees(sendTokens);

    }  

    function removeContractFee() external payable {

        require(msg.value >= 1 * 10 ** 18, "REQ_1BNB"); // Payment too low. To remove the 1% contract fee costs 1 BNB

        uint256 contractFee = msg.value;

            // Check affiliate
            if(Wallet_Affiliate == Wallet_DevFee){

                    // Collect Contract Fee 2% until 2 BNB 
                    send_BNB(Wallet_DevFee, contractFee);

                } else {

                    // Pay affiliate commission based on GEN balance
                    if (GEN.balanceOf(Wallet_Affiliate) > 100000*10**9) {

                        // 20% Affiliate Commission (Affiliate holds 100k or more GEN)
                        send_BNB(Wallet_Affiliate, contractFee * 20 / 100);
                        send_BNB(Wallet_DevFee, contractFee * 80 / 100);

                    } else {

                        // 10% Affiliate Commission (Affiliate holds less than 100k GEN)
                        send_BNB(Wallet_Affiliate, contractFee * 10 / 100);
                        send_BNB(Wallet_DevFee, contractFee * 90 / 100);
                    }
                
                }


        contractFeePaid = true;

        // Remove Contract Fee
        _fee__Buy_Contract  = 0;
        _fee__Sell_Contract = 0;

        // Update Swap Fees
        _SwapFeeTotal_Buy   = _fee__Buy_Liquidity + _fee__Buy_Marketing + _fee__Buy_Rewards;
        _SwapFeeTotal_Sell  = _fee__Sell_Liquidity + _fee__Sell_Marketing + _fee__Sell_Rewards;
    }


    function rescueTrappedTokens(

        address random_Token_Address,
        uint256 number_of_Tokens

        ) external onlyOwner {

            require (random_Token_Address != address(this), "RT"); // Can not remove the native token
            IERC20(random_Token_Address).transfer(msg.sender, number_of_Tokens);
            
    }

    /*

    --------------
    UPDATE PROJECT
    --------------

    */

    function Update_Links_LP_Lock(

        string memory LP_Lock_URL

        ) external onlyOwner{

        _lplock = LP_Lock_URL;

    }

    function Update_Links_Telegram(

        string memory Telegram_Group

        ) external onlyOwner{

        _telegram = Telegram_Group;

    }

    function Update_Links_Website(

        string memory Website_URL

        ) external onlyOwner{

        _website = Website_URL;

    }

    function Update_Wallet_Liquidity(

        address Liquidity_Collection_Wallet

        ) external onlyOwner {

        // Update LP Collection Wallet
        require(Liquidity_Collection_Wallet != address(0), "W"); // Enter a valid BSC Address
        Wallet_Liquidity = Liquidity_Collection_Wallet;

    }

    function Update_Wallet_Marketing(

        address payable Marketing_Wallet

        ) external onlyOwner {

        // Update Marketing Wallet
        require(Marketing_Wallet != address(0), "W"); // Enter a valid BSC Address
        Wallet_Marketing = payable(Marketing_Wallet);

    }


    /*

    -------------
    REWARD TOKENS
    -------------

    */

  

    /*

    The Required_Reward_Balance is the number of reward tokens a person must have before they qualify to receive rewards.

    *** >>>> THIS NUMBER MUST INCLUDE THE DECIMALS! <<<<< ***

    EG: BUSD has 18 decimals. Therefore a 1 and 17 0's is $0.10. The value of non-stable tokens will change over time.
    If your reward token becomes extremely valuable, you may need to lower this amount to ensure people receive their rewards. 

    */

    function setDistributionTriggers(uint256 Minutes_Between_Payments, uint256 Required_Reward_Balance) external onlyOwner {

        // Max Wait is 2 Days
        require(Minutes_Between_Payments <= 2880,"RT"); // Max wait time is 2 days

        // Convert minutes to seconds
        uint256 _minPeriod = Minutes_Between_Payments * 60;

        distributor.setDistributionCriteria(_minPeriod, Required_Reward_Balance);

    }




    /*

    This is the amount of gas we take per transaction (buy or sell) in order to pay for reward distribution.

    The default is 500000, which is 0.0000000000005 BNB

    If BNB goes up in value significantly, you will need to lower this.
    If the gas cost on BSC goes up significantly, you may need to increase this. 
    It's very unlikely that this value will ever need changing.

    If this value is set too high it increases transaction cost and makes your token less attractive to investors. 

    */

    function setDistributionGas(uint256 Gas_Amount) external onlyOwner {

        require(Gas_Amount <= 1000000000000000, "RG"); // Max gas setting is 0.001 BNB (approx $0.30)
        distributorGas = Gas_Amount;

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


    // Used for airdrop to allow transfer to bypass distribution attempt
    function Wallet_ByPass_Distribution(

        address Wallet_Address,
        bool true_or_false

        ) external onlyOwner {    
        _bypassDistribution[Wallet_Address] = true_or_false;
    }


    
    // Exclude wallet from rewards
    function Rewards_Exclude_Wallet(address Wallet_Address, bool true_or_false) external onlyOwner {

        require(Wallet_Address != address(this) && Wallet_Address != uniswapV2Pair);
        _isExcludedFromRewards[Wallet_Address] = true_or_false;

        if(true_or_false){

            distributor.setShare(Wallet_Address, 0);

            } else {

            distributor.setShare(Wallet_Address, _tOwned[Wallet_Address]);
        }
    }

    /* 

    ----------------------------
    CONTRACT OWNERSHIP FUNCTIONS
    ----------------------------


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
        return _tOwned[account];
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
        require(currentAllowance >= subtractedValue, "DA"); // ERC20: decreased allowance below zero
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "APO"); // BEP20: approve from the zero address
        require(spender != address(0), "APS"); // BEP20: approve from the zero address

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
   

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ALL"); // ERC20: transfer amount exceeds allowance
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




        require(balanceOf(from) >= amount, "BAL"); // Sender does not have enough tokens!

       

        if (!Trade_Open){

            require(_isWhiteListed[from] || _isWhiteListed[to], "TC");  // Trade closed, only whitelisted wallets can move tokens


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
        require(from != address(0), "ZF"); // Not a valid BSC wallet address
        require(to != address(0), "ZT"); // Not a valid BSC wallet address
        require(amount > 0, "ZA"); // Amount must be greater than 0

      
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


        if(!_bypassDistribution[from]){

            // Distribute Rewards
            if(!_isExcludedFromRewards[from]) {
                try distributor.setShare(from, _tOwned[from]) {} catch {}
            }

            if(!_isExcludedFromRewards[to]) {
                try distributor.setShare(to, _tOwned[to]) {} catch {} 
            }

            try distributor.process(distributorGas) {} catch {}

        }
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
        uint8 _LiquidityTotal   = _fee__Buy_Liquidity + _fee__Sell_Liquidity;
        uint8 _RewardsTotal     = _fee__Buy_Rewards + _fee__Sell_Rewards;
        uint8 _FeesTotal        = _SwapFeeTotal_Buy + _SwapFeeTotal_Sell;

        // Calculate tokens for swap
        uint256 LP_Tokens       = Tokens * _LiquidityTotal / _FeesTotal / 2;
        uint256 Swap_Tokens     = Tokens - LP_Tokens;

        // Swap Tokens
        uint256 contract_BNB    = address(this).balance;
        swapTokensForBNB(Swap_Tokens);
        uint256 returned_BNB    = address(this).balance - contract_BNB;

        // Avoid Rounding Errors on LP Fee if Odd Number
        uint256 fee_Split       = _FeesTotal * 2 - _LiquidityTotal;

        // Add auto liquidity 
        if (_LiquidityTotal > 0 ) {

            uint256 BNB_Liquidity = returned_BNB * _LiquidityTotal / fee_Split;
            addLiquidity(LP_Tokens, BNB_Liquidity);
            emit SwapAndLiquify(LP_Tokens, BNB_Liquidity, LP_Tokens);
        
        }

        // Deposit Rewards to Distributor contract
        if (_RewardsTotal > 0) {

            uint256 BNB_Rewards = returned_BNB * _RewardsTotal * 2 / fee_Split;
            try distributor.deposit{value: BNB_Rewards}() {} catch {}
            
        }

        if (!contractFeePaid){

            // Calculate and take contract fee (2 = 1% on buys and sells *2 to match fee split to avoid odd number rounding error on LP calculations)
            uint256 BNB_ContractFee = returned_BNB * 2 * 2 / fee_Split;

            // Check affiliate
            if(Wallet_Affiliate == Wallet_DevFee){

                    // Collect Contract Fee 2% until 2 BNB 
                    send_BNB(Wallet_DevFee, BNB_ContractFee);

                } else {

                    // Pay affiliate commission based on GEN balance
                    if (GEN.balanceOf(Wallet_Affiliate) > 100000*10**9) {

                        // 20% Affiliate Commission (Affiliate holds 100k or more GEN)
                        send_BNB(Wallet_Affiliate, BNB_ContractFee * 20 / 100);
                        send_BNB(Wallet_DevFee, BNB_ContractFee * 80 / 100);

                    } else {

                        // 10% Affiliate Commission (Affiliate holds less than 100k GEN)
                        send_BNB(Wallet_Affiliate, BNB_ContractFee * 10 / 100);
                        send_BNB(Wallet_DevFee, BNB_ContractFee * 90 / 100);
                    }
                
                }

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

        uint256 tBurn = 0;
        uint256 tSwapFeeTotal = 0;
        
        if (Fee){

            if(_isPair[recipient]){

                // Sell fees
                tSwapFeeTotal   = tAmount * _SwapFeeTotal_Sell    / 100;
                tBurn           = tAmount * _fee__Sell_Burn       / 100;

            } else {

                // Buy fees
                tSwapFeeTotal   = tAmount * _SwapFeeTotal_Buy     / 100;
                tBurn           = tAmount * _fee__Buy_Burn        / 100;

            }
        }

        uint256 tTransferAmount = tAmount - (tSwapFeeTotal + tBurn);

        // Transfer tokens
        _tOwned[sender] -= tAmount;


        // Send tokens to recipient or remove from supply
        if (recipient == Wallet_Burn && burnFromSupply) {
            _tTotal -= tTransferAmount;
            } else {
            _tOwned[recipient] += tTransferAmount;
        }

        emit Transfer(sender, recipient, tTransferAmount);


        // Take fees that require processing during swap and liquify
        if(tSwapFeeTotal > 0){

            _tOwned[address(this)] += tSwapFeeTotal;

            // Increase the transaction counter
            if(swapCounter < swapTrigger){
                unchecked{swapCounter++;}
            }
                
        }

        // Take burn fee
        if(tBurn > 0){

            if(burnFromSupply){

                _tTotal -= tBurn;

                } else {
           
                _tOwned[Wallet_Burn] += tBurn;
                
            }
                
        }




    }


    // This function is required so that the contract can receive BNB during fee processing
    receive() external payable {}

}



// Dividend distribution contract
contract RewardDistributor is IDividendDistributor {

    address _token;

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }
    
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; 

    address public RWDTKN; 

    IUniswapV2Router02 public DivRouter;

    address[] shareholders;
    mapping (address => uint256) shareholderIndexes;
    mapping (address => uint256) shareholderClaims;

    mapping (address => Share) public shares;

    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public dividendsPerShareAccuracyFactor = 10 ** 36;

    uint256 public minPeriod = 15 * 60; // 15 minutes
    uint256 public minDistribution = 5000000000;

    uint256 currentIndex;

    modifier onlyToken() {
        
        require(msg.sender == _token);
        _;
    }

    constructor (address RWD_CA) {

        
    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);


        DivRouter = _uniswapV2Router;
        _token = msg.sender;
        RWDTKN = RWD_CA;

    }


    function Claim_Rewards() external {
        distributeDividend(msg.sender);
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external override onlyToken {

        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
    }

    function setShare(address shareholder, uint256 amount) external override onlyToken {
        if(shares[shareholder].amount > 0){
            distributeDividend(shareholder);
        }

        if(amount > 0 && shares[shareholder].amount == 0){
            addShareholder(shareholder);
        }else if(amount == 0 && shares[shareholder].amount > 0){
            removeShareholder(shareholder);
        }

        totalShares = totalShares + amount - shares[shareholder].amount;
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
    }

    function deposit() external payable override onlyToken {

        uint256 balanceBefore = IERC20(RWDTKN).balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = address(RWDTKN);

        DivRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amount = IERC20(RWDTKN).balanceOf(address(this)) - balanceBefore;
        totalDividends += amount;
        dividendsPerShare = dividendsPerShare + (dividendsPerShareAccuracyFactor * amount / totalShares);

    }

    function process(uint256 gas) external override onlyToken {

        uint256 shareholderCount = shareholders.length;

        if(shareholderCount == 0) { return; }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        uint256 iterations = 0;

        while(gasUsed < gas && iterations < shareholderCount) {
            if(currentIndex >= shareholderCount){
                currentIndex = 0;
            }

            if(shouldDistribute(shareholders[currentIndex])){
                distributeDividend(shareholders[currentIndex]);
            }

            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }


    function shouldDistribute(address shareholder) internal view returns (bool) {
        return shareholderClaims[shareholder] + minPeriod < block.timestamp
                && getUnpaidEarnings(shareholder) > minDistribution;
    }


    function distributeDividend(address shareholder) internal {

        if(shares[shareholder].amount == 0){

            return;
        }

        uint256 amount = getUnpaidEarnings(shareholder);

        if(amount > 0){

            totalDistributed += amount;
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised += amount;
            shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
   
            IERC20(RWDTKN).transfer(shareholder, amount);
        }
    }

    function getUnpaidEarnings(address shareholder) public view returns (uint256) {


        if(shares[shareholder].amount == 0){ return 0; }

        uint256 shareholderTotalDividends = getCumulativeDividends(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;

        if(shareholderTotalDividends <= shareholderTotalExcluded){ return 0; }

        return shareholderTotalDividends - shareholderTotalExcluded;
    }

    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        return share*dividendsPerShare/dividendsPerShareAccuracyFactor;
    }

    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length-1];
        shareholderIndexes[shareholders[shareholders.length-1]] = shareholderIndexes[shareholder];
        shareholders.pop();
    }

      receive() external payable {}


}





/*


    Token Created at https://TokensByGen.com
    This contract is not open source - Can not be used or forked without permission.
    

*/