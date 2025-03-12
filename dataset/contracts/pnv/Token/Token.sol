//SPDX-License-Identifier: MIT

pragma solidity = 0.8.16;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }
}

/**
 * BEP20 standard interface.
 */
interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * Allows for contract ownership along with multi-address ownerLeaders
 */
abstract contract Auth {
    address internal owner;

    constructor(address _owner) {
        owner = _owner;    
    }

    /**
     * Function modifier to require caller to be contract owner
     */
    modifier onlyOwner() {
        require(isOwner(msg.sender), "!OWNER"); _;
    }

    /**
     * Check if address is owner
     */
    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }

    /**
     * Transfer ownership to new address. Caller must be owner. Leaves old owner ownerLeaded
     */
    function transferOwnership(address payable adr) public virtual onlyOwner {
        require(adr != address(0),"Ownable: new owner is the zero address");
       
        owner = adr;
        emit OwnershipTransferred(adr);
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(address(0));
        owner = address(0);
    }   

    event OwnershipTransferred(address owner);
}

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
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

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

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

interface IDividendDistributor {
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external;
    function setShare(address shareholder, uint256 amount) external;
    function deposit() external payable;
    function process(uint256 gas) external;
}

contract DividendDistributor is IDividendDistributor {
    using SafeMath for uint256;

    address _token;

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    IBEP20 REWARD = IBEP20(WBNB);
    IDEXRouter router;

    address[] investors;
    mapping (address => uint256) shareholderIndexes;
    mapping (address => uint256) shareholderClaims;

    mapping (address => Share) public shares;

    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public dividendsPerShareAccuracyFactor = 10 ** 36;

    //SETMEUP, change this to 1 hour instead of 10mins
    uint256 public minPeriod = 10 minutes;
    uint256 public minDistribution = 10 * (10 **18);

    uint256 currentIndex;

    bool initialized;
    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }

    modifier onlyToken() {
        require(msg.sender == _token); _;
    }

    constructor (address _router) {
        router = _router != address(0)
            ? IDEXRouter(_router)
            // : IDEXRouter(0xD99D1c33F9fC3444f8101754aBC46c52416550D1); // TESTNET ONLY
            : IDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E); // MAINNET ONLY
        _token = msg.sender;
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

        totalShares = totalShares.sub(shares[shareholder].amount).add(amount);
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
    }

    function setRewardToken(address _address) external onlyToken {
        REWARD = IBEP20(_address);
    }    

    function setWBNB(address _address) external onlyToken {
        require(_address != address(0), "Cannot ste zero address!");
        WBNB = _address;
    }

    function deposit() external payable override onlyToken {
        uint256 balanceBefore = REWARD.balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = address(REWARD);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amount = REWARD.balanceOf(address(this)).sub(balanceBefore);

        totalDividends = totalDividends.add(amount);
        dividendsPerShare = dividendsPerShare.add(dividendsPerShareAccuracyFactor.mul(amount).div(totalShares));
    }

    function process(uint256 gas) external override onlyToken {
        uint256 shareholderCount = investors.length;

        if(shareholderCount == 0) { return; }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        uint256 iterations = 0;

        while(gasUsed < gas && iterations < shareholderCount) {
            if(currentIndex >= shareholderCount){
                currentIndex = 0;
            }

            if(shouldDistribute(investors[currentIndex])){
                distributeDividend(investors[currentIndex]);
            }

            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
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
        if(shares[shareholder].amount == 0){ return; }

        uint256 amount = getUnpaidEarnings(shareholder);
        if(amount > 0){
            totalDistributed = totalDistributed.add(amount);
            REWARD.transfer(shareholder, amount);
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder].totalRealised.add(amount);
            shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
        }
    }

    function claimDividend() external {
        distributeDividend(msg.sender);
    }

    function getUnpaidEarnings(address shareholder) public view returns (uint256) {
        if(shares[shareholder].amount == 0){ return 0; }

        uint256 shareholderTotalDividends = getCumulativeDividends(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;

        if(shareholderTotalDividends <= shareholderTotalExcluded){ return 0; }

        return shareholderTotalDividends.sub(shareholderTotalExcluded);
    }

    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        return share.mul(dividendsPerShare).div(dividendsPerShareAccuracyFactor);
    }

    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = investors.length;
        investors.push(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        investors[shareholderIndexes[shareholder]] = investors[investors.length-1];
        shareholderIndexes[investors[investors.length-1]] = shareholderIndexes[shareholder];
        investors.pop();
    }
}

