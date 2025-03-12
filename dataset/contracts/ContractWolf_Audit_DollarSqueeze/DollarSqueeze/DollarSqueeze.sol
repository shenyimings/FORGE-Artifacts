/**
TG: https://t.me/DollarSqueeze
Website: https://dollarsqueeze.io
Author: @bLock_doctor
 */
// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.12;
 
library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }
    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}
interface IUniRouterV1
{
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
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}
interface IUniRouterV2 is IUniRouterV1
{
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);
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
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}
library SafeMath {
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
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
    IUniRouterV2 router;
    address[] shareholders;
    mapping (address => uint256) shareholderIndexes;
    mapping (address => uint256) shareholderClaims;
    mapping (address => Share) public shares;
    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public dividendsPerShareAccuracyFactor = 10 ** 36;
    uint256 public minPeriod = 1 hours;
    uint256 public minDistribution = 1;
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
    constructor (IUniRouterV2 _router) {
        router = _router;
        _token = msg.sender;
    }
    function setDistributionCriteria(uint256 newMinPeriod, uint256 newMinDistribution) external override onlyToken {
        minPeriod = newMinPeriod;
        minDistribution = newMinDistribution;
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
    function deposit() external payable override onlyToken
    {
        totalDividends = totalDividends.add(msg.value);
        dividendsPerShare = dividendsPerShare.add(dividendsPerShareAccuracyFactor.mul(msg.value).div(totalShares));
    }
    function process(uint256 gas) external override onlyToken {
        uint256 shareholderCount = shareholders.length;
        if(shareholderCount == 0) { return; }
        uint256 iterations = 0;
        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();
        while(gasUsed < gas && iterations < shareholderCount) {
            if(currentIndex >= shareholderCount){ currentIndex = 0; }
            if(shouldDistribute(shareholders[currentIndex])){
                distributeDividend(shareholders[currentIndex]);
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
            (bool success, ) = payable(shareholder).call{value: amount, gas: 30000}("");
            success = false;
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder].totalRealised.add(amount);
            shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
        }
    }
    function claimDividend() external {
        require(shouldDistribute(msg.sender), "Too soon. Need to wait!");
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
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }
    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length-1];
        shareholderIndexes[shareholders[shareholders.length-1]] = shareholderIndexes[shareholder];
        shareholders.pop();
    }
}
contract Ownable {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor () {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }
    function owner() public view returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(msg.sender==owner(), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        _owner = address(0);
        emit OwnershipTransferred(_owner, address(0));
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _owner = newOwner;
        emit OwnershipTransferred(_owner, newOwner);
    }
}
contract DollarSqueeze is IERC20, Ownable {
    string private _tokenName="DollarSqueeze";
    string private _tokenSymbol="DSQ";
    uint8 private _decimals=18;
    uint256 private _totalSupply=100000000*10**_decimals; // 100m
    // Transaction Tax
    uint8 private _buyTax=6;
    uint8 private _sellTax=20;
    uint8 private _burnTax=1;
    uint8 private _transferTax=0;
    // Trading
    bool private _airdropDone=false;
    bool private _tradingEnabled=false;
    uint256 private _maxTx=1000000*10**_decimals; // 1m
    // Wallets
    address public backupOwner=0xAe7c6C4D33667185db125842d31e3D79d614986d;
    address public marketingWallet=0xa62909d663e79Eaa49c86F429EE1538be50862aD;
    address public burnWallet=address(0xdead);
    address public zeroAddress=address(0);
    IUniRouterV2 private _router;
    address public _pair;
    // Reward Distributor
    DividendDistributor public dividendDistributor;
    address public dividendDistributorAddress;
    uint256 distributorGas=500000;
    // Mappings
    mapping(address=>uint256) private _balances;
    mapping(address=>mapping (address => uint256)) private _allowances;
    mapping(address=>bool) private _excludedFromFee;
    mapping(address=>bool) private _excludedFromRewards;
    mapping(address=>bool) private _automatedMarketMakers;
    //
    // Swap & Liquify Taxes
    SwapTaxes private _swapTaxes;
    struct SwapTaxes {
        uint8 marketingTax;
        uint8 liquidityTax;
        uint8 rewardsTax;
    }
    //Swap & Liquify
    bool private _inSwap;
    bool private _swapEnabled;
    uint256 private _swapThreshold=100000*10**_decimals;
    modifier lockTheSwap {_inSwap = true;_;_inSwap = false;}
    event SwapAndLiquify(
        uint256 amountTokens,
        uint256 amountETH
    );
 
    constructor() {
        _router = IUniRouterV2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _pair = IDEXFactory(_router.factory()).createPair(_router.WETH(), address(this));
        _allowances[address(this)][address(_router)]=type(uint256).max;
        _automatedMarketMakers[_pair] = true;
        _excludedFromFee[msg.sender]=true;
        _excludedFromFee[address(this)]=true;
        _excludedFromFee[burnWallet]=true;
        _excludedFromFee[zeroAddress]=true;
        _excludedFromRewards[_pair]=true;
        _excludedFromRewards[msg.sender]=true;
        _excludedFromRewards[address(this)]=true;
        _excludedFromRewards[burnWallet]=true;
        _excludedFromRewards[zeroAddress]=true;
        _swapTaxes=SwapTaxes(50,20,30);
        dividendDistributor = new DividendDistributor(_router);
        dividendDistributorAddress=address(dividendDistributor);
        _balances[msg.sender]+=_totalSupply;
        emit Transfer(address(0),msg.sender,_totalSupply);
    }
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        bool isExcluded=_excludedFromFee[from]||_excludedFromFee[to]||_inSwap;
        bool isBuy=_automatedMarketMakers[from];
        bool isSell=_automatedMarketMakers[to];
        if(isExcluded)_tokenTransfer(from,to,amount,0);
        else {
            require(_tradingEnabled);
            if(isBuy)_buyTokens(from,to,amount);
            else if(isSell) {
                if(!_inSwap&&_swapEnabled)_swapAndLiquify(false);
                _sellTokens(from,to,amount);
            } else {
                _tokenTransfer(from,to,amount,_transferTax*amount/100);
            }
        }
    }
    function _swapAndLiquify(
        bool ignoreLimits
    ) private lockTheSwap {
        uint256 contractTokenBalance=_balances[address(this)];
        uint256 toSwap=_swapThreshold;
        if(contractTokenBalance<toSwap) {
            if(ignoreLimits&&contractTokenBalance>0) {
                toSwap=contractTokenBalance;
            } else return;
        }
        uint256 totalLiquidityTokens=toSwap*_swapTaxes.liquidityTax/100;
        uint256 tokensRemaining=toSwap-totalLiquidityTokens;
        uint256 liquidityTokens=totalLiquidityTokens/2;
        uint256 liquidityETHTokens=totalLiquidityTokens-liquidityTokens;
        toSwap=tokensRemaining+liquidityETHTokens;
        uint256 oldETH=address(this).balance;
        _swapTokensForETH(toSwap);
        uint256 newETH=address(this).balance-oldETH;
        uint256 liquidityETH=(newETH*liquidityETHTokens)/toSwap;
        uint256 remainingETH=newETH-liquidityETH;
        uint256 marketingETH=remainingETH*_swapTaxes.marketingTax/100;
        uint256 rewardsETH=remainingETH-marketingETH;
        if (rewardsETH > 0)
            try dividendDistributor.deposit{value: rewardsETH}() {} catch {}
        (bool transferMarketing,) = payable(marketingWallet).call{value: marketingETH, gas: 30000}("");
        transferMarketing=false;
        _addLiquidity(liquidityTokens,liquidityETH);
        emit SwapAndLiquify(liquidityTokens,liquidityETH);
    }
    function _buyTokens(
        address from,
        address to,
        uint256 amount
    ) private {
        require(amount<=_maxTx,"Amount exceeds maxTx.");
        _tokenTransfer(from,to,amount,amount*_buyTax/100);
    }
    function _sellTokens(
        address from,
        address to,
        uint256 amount
    ) private {
        require(amount<=_maxTx,"Amount exceeds maxTx.");
        _tokenTransfer(from,to,amount,amount*_sellTax/100);
    }
    function _tokenTransfer(
        address from,
        address to,
        uint256 amount,
        uint256 tax
    ) private {
        uint256 tokensToBurn=_burnTax*tax/100;
        _balances[from]-=amount;
        _balances[burnWallet]+=tokensToBurn;
        _balances[address(this)]+=(tax-tokensToBurn);
        _balances[to]+=(amount-tax);
        if(!_excludedFromRewards[from]) try dividendDistributor.setShare(from,_balances[from]) {} catch {}
        if(!_excludedFromRewards[to]) try dividendDistributor.setShare(to,_balances[to]) {} catch {}
        try dividendDistributor.process(distributorGas) {} catch {}
        emit Transfer(from,to,(amount-tax));
    }
    function _swapTokensForETH(
        uint256 tokenAmount
    ) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _router.WETH();
        _approve(address(this), address(_router), tokenAmount);
        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, 
            path,
            address(this),
            block.timestamp
        );
    }
    function _addLiquidity(
        uint256 tokenAmount,
        uint256 ETHAmount
    ) private {
        _approve(address(this), address(_router), tokenAmount);
        _router.addLiquidityETH{value: ETHAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            burnWallet,
            block.timestamp
        );
    }
    //
    function enableTrading() public onlyOwner() {
        require(!_tradingEnabled,"Trading is already enabled.");
        _tradingEnabled=!_tradingEnabled;
    }
    function recoverOwnershipFromBackup() public {
        require(msg.sender==backupOwner);
        transferOwnership(backupOwner);
    }
    function updateBackupOwnerWallet(
        address _backupOwner
    ) public onlyOwner {
        backupOwner=_backupOwner;
    }
    function updateAutomatedMarketMakers(
        address marketMaker,
        bool enabled
    ) public onlyOwner {
        _automatedMarketMakers[marketMaker]=enabled;
        excludeFromReward(marketMaker,true);
    }
    function updateTax(
        uint8 buyTax,
        uint8 sellTax,
        uint8 burnTax,
        uint8 transferTax
    ) public onlyOwner {
        require(_buyTax+sellTax<=30,"Taxes cannot exceed 30%.");
        require(_transferTax<=20,"Transfer tax cannot exceed 20%.");
        _buyTax=buyTax;
        _sellTax=sellTax;
        _burnTax=burnTax;
        _transferTax=transferTax;
    }
    function updateSwapTaxes(
        uint8 marketingTax,
        uint8 rewardsTax,
        uint8 liquidityTax
    ) public onlyOwner {
        require((marketingTax+rewardsTax+liquidityTax)==100,"Swap tax cannot exceed 100.");
        _swapTaxes.marketingTax=marketingTax;
        _swapTaxes.rewardsTax=rewardsTax;
        _swapTaxes.liquidityTax=liquidityTax;
    }
    function updateSwapThreshold(
        uint256 swapThreshold
    ) public onlyOwner {
        require(_swapThreshold>0&&swapThreshold<=(_totalSupply*1/100));
        _swapThreshold=swapThreshold;
    }
    function switchSwapEnabled(
        bool swapEnabled
    ) public onlyOwner {
        _swapEnabled=swapEnabled;
    }
    function triggerSwapAndLiquify(
        bool ignoreLimits
    ) public onlyOwner {
        _swapAndLiquify(ignoreLimits);
    }
    function excludeFromFee(
        address account,
        bool excluded
    ) public onlyOwner {
        _excludedFromFee[account]=excluded;
    }
    function excludeFromReward(
        address account,
        bool excluded
    ) public onlyOwner {
        _excludedFromRewards[account]=excluded;
        try dividendDistributor.setShare(account,excluded?0:_balances[account]) {} catch {}
    }
    function updateMaxTx(
        uint256 maxTx
    ) public onlyOwner {
        require(maxTx>=(_totalSupply*1/100) / 2);
        _maxTx=maxTx*10**_decimals;
    }
    function updateMarketingWallet(
        address _marketingWallet
    ) public onlyOwner {
        require(_marketingWallet!=address(0),"Cannot be zero address!");
        marketingWallet=_marketingWallet;
    }
    function withdrawStrandedToken(
        address strandedToken
    ) public onlyOwner {
        require(strandedToken!=address(this));
        IERC20 token=IERC20(strandedToken);
        token.transfer(owner(),token.balanceOf(address(this)));
    }
    function withdrawStuckETH() public onlyOwner {
        (bool success,)=msg.sender.call{value:(address(this).balance)}("");
        require(success);
    }
    function addRewardsManually() public payable onlyOwner {
        require(msg.value>0);
        try dividendDistributor.deposit{value: msg.value}() {} catch {}
    }
    function updateDistributorSettings(
        uint256 _minPeriod,
        uint256 _minDistribution,
        uint256 gas
    ) public onlyOwner {
        require(gas<=1200000);
        dividendDistributor.setDistributionCriteria(_minPeriod, _minDistribution);
        distributorGas = gas;
    }
    //
    function showMaxTx() public view returns(uint256) {
        return _maxTx;
    }
    function isSwapEnabled() public view returns(bool) {
        return _swapEnabled;
    }
    function showTradeTaxes() public view returns(
        uint8 buyTax, 
        uint8 sellTax,
        uint8 burnTax,
        uint8 transferTax
    ) {
        buyTax=_buyTax;
        sellTax=_sellTax;
        burnTax=_burnTax;
        transferTax=_transferTax;
    }
    function showSwapTaxes() public view returns(
        uint8 marketingTax, 
        uint8 liquidityTax, 
        uint8 rewardsTax
    ) {
        marketingTax=_swapTaxes.marketingTax;
        liquidityTax=_swapTaxes.liquidityTax;
        rewardsTax=_swapTaxes.rewardsTax;
    }
    function showDistributorDetails() public view returns(
        address _distributorAddress, 
        uint256 _distributorGas
    ) {
        _distributorAddress=dividendDistributorAddress;
        _distributorGas=distributorGas;
    }
    function isTradingEnabled() public view returns(bool) {
        return _tradingEnabled;
    }
    //
    function transfer(
        address recipient, 
        uint256 amount
    ) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    function transferFrom(
        address sender, 
        address recipient, 
        uint256 amount
    ) external override returns (bool) {
        uint256 allowance_ = _allowances[sender][msg.sender];
        _transfer(sender, recipient, amount);
        require(allowance_ >= amount);
        _approve(sender, msg.sender, allowance_ - amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }
    function _approve(
        address owner, 
        address spender, 
        uint256 amount
    ) private {
        require((owner != address(0) && spender != address(0)), "Owner/Spender address cannot be 0.");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function approve(
        address spender, 
        uint256 amount
    ) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    function allowance(
        address owner_,
        address spender
    ) external view override returns (uint256) {
        return _allowances[owner_][spender];
    }
    function balanceOf(
        address account
    ) external view override returns (uint256) {
        return _balances[account];
    }
    function name() external view returns (string memory) {
        return _tokenName;
    }
    function symbol() external view returns (string memory) {
        return _tokenSymbol;
    }
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }
    function decimals() external view returns (uint8) {
        return _decimals;
    }
    function getOwner() external view returns (address) {
        return owner();
    }
    receive() external payable { }
}