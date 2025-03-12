/**
 *Submitted for verification at Etherscan.io on 2023-09-13
*/

//SPDX-License-Identifier: MIT

pragma solidity = 0.8.19;

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
//--- Context ---//
abstract contract Context {
    constructor() {
    }

    function _msgSender() internal view returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view returns (bytes memory) {
        this;
        return msg.data;
    }
}

//--- Ownable ---//
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _setOwner(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IFactoryV2 {
    event PairCreated(address indexed token0, address indexed token1, address lpPair, uint);
    function getPair(address tokenA, address tokenB) external view returns (address lpPair);
    function createPair(address tokenA, address tokenB) external returns (address lpPair);
}

interface IV2Pair {
    function factory() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function sync() external;
}

interface IRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
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
    function swapExactETHForTokens(
        uint amountOutMin, 
        address[] calldata path, 
        address to, uint deadline
    ) external payable returns (uint[] memory amounts);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IRouter02 is IRouter01 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
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
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}



//--- Interface for ERC20 ---//
interface IERC20 {
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

//--- Contract v2 ---//
contract Token is Context, Ownable, IERC20 {
     using SafeMath for uint256;
    function totalSupply() external pure override returns (uint256) { if (_totalSupply == 0) { revert(); } return _totalSupply; }
    function decimals() external pure override returns (uint8) { if (_totalSupply == 0) { revert(); } return _decimals; }
    function symbol() external pure override returns (string memory) { return _symbol; }
    function name() external pure override returns (string memory) { return _name; }
    function getOwner() external view override returns (address) { return owner(); }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }
    function balanceOf(address account) public view override returns (uint256) { return balance[account];}

    address public constant ETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address public constant ZERO = 0x0000000000000000000000000000000000000000;
    address public MKT = 0xebb733EAB3C98975dEdd7341F0C1b5E7752F38D1;

    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _noFee;
    mapping (address => bool) private liquidityAdd;
    mapping (address => bool) private isLpPair;
    mapping (address => bool) private isAutorizerAddress;
    mapping (address => uint256) private balance;


    uint256 constant public _totalSupply = 810_000_000_000_000 * 10**18;
    uint256 public swapThreshold = _totalSupply.mul(10).div(10000); //0.01% of supply
    bool public swapEnabled = true;

    // Sell fee distribution
    uint256 public liquidityFee = 10;
    uint256 public marketingFee = 20; 
    uint256 public contestFee = 20;
    uint256 public sellfee = liquidityFee.add(marketingFee).add(contestFee);

    uint256 public buyfee = 50;
    uint256 public transferfee = 0;

    uint256 constant public fee_denominator = 1_000;
    uint256 public targetLiquidity = 20;
    uint256 public targetLiquidityDenominator = 100;
    uint256 constant public maxFee = 150;

    bool private canSwapFees = false;
    address public marketingAddress = MKT;
    address public autoLiquidityReceiver = MKT;
    address public contestReceiver = MKT;


    IRouter02 public swapRouter;
    string constant private _name = "$PepeFace";
    string constant private _symbol = "PPFACE";
    uint8 constant private _decimals = 18;
    address public lpPair;
    bool public isTradingEnabled = false;
    bool private inSwap;

    modifier inSwapFlag { inSwap = true; _; inSwap = false; }

    modifier isAutorizer {require(isAutorizerAddress[msg.sender], "Not an authorized address");_; }

    event _enableTrading();
    event _setPresaleAddress(address account, bool enabled);
    event _toggleCanSwapFees(bool enabled);
    event _changePair(address newLpPair);
    event _changeWallets(address marketing, address contest);
    event _adminTokenRecovery(address tokenAddress, uint256 tokenAmount);
    event _feeDistributionUpdated(uint256 liquidityFee,uint256 marketingFee,uint256 contestFee);
    event _transferBuyFeeUpdated(uint256 transferFee,uint256 totalBuyFee);


