// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;
import "./SafeMath.sol";
import "./Uniswap.sol";
import "./ERC20.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./Uniswap.sol";
contract Token is Ownable, ERC20,ReentrancyGuard {
    using SafeMath for uint256;
    address public growthFundAddress;
    uint256 public feeRate = 10;
    uint256 public swapTokensAtAmount = 10*6*10*18;
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    mapping (address => bool) private _isExcludedFromFees;
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);
    bool swapping = false;
    
    constructor() ERC20("Save Luna Token", "SLN") {
        growthFundAddress = _msgSender();
        uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
        .createPair(address(this), uniswapV2Router.WETH());
        _approve(address(this), address(uniswapV2Router), ~uint256(0));
        _isExcludedFromFees[_msgSender()]=true;
        _mint(_msgSender(), 10*10**9*10**18);
    }
    receive() external payable {}
    function setGrowthFundAddress(address _address) public onlyOwner {
        growthFundAddress = _address;
    }
    function setAmountToSwap(uint256 _amount) public onlyOwner{
        swapTokensAtAmount = _amount;
    }
    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromFees[account] != excluded, "Account is already 'excluded'");
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }
      function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }
    
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        if(!swapping && sender!=uniswapV2Pair&&sender != address(this) && recipient != address(this)){
            swapFeeToken();
        }
        if (!swapping && sender != address(this) && recipient != address(this) && !_isExcludedFromFees[sender] && !_isExcludedFromFees[recipient]) {
            if(sender==uniswapV2Pair||recipient==uniswapV2Pair){
               
                uint256 _fee = amount.mul(feeRate).div(100);
                super._transfer(sender,address(this), _fee);
                super._transfer(address(this), 0x000000000000000000000000000000000000dEaD, _fee/2);
                amount = amount.sub(_fee);
                
            }
        }
        super._transfer(sender, recipient, amount);
    }
    function swapFeeToken() private{
        swapping = true;
        uint256 contractTokenBalance = balanceOf(address(this));
        if(contractTokenBalance>=swapTokensAtAmount){
            swapAndLiquify(contractTokenBalance*2/5);
            swapTokensForEth(contractTokenBalance*3/5,growthFundAddress);
        }   
        swapping = false;
    }
    
    function swapAndLiquify(uint256 tokens) private {
        uint256 half = tokens/2;
        uint256 otherHalf = tokens-half;
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(half,address(this));
        uint256 newBalance = address(this).balance.sub(initialBalance);
        addLiquidity(otherHalf, newBalance);
        emit SwapAndLiquify(half, initialBalance, otherHalf);
    }
    function swapTokensForEth(uint256 tokenAmount,address _to) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        tokenAmount,
        0,
        path,
        _to,
        block.timestamp
        );
    }
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private{
        uniswapV2Router.addLiquidityETH{ value: ethAmount }(
        address(this),
        tokenAmount,
        0,
        0,
        address(this),
        block.timestamp
        );
    }
    
}
