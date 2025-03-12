// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

interface IUniswapV2Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    // function setFeeTo(address) external;
    // function setFeeToSetter(address) external;
}



interface IUniswapV2Pair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}



interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}



interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract TaxDistributionContrac is  Ownable {
    uint256 public investorAmountThreshold = 70000000000000000000; //amount after which investor percentage will change 
    uint256 public amountDistributedToInvestors;// total amount sent to the investor
    uint256 initialInvestorPercentage = 5000; // 50% sent to the investor
    uint256 investorPercentage = 2500; // After 70 eth, 25% will be sent to the investor
    uint256 public priceImpactMax  = 200; //2% price impact is allowed
    uint256 public slippage =10000; // Slippage while swapping tokens on dex
    uint256 public epoch = 28800; // epoch time for tax distribution
    uint256 public lastDistributedTime; // last time the tax got distributed
    address  payable public  investorWallet = payable(0x50Ca1fde29D62292a112A72671E14a5d4f05580f); // investor wallet
    address  payable public teamWallet = payable(0x50Ca1fde29D62292a112A72671E14a5d4f05580f); // team wallet
    address public TGKToken; //tgk token address
    uint256 public amountDistributedToTeam; // amount distributed to the team
    bool public reverse; // token order in pair
    IUniswapV2Router02 public uniswapV2Router; // uniswap dex router
    IUniswapV2Pair public pairContract  ; // tgk eth pair contract
    

    // events
    event InvestorAmountThresholdUpdated(uint256 amount);
    event InitialInvestorPercentageUpdated(uint256 percentage);
    event InvestorPercentageUpdated(uint256 percentage);
    event PriceImpactMaxUpdated(uint256 max);
    event InvestorWalletUpdated(address wallet);
    event TeamWalletUpdated(address wallet);
    event TokenContractUpdated(address token);
    event RouterUpdated(address router);
    event PairUpdated(address pair);
    event SlippageUpdated(uint256 slippage);
    event EpochUpdated(uint256 epoch);
    event ReverseUpdated(bool reverse);

    /*
    @param token Address of tgk token
    @param pair TGK -ETH Pair Address
     */

    constructor(address token, address pair) {

         TGKToken = token;
         pairContract = IUniswapV2Pair(pair);
         IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        if(pairContract.token1() == TGKToken){
           reverse = true;
        }
        uniswapV2Router = _uniswapV2Router;
        IERC20(TGKToken).approve(address(uniswapV2Router), 2**256 - 1);
        


    }

     /*
    @param amount updated investor threshold Amount
     */

    function setInvestorThresholdAmount(uint256 amount) external onlyOwner{
        investorAmountThreshold = amount;
        emit InvestorAmountThresholdUpdated(amount);
    }

     /*
    @param percentage initial percentage to the investor before threshold
     */

    function setInvestorInitialPercentage(uint256 percentage) external onlyOwner{
        require(percentage < 10000,"Percentage should be less than 100");
        initialInvestorPercentage = percentage;
        emit InitialInvestorPercentageUpdated(percentage);
    }
    
     /*
    @param percentage  percentage to the investor after threshold
     */

    function setInvestorPercentage(uint256 percentage) external onlyOwner{
        require(percentage < 10000,"Percentage should be less than 100");
        investorPercentage = percentage;
        emit InvestorPercentageUpdated(percentage);
    }

     /*
    @param wallet investor wallet address
     */

    function setInvestorWalletAddress(address wallet) external onlyOwner{
        investorWallet = payable(wallet);
        emit InvestorWalletUpdated(wallet);
    }

     /*
    @param wallet team wallet address
     */

    function setTeamWalletAddress(address wallet) external onlyOwner{
        teamWallet = payable(wallet);
        emit TeamWalletUpdated(wallet);
    }

     /*
    @param token tgk token address
     */

    function setTGKAddress(address token) external onlyOwner{
        TGKToken = token;
        emit TokenContractUpdated(token);
    }

     /*
    @param router dex router address address
     */

    function setRouterAddress(address router) external onlyOwner{
        uniswapV2Router = IUniswapV2Router02(router);
        IERC20(TGKToken).approve(address(uniswapV2Router), 2**256 - 1);
        emit RouterUpdated(router);
    }

     /*
    @param pair TGK-ETH pair address
     */

    function setPairAddress(address pair) external onlyOwner{
        pairContract = IUniswapV2Pair(pair);
        emit PairUpdated(pair);
    }

     /*
    @param max maximum price impact
     */

    function setPriceImpactMx(uint256 max) external onlyOwner{
        priceImpactMax = max;
        emit PriceImpactMaxUpdated(max);
    }

     /*
    @param _slippage slippage while swapping
     */

    function setSlippage(uint256 _slippage) external onlyOwner {
        slippage = _slippage;
        emit SlippageUpdated(_slippage);
    }

     /*
    @param rev order of token in pair address
     */

    function setReverse(bool rev) external onlyOwner{
        reverse = rev;
        emit ReverseUpdated(rev);
    }

     /*
    @param _epoch time for distributing tax
     */

    function updateEpoch(uint256 _epoch) external onlyOwner{
        epoch = _epoch;
        emit EpochUpdated(_epoch);
    }

     /*
    @param amountA amount of Token swapped on router
     */
   
        

    function calcPairSwap(uint256 amountA) public view returns(uint256 priceImpact) {
        (uint256 reserveA, uint256 reserveB,) = pairContract.getReserves();
        uint256 reserve;
        uint256 amountB;
        if(reverse == true){
        reserve = reserveA;
        amountB =  uniswapV2Router.getAmountOut(amountA, reserveB, reserveA);
        }
        else{
        reserve = reserveB;
        amountB =  uniswapV2Router.getAmountOut(amountA, reserveA, reserveB);
        }
        unchecked {priceImpact =  (reserve-(reserve-(amountB)))*(10000) / reserve;}
        return( priceImpact);    
    }

     /*
    @param amount distribute amount as Eth
     */

    function distributeTax(uint256 amount) external {
        require(block.timestamp >= epoch + lastDistributedTime,"Epoch Time not completed");
        lastDistributedTime = block.timestamp;
        require(calcPairSwap(amount)<=priceImpactMax,"Price Impact Exceeded");
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(amount);
        uint256 newBalance = address(this).balance-(initialBalance);
        uint256 investorAmount;
        if(amountDistributedToInvestors <= investorAmountThreshold){
        unchecked { investorAmount = (newBalance*initialInvestorPercentage)/10000;}
         
        }
        else{
          investorAmount = (newBalance*investorPercentage)/10000;
        }

         investorWallet.transfer(investorAmount);
         amountDistributedToInvestors = amountDistributedToInvestors + investorAmount;
         uint256 amountLeft = newBalance-investorAmount;
         teamWallet.transfer(amountLeft);
         amountDistributedToTeam = amountDistributedToTeam + amountLeft;

    }

     /*
    @param tokenAmount amount swapped on dex
     */

    function swapTokensForEth(uint256 tokenAmount) private {
       
        address[] memory path = new address[](2);
        path[0] = TGKToken;
        path[1] = uniswapV2Router.WETH();
      
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            tokenAmount - (tokenAmount*slippage/10000), 
            path,
            address(this),
            block.timestamp + 1000
        );
    }
    
    receive() external payable {}

     /*
    @param token address of token to be withdrawn
    @param wallet wallet that gets the token
     */

    function withdrawTokens(IERC20 token, address wallet) external onlyOwner{
         uint256 balanceOfContract = token.balanceOf(address(this));
        token.transfer(wallet,balanceOfContract);
    }

     /*
    @param wallet address that gets the Eth
     */
    
    function withdrawFunds(address wallet) external onlyOwner{
        uint256 balanceOfContract = address(this).balance;
        payable(wallet).transfer(balanceOfContract);
    }
}