    constructor () {
        _noFee[msg.sender] = true;

        if (block.chainid == 56) {
            swapRouter = IRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        } else if (block.chainid == 97) {
            swapRouter = IRouter02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
        } else if (block.chainid == 1 || block.chainid == 4 || block.chainid == 3) {
            swapRouter = IRouter02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        } else if (block.chainid == 43114) {
            swapRouter = IRouter02(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
        } else if (block.chainid == 250) {
            swapRouter = IRouter02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
        } else {
            revert("Chain not valid");
        }
        liquidityAdd[msg.sender] = true;
        balance[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);

        lpPair = IFactoryV2(swapRouter.factory()).createPair(swapRouter.WETH(), address(this));
        isLpPair[lpPair] = true;
        isAutorizerAddress[msg.sender] = true;

        _approve(msg.sender, address(swapRouter), type(uint256).max);
        _approve(address(this), address(swapRouter), type(uint256).max);
    }
    
    receive() external payable {}

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function _approve(address sender, address spender, uint256 amount) internal {
        require(sender != address(0), "ERC20: Zero Address");
        require(spender != address(0), "ERC20: Zero Address");

        _allowances[sender][spender] = amount;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            _allowances[sender][msg.sender] -= amount;
        }

        return _transfer(sender, recipient, amount);
    }
    function isNoFeeWallet(address account) external view returns(bool) {
        return _noFee[account];
    }

    function setNoFeeWallet(address account, bool enabled) public onlyOwner {
        _noFee[account] = enabled;
    }

    function isLimitedAddress(address ins, address out) internal view returns (bool) {

        bool isLimited = ins != owner()
            && out != owner() && msg.sender != owner()
            && !liquidityAdd[ins]  && !liquidityAdd[out] && out != DEAD && out != address(0) && out != address(this);
            return isLimited;
    }

    function is_buy(address ins, address out) internal view returns (bool) {
        bool _is_buy = !isLpPair[out] && isLpPair[ins];
        return _is_buy;
    }

    function is_sell(address ins, address out) internal view returns (bool) { 
        bool _is_sell = isLpPair[out] && !isLpPair[ins];
        return _is_sell;
    }

    function is_transfer(address ins, address out) internal view returns (bool) { 
        bool _is_transfer = !isLpPair[out] && !isLpPair[ins];
        return _is_transfer;
    }

    function canSwap(address ins, address out) internal view returns (bool) {
        bool canswap = canSwapFees && !isAutorizerAddress[ins] && !isAutorizerAddress[out];

        return canswap;
    }

    function changeLpPair(address newPair,bool yesno) external isAutorizer {
        isLpPair[newPair] = yesno;
        emit _changePair(newPair);
    }

    function getLpPair(address _contract) external view returns(bool) {
        return isLpPair[_contract];
    }

    function toggleCanSwapFees(bool yesno) external onlyOwner {
        require(canSwapFees != yesno,"Bool is the same");
        canSwapFees = yesno;
        emit _toggleCanSwapFees(yesno);
    }

    function _transfer(address from, address to, uint256 amount) internal returns  (bool) {
        bool takeFee = true;
        require(to != address(0), "ERC20: transfer to the zero address");
        require(from != address(0), "ERC20: transfer from the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (isLimitedAddress(from,to)) {
            require(isTradingEnabled,"Trading is not enabled");
        }

        if(is_sell(from, to) &&  !inSwap && canSwap(from, to)) {
            uint256 contractTokenBalance = balanceOf(address(this));
            if(swapEnabled && contractTokenBalance >= swapThreshold) { internalSwap(); }
        }

        if (_noFee[from] || _noFee[to]){
            takeFee = false;
        }

        balance[from] -= amount; uint256 amountAfterFee = (takeFee) ? takeTaxes(from, is_buy(from, to), is_sell(from, to), amount) : amount;
        balance[to] += amountAfterFee; emit Transfer(from, to, amountAfterFee);

        return true;

    }

    function changeWallets(address _marketingReceiver, address _contestReceiver) external isAutorizer {
        require(_marketingReceiver != address(0), "ERC20: transfer from the zero address");
        require(_contestReceiver != address(0), "ERC20: transfer to the zero address");
        marketingAddress = _marketingReceiver;       
        contestReceiver = _contestReceiver;
        emit _changeWallets(marketingAddress, contestReceiver);     
    }

    function takeTaxes(address from, bool isbuy, bool issell, uint256 amount) internal returns (uint256) {
        uint256 fee;
        if (isbuy)  fee = buyfee;  else if (issell)  fee = sellfee;  else  fee = transferfee; 
        if (fee == 0)  return amount;
        uint256 feeAmount = amount * fee / fee_denominator;
        if (feeAmount > 0) {

            balance[address(this)] += feeAmount;
            emit Transfer(from, address(this), feeAmount);
            
        }
        return amount - feeAmount;
    }

