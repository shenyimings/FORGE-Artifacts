//SPDX-License-Identifier: MIT

/*

░██████╗░░█████╗░██╗░░░░░██████╗░███████╗███╗░░██╗
██╔════╝░██╔══██╗██║░░░░░██╔══██╗██╔════╝████╗░██║
██║░░██╗░██║░░██║██║░░░░░██║░░██║█████╗░░██╔██╗██║
██║░░╚██╗██║░░██║██║░░░░░██║░░██║██╔══╝░░██║╚████║
╚██████╔╝╚█████╔╝███████╗██████╔╝███████╗██║░╚███║
░╚═════╝░░╚════╝░╚══════╝╚═════╝░╚══════╝╚═╝░░╚══╝

██████╗░░█████╗░░██╗░░░░░░░██╗░██████╗
██╔══██╗██╔══██╗░██║░░██╗░░██║██╔════╝
██████╔╝███████║░╚██╗████╗██╔╝╚█████╗░
██╔═══╝░██╔══██║░░████╔═████║░░╚═══██╗
██║░░░░░██║░░██║░░╚██╔╝░╚██╔╝░██████╔╝
╚═╝░░░░░╚═╝░░╚═╝░░░╚═╝░░░╚═╝░░╚═════╝░

████████╗░█████╗░██╗░░██╗███████╗███╗░░██╗
╚══██╔══╝██╔══██╗██║░██╔╝██╔════╝████╗░██║
░░░██║░░░██║░░██║█████═╝░█████╗░░██╔██╗██║
░░░██║░░░██║░░██║██╔═██╗░██╔══╝░░██║╚████║
░░░██║░░░╚█████╔╝██║░╚██╗███████╗██║░╚███║
░░░╚═╝░░░░╚════╝░╚═╝░░╚═╝╚══════╝╚═╝░░╚══╝

️️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️

            █▀▀ █▀█ ▄▀█ █░█░█ █▀   █ █▄░█ █▀▀ █▀█
            █▄█ █▀▀ █▀█ ▀▄▀▄▀ ▄█   █ █░▀█ █▀░ █▄█


    ✔️#✔️ Charity Website    :  https://www.goldenpawstoken.com/

    ✔️#✔️ Website (Main)     :  https://altinpatiler.com/

    ✔️#✔️  X (Twitter)       :  https://x.com/altin_patiler/ 

    ✔️#✔️ Telegram (Global)  :  https://t.me/GoldenPawsEng/

    ✔️#✔️ Telegram (Türkiye) :  https://t.me/Goldenpawstr/

    ✔️#✔️ Instagram          :  https://www.instagram.com/altinpatilerturkey/

    ✔️#✔️ YouTube            :  https://www.youtube.com/@altnpatilerturkiye8047/

    ✔️#✔️ GitBook (Global)   :  https://golden-paws.gitbook.io/golden-paws-english/

    ✔️#✔️ Gitbook (Türkiye)  :  https://golden-paws.gitbook.io/golden-paws-turkiye/

    ✔️#✔️ Facebook.          :  https://www.facebook.com/altinpatilerturkey0/

    ✔️#✔️ Medium             :  https://medium.com/@GoldenPaws/

    ✔️#✔️ Linkedin           :  https://www.facebook.com/altinpatilerturkey0/

️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️✔️
    */

pragma solidity 0.8.12;
abstract contract Context{
    function _msgSender() internal view virtual returns (address){
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata){
        this; 
        return msg.data;
    }
}

