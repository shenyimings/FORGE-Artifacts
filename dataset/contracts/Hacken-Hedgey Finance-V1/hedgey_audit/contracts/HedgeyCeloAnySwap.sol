pragma solidity ^0.6.12;


import ./libraries.sol

interface IHedgeySwap {
    function hedgeySwap(address originalOwner, uint _c, uint totalPurchase, address[] memory path, bool cashBack) external;
}


interface IHedgey {
    function asset() external view returns (address asset);
    function pymtCurrency() external view returns (address pymtCurrency);
    function exercise(uint _c) external;
    
}


contract HedgeyAnySwap is ReentrancyGuard {
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    

    address public factory;
    uint8 public fee;

    constructor(address _factory, uint8 _fee) public {
        factory = _factory;
        fee = _fee;
    }

    
    function sortTokens(address tokenA, address tokenB) internal view returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }
    
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public view returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(10000 - fee);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(10000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) public view returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(10000);
        uint denominator = reserveOut.sub(amountOut).mul(10000 - fee);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(uint amountIn, address[] memory path) public view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(uint amountOut, address[] memory path) public view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
    
    

    // fetches and sorts the reserves for a pair
    function getReserves(address tokenA, address tokenB) public view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        address pair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }
    
    
    
    //function to swap from this contract to uniswap pool
    function swap(bool send, address tokenIn, address tokenOut, uint _in, uint out, address to) internal {
        address pair = IUniswapV2Factory(factory).getPair(tokenIn, tokenOut);
        if (send) SafeERC20.safeTransfer(IERC20(tokenIn), pair, _in); //sends the asset amount in to the swap
        address token0 = IUniswapV2Pair(pair).token0();
        if (tokenIn == token0) {
            IUniswapV2Pair(pair).swap(0, out, to, new bytes(0));
        } else {
            IUniswapV2Pair(pair).swap(out, 0, to, new bytes(0));
        }
        
    }
    
    
    function multiSwap(address[] memory path, uint amountOut, uint amountIn, address to) internal {
       require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
       require((amountOut > 0 && amountIn == 0) || (amountIn > 0 && amountOut == 0), "one of the amounts must be 0");
       uint[] memory amounts = (amountOut > 0) ? getAmountsIn(amountOut, path) : getAmountsOut(amountIn, path);
       for (uint i = 0; i < path.length - 1; i++) {
           address _to = (i < path.length - 2) ? IUniswapV2Factory(factory).getPair(path[i+1], path[i+2]) : to;
           swap((i == 0), path[i], path[i+1], amounts[i], amounts[i+1], _to);
       }
    }
    
    
    
    
    
    function flashSwap(address borrowedToken, address tokenDue, uint out, bytes memory data) internal {
        address pair = IUniswapV2Factory(factory).getPair(borrowedToken, tokenDue);
        address token0 = IUniswapV2Pair(pair).token0();
        if (borrowedToken == token0) {
            IUniswapV2Pair(pair).swap(0, out, address(this), data);
        } else {
            IUniswapV2Pair(pair).swap(out, 0, address(this), data);
        }
    }
    
    
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes memory data) external {
        
        address token0 = IUniswapV2Pair(msg.sender).token0(); // fetch the address of token0
        address token1 = IUniswapV2Pair(msg.sender).token1(); // fetch the address of token1
        (uint reserveA, uint reserveB) = getReserves(token0, token1);
        assert(msg.sender == IUniswapV2Factory(factory).getPair(token0, token1));
        (address _hedgey, uint _n, address[] memory path, bool optionType) = abi.decode(data, (address, uint, address[], bool));
        
        uint amountDue = amount0 == 0 ? getAmountIn(amount1, reserveA, reserveB) : getAmountIn(amount0, reserveB, reserveA);
        uint purchase = amount0 == 0 ? amount1 : amount0;
        if (optionType) {
            (address asset) = exerciseCall(_hedgey, _n, purchase); //exercises the call given the input data
            multiSwap(path, amountDue, 0, msg.sender);
        } else {
            // must be a put
            (address paymentCurrency) = exercisePut(_hedgey, _n, purchase);
            multiSwap(path, amountDue, 0, msg.sender);
        }
        
        
    }
    
    
    
    function exerciseCall(address hedgeyCalls, uint _c, uint purchase) internal returns (address asset) {
        
        SafeERC20.safeIncreaseAllowance(IERC20(IHedgey(hedgeyCalls).pymtCurrency()), hedgeyCalls, purchase); //approve that we can spend the payment currency
        IHedgey(hedgeyCalls).exercise(_c); //exercise call - gives us back the asset
        asset = IHedgey(hedgeyCalls).asset();
        
    }
    
    
    function exercisePut(address hedgeyPuts, uint _p, uint purchase) internal returns (address paymentCurrency) {
        
        SafeERC20.safeIncreaseAllowance(IERC20(IHedgey(hedgeyPuts).asset()), hedgeyPuts, purchase); //approve that we can spend the payment currency
        IHedgey(hedgeyPuts).exercise(_p);
        paymentCurrency = IHedgey(hedgeyPuts).pymtCurrency();
        
    }
    
    
    function hedgeyCallSwap(address originalOwner, uint _c, uint totalPurchase, address[] memory path, bool cashBack) external nonReentrant {
   
        address[] memory _path = new address[](path.length - 1);
        for (uint i; i < path.length - 1; i++) {
            _path[i] = path[i];
        }
        bytes memory data = abi.encode(msg.sender, _c, _path, true);
        flashSwap(path[path.length - 2], path[path.length - 1], totalPurchase, data);
        
        if(cashBack) {
            
            multiSwap(path, 0, IERC20(path[0]).balanceOf(address(this)), originalOwner);
        } else {
            SafeERC20.safeTransfer(IERC20(path[0]), originalOwner, IERC20(path[0]).balanceOf(address(this)));
        }
    }
    
    function hedgeyPutSwap(address originalOwner, uint _p, uint assetAmount, address[] memory path) external nonReentrant {
        
        address[] memory _path = new address[](path.length - 1);
        for (uint i; i < path.length - 1; i++) {
            _path[i] = path[i];
        }
        bytes memory data = abi.encode(msg.sender, _p, _path, false);
        flashSwap(path[path.length - 2], path[path.length - 1], assetAmount, data);
        SafeERC20.safeTransfer(IERC20(path[0]), originalOwner, IERC20(path[0]).balanceOf(address(this)));
    }
    
    
}