    function setTransferBuyFee(uint256 _transferTaxRate, uint256 _buyTaxRate) external onlyOwner {
        require(_transferTaxRate <= maxFee, "Transfer tax rate exceeds maximum fee");
        require(_buyTaxRate <= maxFee, "Buy tax rate exceeds maximum fee");

        transferfee = _transferTaxRate;
        buyfee = _buyTaxRate;
        emit _transferBuyFeeUpdated(transferfee,buyfee);
    }
    function setFeeDistribution(uint256 _liquidityFee, uint256 _reflectionFee, uint256 _marketingFee, uint256 _contestFee) external onlyOwner {
        require(_liquidityFee.add(_reflectionFee).add(_marketingFee).add(_contestFee) <= maxFee, "Total fee exceeds maximum fee");

        liquidityFee = _liquidityFee;
        marketingFee = _marketingFee;
        contestFee = _contestFee;

        sellfee = _liquidityFee.add(_marketingFee).add(_contestFee);

         emit _feeDistributionUpdated(liquidityFee,marketingFee, contestFee);
    }

    function internalSwap() internal inSwapFlag {
        
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = swapRouter.WETH();
        
        uint256 balanceBefore = address(this).balance;

        bool success;

        if (sellfee > 0) {
            uint256 dynamicLiquidityFee = isOverLiquified(targetLiquidity, targetLiquidityDenominator) ? 0 : liquidityFee;
            uint256 amountToLiquify = balanceOf(address(this)).mul(dynamicLiquidityFee).div(sellfee).div(2);
            uint256 amountToSwap = balanceOf(address(this)).sub(amountToLiquify);

            swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
                amountToSwap,
                0,
                path,
                address(this),
                block.timestamp
            );
            uint256 amountETH = address(this).balance.sub(balanceBefore);
            uint256 totalETHFee = sellfee.sub(dynamicLiquidityFee.div(2));
            uint256 amountETHLiquidity = amountETH.mul(dynamicLiquidityFee).div(totalETHFee).div(2);
            uint256 amountETHContest = amountETH.mul(contestFee).div(totalETHFee);
            uint256 amountETHMarketing = amountETH.mul(marketingFee).div(totalETHFee);

            if (contestFee > 0) {
                (success,) = contestReceiver.call{value: amountETHContest, gas: 35000}("");
                require(success, "Failed to send ETH to contest receiver");
            }

            if (marketingFee > 0) {
                (success,) = marketingAddress.call{value: amountETHMarketing, gas: 35000}("");
                require(success, "Failed to send ETH to marketing fee receiver");
            }

            if (amountToLiquify > 0) {
                swapRouter.addLiquidityETH{value: amountETHLiquidity}(
                    address(this),
                    amountToLiquify,
                    0,
                    0,
                    autoLiquidityReceiver,
                    block.timestamp
                );
                emit AutoLiquify(amountETHLiquidity, amountToLiquify);
            }
        } else if (balanceOf(address(this)) > 0) {
            swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
                balanceOf(address(this)),
                0,
                path,
                address(this),
                block.timestamp
            );
            uint256 amount = address(this).balance.sub(balanceBefore);
             (success,) = marketingAddress.call{value: amount, gas: 35000}("");
            require(success, "Failed to send ETH to marketing fee receiver");
        }

        if (_allowances[address(this)][address(swapRouter)] != type(uint256).max) {
            _allowances[address(this)][address(swapRouter)] = type(uint256).max;
        }

    }

    function setAutorizerAddress(address _autorizer, bool yesno) external isAutorizer {
        require(isAutorizerAddress[_autorizer] != yesno,"Same bool");
        isAutorizerAddress[_autorizer] = yesno;
        _noFee[_autorizer] = yesno;
        liquidityAdd[_autorizer] = yesno;
        emit _setPresaleAddress(_autorizer, yesno);
    }

    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external isAutorizer {
        require(_tokenAddress != address(this), "Cannot be this token");
        IERC20(_tokenAddress).transfer(address(msg.sender), _tokenAmount);
        emit _adminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    function enableTrading() external onlyOwner {
        require(!isTradingEnabled, "Trading already enabled");
        isTradingEnabled = true;
        emit _enableTrading();
    }

    function setSwapBackSettings(bool _enabled, uint256 _amount) external onlyOwner {
        swapEnabled = _enabled;
        swapThreshold = _amount;
    }

    function getAutorizer(address account) external view returns(bool) {
        return isAutorizerAddress[account];
    }

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
    }
        function getLiquidityBacking(uint256 accuracy) public view returns (uint256) {
        return accuracy.mul(balanceOf(lpPair).mul(2)).div(getCirculatingSupply());
    }

    function isOverLiquified(uint256 target, uint256 accuracy) public view returns (bool) {
        return getLiquidityBacking(accuracy) > target;
    }
    
    event AutoLiquify(uint256 amountETH, uint256 amount);
}