contract Token is IBEP20, Auth {
    using SafeMath for uint256;

    address public REWARD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; //Busd
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address public constant ZERO = 0x0000000000000000000000000000000000000000;
    address public MKT = 0x1cAcb4979dACAEF191b9A67341e739ce6997dEF5;

    string public constant _name = "Payinnov Protocol";
    string public constant _symbol = "PNV";
    uint8 public constant _decimals = 18;

    uint256 _totalSupply = 10_000_000_000 * (10**_decimals); 

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) public isFeeExempt;
    mapping (address => bool) public isDividendExempt;

    // Fee for all transactions transfer
    uint256 public transferFee = 0;

    // Fee for all transactions buy
    uint256 public totalBuyFee = 50; //Fee for all buy transactions 

    // Sell fee distribution
    uint256 public liquidityFee = 10;
    uint256 public reflectionFee = 20;
    uint256 public marketingFee = 20; 
    uint256 public stakingFee = 0; 
    uint256 public totalFee = liquidityFee.add(marketingFee).add(stakingFee).add(reflectionFee);
    uint256 constant public feeDenominator = 1000;
    uint256 constant public maxFee = 200;

    address public autoLiquidityReceiver = MKT;
    address public marketingFeeReceiver = MKT;
    address public stakingReceiver = MKT;

    uint256 public targetLiquidity = 20;
    uint256 public targetLiquidityDenominator = 100;

    IDEXRouter public router;
    address public pair;

    bool public swapTokenEnabled = false;

    event AdminTokenRecovery(address tokenAddress, uint256 tokenAmount);    
    event TransferBuyFeeUpdated(uint256 transferFee, uint256 totalBuyFee); 
    event FeeDistributionUpdated(uint256 liquidityFee, uint256 reflectionFee, uint256 marketingFee, uint256 stakingFee);
    event TargetLiquidityUpdated(uint256 targetLiquidity, uint256 targetLiquidityDenominator);
    event DistributionCriteriaUpdated(uint256 minPeriod, uint256 minDistribution);

    DividendDistributor public immutable distributor;
    uint256 distributorGas = 300_000;

    mapping (address => bool) private isAutorizerAddress;
    mapping (address => bool) private isLpPair;

    bool public swapEnabled = true;
    uint256 public swapThreshold = _totalSupply.mul(10).div(10000); //0.01% of supply
    bool inSwap;

    modifier swapping() { inSwap = true; _; inSwap = false; }
    
    modifier isAutorizer {require(isAutorizerAddress[msg.sender], "Not an authorized address");_; }

    constructor () Auth(msg.sender) {
        // router = IDEXRouter(0xD99D1c33F9fC3444f8101754aBC46c52416550D1); // TESTNET ONLY
        router = IDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E); // MAINNET ONLY
        pair = IDEXFactory(router.factory()).createPair(WBNB, address(this));
        isLpPair[pair] = true;
        _allowances[address(this)][address(router)] = type(uint256).max;

        distributor = new DividendDistributor(address(router));

        isFeeExempt[msg.sender] = true;
        isFeeExempt[DEAD] = true;
        isFeeExempt[MKT] = true;

        isDividendExempt[pair] = true;
        isDividendExempt[address(this)] = true;
        isDividendExempt[DEAD] = true;

        isAutorizerAddress[msg.sender] = true;

        _balances[msg.sender] = _totalSupply;
        
        distributor.setRewardToken(REWARD);
        distributor.setWBNB(WBNB);

        emit Transfer(address(0), msg.sender, _totalSupply); 
    }

    receive() external payable { }

    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function decimals() external pure override returns (uint8) { return _decimals; }
    function symbol() external pure override returns (string memory) { return _symbol; }
    function name() external pure override returns (string memory) { return _name; }
    function getOwner() external view override returns (address) { return owner; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            require(_allowances[sender][msg.sender] >= amount, "Insufficient Allowance");
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount);
        }

        return _transferFrom(sender, recipient, amount);
    }

    function setRewardToken(address _rewardTokenAddress) external onlyOwner {
        require(
            _rewardTokenAddress != DEAD &&
            _rewardTokenAddress != pair &&
            _rewardTokenAddress != owner,
            "Invalid reward token address"
        );

        REWARD = _rewardTokenAddress;
        distributor.setRewardToken(_rewardTokenAddress);
    }

    function claimDividend() external {
        distributor.claimDividend();
    }
   

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if(inSwap){ return _basicTransfer(sender, recipient, amount); }

         if (isLimitedAddress(sender,recipient)) {
            require(swapTokenEnabled,"Token is paused");
        }

        // Liquidity, Maintained at 25%
        if (shouldSwapBack()) {
            if (is_sell(sender, recipient)) {
                swapBack();
            }
        }

        //Exchange tokens
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        
        uint256 amountReceived  = shouldTakeFee(sender, recipient) ? takeFee(sender, is_buy(sender, recipient), is_sell(sender, recipient), amount) : amount;
                  
      
        _balances[recipient] = _balances[recipient].add(amountReceived);

        // Dividend tracker
        if (!isDividendExempt[sender]) {
            try distributor.setShare(sender, _balances[sender]) {} catch {}
        }

        if (!isDividendExempt[recipient]) {
            try distributor.setShare(recipient, _balances[recipient]) {} catch {}
        }

        try distributor.process(distributorGas) {} catch {}

        emit Transfer(sender, recipient, amountReceived);
        return true;            
    }

    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function shouldTakeFee(address sender, address recipient) internal view returns (bool) {
        return !(isFeeExempt[sender] || isFeeExempt[recipient]);
    }

    function takeFee(address from, bool isbuy, bool issell, uint256 amount) internal returns (uint256) {
        uint256 fee;
        if (isbuy)
          fee = totalBuyFee;
        else if (issell)  
          fee = totalFee;
        else  
        fee = transferFee; 

        if (fee == 0) 
            return amount; 

        uint256 feeAmount = amount.mul(fee).div(feeDenominator);

        if (feeAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(feeAmount);
            emit Transfer(from, address(this), feeAmount);            
        }
        return amount.sub(feeAmount);
    }

    function shouldSwapBack() internal view returns (bool) {
        return msg.sender != pair
        && !inSwap
        && swapEnabled
        && _balances[address(this)] >= swapThreshold;
    }

    function is_buy(address ins, address out) internal view returns (bool) {
        bool _is_buy = !isLpPair[out] && isLpPair[ins];
        return _is_buy;
    }

    function is_sell(address ins, address out) internal view returns (bool) { 
        bool _is_sell = isLpPair[out] && !isLpPair[ins];
        return _is_sell;
    }

    function isLimitedAddress(address ins, address out) internal view returns (bool) {
        bool isLimited = ins != owner
            && out != owner && msg.sender != owner
            && !isAutorizerAddress[ins]  && !isAutorizerAddress[out] && out != DEAD && out != address(0) && out != address(this);
            return isLimited;
    }

    function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
        isFeeExempt[holder] = exempt;
    }

    function changeLpPair(address newPair,bool yesno) external isAutorizer {
        isLpPair[newPair] = yesno;
    }
    function getLpPair(address _contract) external view returns(bool) {
        return isLpPair[_contract];
    }

    // switch Trading
    function EnableTrading() external onlyOwner {
        require(!swapTokenEnabled, "Cannot re-enable trading");
        swapTokenEnabled = true;
    }

     function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external isAutorizer {
        require(_tokenAddress != address(this), "Cannot be this token");
        IBEP20(_tokenAddress).transfer(address(msg.sender), _tokenAmount);
        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    function swapBack() internal swapping {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WBNB;
        uint256 balanceBefore = address(this).balance;

        if (totalFee > 0) {
            uint256 dynamicLiquidityFee = isOverLiquified(targetLiquidity, targetLiquidityDenominator) ? 0 : liquidityFee;
            uint256 amountToLiquify = balanceOf(address(this)).mul(dynamicLiquidityFee).div(totalFee).div(2);
            uint256 amountToSwap = balanceOf(address(this)).sub(amountToLiquify);

            router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                amountToSwap,
                0,
                path,
                address(this),
                block.timestamp
            );

            uint256 amountBNB = address(this).balance.sub(balanceBefore);
            uint256 totalBNBFee = totalFee.sub(dynamicLiquidityFee.div(2));
            uint256 amountBNBLiquidity = amountBNB.mul(dynamicLiquidityFee).div(totalBNBFee).div(2);
            uint256 amountBNBReflection = amountBNB.mul(reflectionFee).div(totalBNBFee);
            uint256 amountBNBStaking = amountBNB.mul(stakingFee).div(totalBNBFee);
            uint256 amountBNBMarketing = amountBNB.mul(marketingFee).div(totalBNBFee);


            if (stakingFee > 0) {
                (bool success,) = payable(stakingReceiver).call{value: amountBNBStaking, gas: 30000}("");
                require(success, "Failed to send BNB to staking receiver");
            }

            if (reflectionFee > 0) {
                try distributor.deposit{value: amountBNBReflection}() {} catch {}
            }
            if (marketingFee > 0) {
                (bool success,) = payable(marketingFeeReceiver).call{value: amountBNBMarketing, gas: 30000}("");
                require(success, "Failed to send BNB to marketing fee receiver");
            }

            if (amountToLiquify > 0) {
                router.addLiquidityETH{value: amountBNBLiquidity}(
                    address(this),
                    amountToLiquify,
                    0,
                    0,
                    autoLiquidityReceiver,
                    block.timestamp
                );
                emit AutoLiquify(amountBNBLiquidity, amountToLiquify);
            }
        } else if (balanceOf(address(this)) > 0) {
            router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                balanceOf(address(this)),
                0,
                path,
                address(this),
                block.timestamp
            );
            uint256 amountBNB = address(this).balance.sub(balanceBefore);
            (bool success,) = payable(marketingFeeReceiver).call{value: amountBNB, gas: 30000}("");
            require(success, "Failed to send BNB to marketing fee receiver");
        }
    }

    function setIsDividendExempt(address holder, bool exempt) external onlyOwner {
        require(holder != address(this) && holder != pair);
        isDividendExempt[holder] = exempt;
        if(exempt){
            distributor.setShare(holder, 0);
        }else{
            distributor.setShare(holder, _balances[holder]);
        }
    }

    function setTransferBuyFee(uint256 _transferTaxRate, uint256 _buyTaxRate) external onlyOwner {
        require(_transferTaxRate <= maxFee, "Transfer tax rate exceeds maximum fee");
        require(_buyTaxRate <= maxFee, "Buy tax rate exceeds maximum fee");

        transferFee = _transferTaxRate;
        totalBuyFee = _buyTaxRate;
        emit TransferBuyFeeUpdated(transferFee,totalBuyFee);
    }

    function setFeeDistribution(uint256 _liquidityFee, uint256 _reflectionFee, uint256 _marketingFee, uint256 _stakingFee) external onlyOwner {
        require(_liquidityFee.add(_reflectionFee).add(_marketingFee).add(_stakingFee) <= maxFee, "Total fee exceeds maximum fee");

        liquidityFee = _liquidityFee;
        reflectionFee = _reflectionFee;
        marketingFee = _marketingFee;
        stakingFee = _stakingFee;

        totalFee = _liquidityFee.add(_reflectionFee).add(_marketingFee).add(_stakingFee);

         emit FeeDistributionUpdated(liquidityFee,reflectionFee,marketingFee,stakingFee);
    }


    function changeWallets(address _marketingReceiver, address _stakingReceiver, address _autoLiquidityReceiver) external isAutorizer {
        require(_marketingReceiver != address(0), "ERC20: transfer from the zero address");
        require(_stakingReceiver != address(0), "ERC20: transfer to the zero address");
        require(_autoLiquidityReceiver != address(0), "ERC20: transfer to the zero address");
        stakingReceiver = _stakingReceiver;
        marketingFeeReceiver = _marketingReceiver;       
        autoLiquidityReceiver = _autoLiquidityReceiver;     
    }   

    function setSwapBackSettings(bool _enabled, uint256 _amount) external onlyOwner {
        swapEnabled = _enabled;
        swapThreshold = _amount;
    }

    function setTargetLiquidity(uint256 _target, uint256 _denominator) external onlyOwner {
        targetLiquidity = _target;
        targetLiquidityDenominator = _denominator;

        emit TargetLiquidityUpdated(targetLiquidity,targetLiquidityDenominator);
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external onlyOwner {
        distributor.setDistributionCriteria(_minPeriod, _minDistribution);

        emit DistributionCriteriaUpdated(_minPeriod, _minDistribution);
    }

    function setDistributorSettings(uint256 gas) external onlyOwner {
        require(gas < 750000);
        distributorGas = gas;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
    }
    function setAutorizerAddress(address _autorizer, bool yesno) external isAutorizer {
        isAutorizerAddress[_autorizer] = yesno;
    }  

    function getAutorizer(address account) external view returns(bool) {
        return isAutorizerAddress[account];
    }

    function getLiquidityBacking(uint256 accuracy) public view returns (uint256) {
        return accuracy.mul(balanceOf(pair).mul(2)).div(getCirculatingSupply());
    }

    function isOverLiquified(uint256 target, uint256 accuracy) public view returns (bool) {
        return getLiquidityBacking(accuracy) > target;
    }
    
    event AutoLiquify(uint256 amountBNB, uint256 amount);

}