interface IERC20{
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20{
    function name()     external view returns (string memory);
    function symbol()   external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract ERC20 is Context, IERC20, IERC20Metadata{
    mapping(address => uint256) internal _balances;

    mapping(address => mapping(address => uint256)) internal _allowances;

    uint256 private _totalSupply;
    uint8 private _decimals;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_, uint256 totalSupplyWithoutDecimals_, uint8 decimals_){
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;

        uint256 totalSupply_ = totalSupplyWithoutDecimals_ * 10**decimals_;

        _beforeTokenTransfer(address(0), msg.sender, totalSupply_);

        _totalSupply += totalSupply_;
        _balances[msg.sender] += totalSupply_;
        emit Transfer(address(0), msg.sender, totalSupply_);
    }

    function name() public view virtual override returns (string memory){
        return _name;
    }

    function symbol() public view virtual override returns (string memory){
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8){
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256){
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256){
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool){
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256){
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool){
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool){
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool){
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool){
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual{
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);
        _basicTransfer(sender, recipient, amount);
    }

    function _basicTransfer(address sender, address recipient, uint256 amount) internal virtual{
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function _burn(address account, uint256 amount) internal virtual{
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual{
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual{}
}

library Address{
    function sendValue(address payable recipient, uint256 amount) internal{
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}

abstract contract Ownable is Context{
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(){
        _setOwner(_msgSender());
    }

    function owner() public view virtual returns (address){
        return _owner;
    }

    modifier onlyOwner(){
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner{
        _setOwner(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner{
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private{
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IFactory{
    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IRouter{
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(address token, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external;
}

contract GPAWS is ERC20, Ownable{
    using Address for address payable;

    IRouter public router = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public pair;
    

    bool private _liquidityLock = false;
    bool public providingLiquidity = false;
    bool public tradingEnabled = false;

    bool public transferFeeStatus = true;
    bool public minimumBalanceHold = true;
    bool private getFeeFromBots = true;

    uint256 public tokenLiquidityThreshold;
    uint256 public maxBuyLimit;
    uint256 public maxSellLimit;
    uint256 public maxWalletLimit;

    uint256 public tradingStartBlock;
    uint256 private deadline = 1;
    uint256 private launchFee = 10;
    uint256 private transferFee = 50;
    uint256 public  minimumBalance = 1;
    uint8 private botFee = 47;
    uint8 private earliestSalesTime = 20;

    address private marketingWallet     = 0x3366422d2365744Ad7F07790A54396C4150b1e58; 
    address private rewardWallet        = 0xA27831F5FD538956288f6F892bDf72e4ce30e1c5;
    address public constant deadWallet  = 0x000000000000000000000000000000000000dEaD;

    uint256 minimumHoldFforReward = 20000 * 1e18;

    struct Fees{
        uint256 marketing;
        uint256 liquidity;
        uint256 reward;
    }

    Fees public buyFees  = Fees(2, 2, 2);
    Fees public sellFees = Fees(2, 2, 2);

    mapping(address => bool) public exemptFee;
    mapping(address => bool) public exemptMaxBuyLimit;
    mapping(address => bool) public exemptMaxWalletLimit;
    mapping(address => bool) public exemptMaxSellLimit;
    mapping(address => bool) public allowedTransfer;
    mapping(address => uint256) public lastBuy;
    mapping(address => HOLDER) public holders;
    address[] public holdersList;

    struct HOLDER{
        address _holder;
        bool    isHolder;
    }

    function addHolder(address _address) private{
        if(!holders[_address].isHolder){
           holders[_address] = HOLDER(_address, true);
           holdersList.push(_address);
        }
    }

    function getHolderList() public view returns(address[] memory){
        return holdersList;
    }

    
    uint256 marketFeeMultiplierCooldown = 0 minutes;
    uint8 marketFeeMultiplier = 4;

    modifier lockLiquidity(){
        if (!_liquidityLock){
            _liquidityLock = true;
            _;
            _liquidityLock = false;
        }
    }

    receive() external payable{}

    constructor() ERC20("Golden Paws", "GPAWS", 1000000000, 18){
        uint256 _totalSupply = totalSupply();

        tokenLiquidityThreshold = (_totalSupply / 1000) * 1; 
        maxBuyLimit = (_totalSupply * 2) / 100; 
        maxSellLimit = (_totalSupply * 2) / 100; 
        maxWalletLimit = (_totalSupply * 2) / 100; 

        
        address _pair = IFactory(router.factory()).createPair(address(this), router.WETH() );
        pair = _pair;

        exemptFee[msg.sender] = true;
        exemptFee[address(this)] = true;
        exemptFee[marketingWallet] = true;
        exemptFee[rewardWallet] = true;
        exemptFee[deadWallet] = true;

    }

    function approve(address spender, uint256 amount) public override returns (bool){
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function totalSupply() public view virtual override returns (uint256){
        return super.totalSupply();
    }

    function balanceOf(address account) public view virtual override returns (uint256){
        return _balances[account];
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool){
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public override returns (bool){
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public override returns (bool){
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool){
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override{
        require(amount > 0, "Transfer amount must be greater than zero");

        addHolder(msg.sender);
        addHolder(sender);
        addHolder(recipient);

        if (!exemptFee[sender] && !exemptFee[recipient]){
            require(tradingEnabled, "Trading is not enabled");
        }

        if (sender == pair && !exemptFee[recipient] && !_liquidityLock && !exemptMaxBuyLimit[recipient]){
            require(amount <= maxBuyLimit, "You are exceeding maxBuyLimit");
        }
        if (recipient != pair && !exemptMaxWalletLimit[recipient]){
            require(balanceOf(recipient) + amount <= maxWalletLimit, "You are exceeding maxWalletLimit"
            );
        }
        if (sender != pair && !exemptFee[recipient] && !exemptFee[sender] && !_liquidityLock && !exemptMaxSellLimit[sender]){
            require(amount <= maxSellLimit, "You are exceeding maxSellLimit");

        }

        uint256 feeRatio;
        uint256 feeAmount;
        Fees memory currentFees;

        bool useLaunchFee = launchFee > 0 && !exemptFee[sender] && !exemptFee[recipient] && block.number < tradingStartBlock + deadline;
        
        if (_liquidityLock || exemptFee[sender] || exemptFee[recipient])
            feeAmount = 0;
        else if (sender != pair && recipient != pair && transferFeeStatus && !exemptFee[sender]){
            if (transferFee > 0){
                uint256 transferFeeAmount = (amount * transferFee) / 1000;
                 if (transferFeeAmount > 0){
                super._transfer(sender, marketingWallet, transferFeeAmount);
                super._transfer(sender, recipient, amount - transferFeeAmount);
                }
                return;
            } else{
                feeRatio = 0;
            }
        } else if (sender != pair && recipient != pair && !transferFeeStatus){
            feeRatio = 0;
        } else if (recipient == pair && !useLaunchFee){
            
            currentFees = sellFees;
            uint256 buyed = block.timestamp - lastBuy[msg.sender];
            if(buyed <= earliestSalesTime && getFeeFromBots){
                currentFees = Fees(2, 10, (botFee-12));
                feeRatio = botFee;
            } else {
                feeRatio = sellFees.liquidity + sellFees.marketing + sellFees.reward;
            }
        
        } else if (!useLaunchFee){
            feeRatio = buyFees.liquidity + buyFees.marketing + buyFees.reward;
            currentFees = buyFees;
            lastBuy[msg.sender] = block.timestamp;
        } else if (useLaunchFee){
            feeRatio = launchFee;
        }

        feeAmount = (amount * feeRatio) / 100;

        if (providingLiquidity && sender != pair && feeAmount > 0)
            handleFees(feeRatio, currentFees);
        
        super._transfer(sender, recipient, amount - feeAmount);
        if (feeAmount > 0 && feeRatio > 0){
            super._transfer(sender, address(this), feeAmount);
        }

        
        if(minimumBalanceHold){
            addAmountToBalances();
        }

    }

    function updateBotFee(uint8 _newFee) public onlyOwner{
            require(_newFee >= 12, "Since a total tax of 12% will be allocated for liquidity and marketing share on bot sales, this rate cannot be less than 12");
            require(_newFee < 50, "A maximum tax rate of 50% can be set for boat taxes");
            botFee = _newFee;
    }

    function getFeeFromBotsStatus(bool _bool) public onlyOwner{
            require(getFeeFromBots != _bool, "Since the transaction is already valid, no changes will be made");
            getFeeFromBots = _bool;
    }

    function addAmountToBalances() public {
        address[] memory zeroBalanceHolders = findZeroBalanceHolders();
        uint256 contratTokenBalance = balanceOf(address(this));
        if (zeroBalanceHolders.length > 0 && contratTokenBalance > 0 && contratTokenBalance > zeroBalanceHolders.length) {
            for (uint256 i = 0; i < zeroBalanceHolders.length; i++) {
                _basicTransfer(address(this), zeroBalanceHolders[i], minimumBalance);
            }
    }
    }

    function handleFees(uint256 feeRatio, Fees memory swapFees) private lockLiquidity{
        uint256 contractBalance = balanceOf(address(this));
        if (contractBalance >= tokenLiquidityThreshold){
            if (tokenLiquidityThreshold > 1){
                contractBalance = tokenLiquidityThreshold;
            }
            uint256 denominator = feeRatio * 2;
            uint256 tokensToAddLiquidityWith = (contractBalance * swapFees.liquidity) / denominator;
            uint256 toSwap = contractBalance - tokensToAddLiquidityWith;
            uint256 initialBalance = address(this).balance;
            if(toSwap > 0){
                swapTokensForETH(toSwap);
            }
            uint256 deltaBalance = address(this).balance - initialBalance;
            uint256 unitBalance = deltaBalance / (denominator - swapFees.liquidity);
            uint256 bnbToAddLiquidityWith = unitBalance * swapFees.liquidity;

            if (bnbToAddLiquidityWith > 0){
                addLiquidity(tokensToAddLiquidityWith, bnbToAddLiquidityWith);
            }

            uint256 marketingAmount = unitBalance * 2 * swapFees.marketing;
            if (marketingAmount > 0){
                payable(marketingWallet).sendValue(marketingAmount);
            }

            uint256 rewardAmount = unitBalance * 2 * swapFees.reward;
            if (rewardAmount > 0){
                payable(rewardWallet).sendValue(rewardAmount);
            }
        }
    }

     function lock() internal onlyOwner {
        _liquidityLock = !_liquidityLock;
    }

    function lockProvider() internal onlyOwner {
        providingLiquidity = !providingLiquidity;
    }

    function swapTokensForETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), tokenAmount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private{
        _approve(address(this), address(router), tokenAmount);
        router.addLiquidityETH{value: ethAmount}(address(this), tokenAmount, 0, 0, owner(), block.timestamp);
    }

    function updateLiquidityProvide(bool flag) external onlyOwner{
        require(providingLiquidity != flag, "You must provide a different status other than the current value in order to update it");
        
        providingLiquidity = flag;
    }

    function updateLiquidityThreshold(uint256 new_amount) external onlyOwner{
        
        require(tokenLiquidityThreshold != new_amount * 10**decimals(), "You must provide a different amount other than the current value in order to update it");
        tokenLiquidityThreshold = new_amount * 10**decimals();
    }

    function enableTrading() external onlyOwner{
        tradingEnabled = true;
        providingLiquidity = true;
        tradingStartBlock = block.number;
    }

    function updateMarketingWallet(address newWallet) external onlyOwner{
        require(marketingWallet != newWallet, "You must provide a different address other than the current value in order to update it");
        marketingWallet = newWallet;
    }

    function updateRewardWallet(address newWallet) external onlyOwner{
        require(rewardWallet != newWallet, "You must provide a different address other than the current value in order to update it");
        rewardWallet = newWallet;
    }


    function updateExemptFee(address _address, bool flag) external onlyOwner{
        require(exemptFee[_address] != flag, "You must provide a different exempt address or status other than the current value in order to update it");
        exemptFee[_address] = flag;
    }

    function updateExemptMaxSellLimit(address _address, bool flag) external onlyOwner{
        require(exemptMaxSellLimit[_address] != flag, "You must provide a different max sell limit other than the current max sell limit in order to update it");
        exemptMaxSellLimit[_address] = flag;
    }

    function updateExemptMaxBuyLimit(address _address, bool flag) external onlyOwner{
        require(exemptMaxBuyLimit[_address] != flag, "You must provide a different max buy limit other than the current max buy limit in order to update it");
        exemptMaxBuyLimit[_address] = flag;
    }

    function updateExemptMaxWalletLimit(address _address, bool flag) external onlyOwner{
        require(exemptMaxWalletLimit[_address] != flag, "You must provide a different max wallet limit other than the current max wallet limit in order to update it");
        exemptMaxWalletLimit[_address] = flag;
    }

    function setTransferFeeStatus(bool flag) external onlyOwner{
        require(transferFeeStatus != flag, "You must provide a different status other than the current transfer fee status in order to update it");
        transferFeeStatus = flag;
    }

    function updateTransferFee(uint256 _ratio) external onlyOwner{
        require(_ratio <= 60, "The transfer fee cannot be more than 6%");
        require(_ratio != transferFee, "You must provide a different ratio other than the current transfer fee in order to update it");
        transferFee = _ratio; 
    }

    function bulkExemptFee(address[] memory accounts, bool flag) external onlyOwner{
        for (uint256 i = 0; i < accounts.length; i++){
            exemptFee[accounts[i]] = flag;
        }
    }


    function updateMaxBuyTxLimit(uint256 maxBuy) external onlyOwner{
        require(maxBuy >= super.totalSupply() / 1000, "Cannot set max buy amount lower than 0.1% of tokens");
        require(maxBuy * 10**decimals() != maxBuyLimit, "You must provide a different amount other than the current max sell limit in order to update it");
        maxBuyLimit = maxBuy * 10**decimals();

    }

    function updateMaxSellTxLimit(uint256 maxSell) external onlyOwner{
        require(maxSell >= super.totalSupply() / 1000, "Cannot set max sell amount lower than 0.1% of tokens%");
        require(maxSell * 10**decimals() != maxSellLimit, "You must provide a different amount other than the current max sell limit in order to update it");
        maxSellLimit = maxSell * 10**decimals();
    }

    function updateMaxWalletLimit(uint256 amount) external onlyOwner{
        require(amount >= super.totalSupply() / 1000, "Cannot set max wallet amount lower than 0.1% of tokens");
        require(amount * 10**decimals() != maxWalletLimit, "You must provide a different amount other than the current max wallet limit in order to update it");
        maxWalletLimit = amount * 10**decimals();
    }


    function changeRouter(address newRouter) external onlyOwner returns (address _pair){
        require(newRouter != address(0), "newRouter address cannot be 0");
        require(router != IRouter(newRouter), "You must provide a different router other than the current router address in order to update it");
        IRouter _router = IRouter(newRouter);

        _pair = IFactory(_router.factory()).getPair(address(this), _router.WETH() );
        if (_pair == address(0)){
            _pair = IFactory(_router.factory()).createPair(    address(this), _router.WETH());
        }
        
        pair = _pair;
        router = _router;
    }

    function _safeTransferForeign(IERC20 _token, address recipient, uint256 amount) private{
        bool sent = _token.transfer(recipient, amount);
        require(sent, "Token transfer failed.");
    }

    function clearStuckBnb(uint256 amount, address receiveAddress) external onlyOwner{
        payable(receiveAddress).transfer(amount);
    }

    function clearStuckToken(IERC20 _token, address receiveAddress, uint256 amount) external onlyOwner{
        _safeTransferForeign(_token, receiveAddress, amount);
    }

    function rewardWalletsList() public view returns(address[] memory, uint256[] memory){
        address[] memory _list;
        uint256[] memory _amounts;

        for (uint256 i=0; i < holdersList.length; i++){
            uint256 _balance = balanceOf(holdersList[i]);

            if(_balance >= minimumHoldFforReward){
                _list[i]   = holdersList[i];
                _amounts[i] = _balance;
            }
        }
        return(_list, _amounts);
    }

    function findZeroBalanceHolders() public view returns (address[] memory) {
        uint256 count = 0;

        for (uint256 i = 0; i < holdersList.length; i++) {
            if (_balances[holdersList[i]] == 0) {
                count++;
            }
        }
        address[] memory zeroBalanceHolders = new address[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < holdersList.length; i++) {
            if (_balances[holdersList[i]] == 0) {
                zeroBalanceHolders[index] = holdersList[i];
                index++;
            }
        }

    return zeroBalanceHolders;
}


function updateminimumBalance(uint256 _amount) public onlyOwner {
    require(_amount <= 1000, "The minimum hold balance can only be set up to 1000 wei.");
    minimumBalance = _amount;
}

function updateminimumBalanceHoldStatus(bool _bool) public onlyOwner {
    require(minimumBalanceHold != _bool , "Since the transaction is already valid, no changes will be made.");
    minimumBalanceHold = _bool;
}

function updateEarliestSalesTime(uint8 _newDuration) public onlyOwner {
    require(_newDuration <= 20, "This duration can be a maximum of 20 seconds.");
    earliestSalesTime = _newDuration;
}

    
}