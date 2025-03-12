// SPDX-License-Identifier: MIT
pragma solidity >=0.5 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface DystopiaPair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}


abstract contract IDystopiaLP is DystopiaPair {

    function deposit(uint amount, uint tokenId) external virtual;

    function withdraw(uint amount) external virtual;

    function withdrawAll() external virtual;

    function getReward(address account, address[] memory tokens) external virtual;

}



interface IDystopiaRouter {

    struct Route {
        address from;
        address to;
        bool stable;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        Route[] calldata routes,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external view returns (uint amount, bool stable);
    function getAmountsOut(uint amountIn, Route[] memory routes) external view returns (uint[] memory amounts);
    function getReserves(address tokenA, address tokenB, bool stable) external view returns (uint reserveA, uint reserveB);
}


library DystopiaLibrary {


    function _swapExactTokensForTokens(
        IDystopiaRouter dystRouter,
        address inputToken,
        address middleToken,
        address outputToken,
        bool isStablePair0,
        bool isStablePair1,
        uint256 amountInput,
        address recipient
    ) internal returns (uint256) {

        IERC20(inputToken).approve(address(dystRouter), amountInput);

        uint256 amountOutMin = _getAmountsOut(dystRouter, address(inputToken), address(middleToken), address(outputToken), isStablePair0, isStablePair1, amountInput);
        if (amountOutMin == 0) {
            return 0;
        }

        IDystopiaRouter.Route[] memory route = new IDystopiaRouter.Route[](2);
        route[0].from = inputToken;
        route[0].to = middleToken;
        route[0].stable = isStablePair0;
        route[1].from = middleToken;
        route[1].to = outputToken;
        route[1].stable = isStablePair1;

        uint[] memory amounts = dystRouter.swapExactTokensForTokens(
            amountInput,
            0,
            route,
            recipient,
            block.timestamp + 600
        );

        return amounts[2];
    }

    function _swap(
        IDystopiaRouter dystRouter,
        address inputToken,
        address outputToken,
        bool isStablePair,
        uint256 amountInput,
        uint256 slippagePercent,
        address recipient
    ) internal returns (uint256) {

        IERC20(inputToken).approve(address(dystRouter), type(uint256).max);

        uint256 amountOutMin = _getAmountOut(dystRouter, address(inputToken), address(outputToken), isStablePair,  amountInput);
        amountOutMin = amountOutMin / 10000 * (10000 - slippagePercent);

        IDystopiaRouter.Route[] memory route = new IDystopiaRouter.Route[](1);
        route[0].from = inputToken;
        route[0].to = outputToken;
        route[0].stable = isStablePair;

        uint[] memory amounts = dystRouter.swapExactTokensForTokens(
            amountInput,
            amountOutMin,
            route,
            recipient,
            block.timestamp + 600
        );

        return amounts[1];
    }

    function _getAmountOut(
        IDystopiaRouter dystRouter,
        address inputToken,
        address outputToken,
        bool isStablePair,
        uint256 amountInput
    ) internal view returns (uint256) {

        IDystopiaRouter.Route[] memory route = new IDystopiaRouter.Route[](1);
        route[0].from = inputToken;
        route[0].to = outputToken;
        route[0].stable = isStablePair;

        uint[] memory amounts = dystRouter.getAmountsOut(amountInput, route);

        return amounts[1];
    }

    function _getAmountsOut(
        IDystopiaRouter dystRouter,
        address inputToken,
        address middleToken,
        address outputToken,
        bool isStablePair0,
        bool isStablePair1,
        uint256 amountInput
    ) internal view returns (uint256) {

        IDystopiaRouter.Route[] memory route = new IDystopiaRouter.Route[](2);
        route[0].from = inputToken;
        route[0].to = middleToken;
        route[0].stable = isStablePair0;
        route[1].from = middleToken;
        route[1].to = outputToken;
        route[1].stable = isStablePair1;

        uint[] memory amounts = dystRouter.getAmountsOut(amountInput, route);

        return amounts[2];
    }

    function _addLiquidity(
        IDystopiaRouter dystRouter,
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to
    ) internal returns (uint amountA, uint amountB, uint liquidity) {

        IERC20(tokenA).approve(address(dystRouter), amountADesired);
        IERC20(tokenB).approve(address(dystRouter), amountBDesired);

        return dystRouter.addLiquidity(
            tokenA,
            tokenB,
            true,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            to,
            block.timestamp + 600
        );

    }

    function _removeLiquidity(
        IDystopiaRouter dystRouter,
        address tokenA,
        address tokenB,
        address lpToken,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to
    ) internal returns (uint amountA, uint amountB) {

        IERC20(lpToken).approve(address(dystRouter), liquidity);

        return dystRouter.removeLiquidity(
            tokenA,
            tokenB,
            true,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            block.timestamp + 600
        );
    }
}


abstract contract DystopiaExchange {

    uint256 public constant BASIS_POINTS_FOR_SLIPPAGE = 4;

    IDystopiaRouter private dystRouter;

    function _setDystopiaRouter(address _dystRouter) internal {
        dystRouter = IDystopiaRouter(_dystRouter);
    }

    function _getAmountsOut(
        address inputToken,
        address outputToken,
        bool isStablePair0,
        uint256 amountInput
    ) internal view returns (uint256) {

        IDystopiaRouter.Route[] memory route = new IDystopiaRouter.Route[](1);
        route[0].from = inputToken;
        route[0].to = outputToken;
        route[0].stable = isStablePair0;

        uint[] memory amounts = dystRouter.getAmountsOut(amountInput, route);

        return amounts[1];
    }

    function _getAmountsOut(
        address inputToken,
        address middleToken,
        address outputToken,
        bool isStablePair0,
        bool isStablePair1,
        uint256 amountInput
    ) internal view returns (uint256) {

        IDystopiaRouter.Route[] memory route = new IDystopiaRouter.Route[](2);
        route[0].from = inputToken;
        route[0].to = middleToken;
        route[0].stable = isStablePair0;
        route[1].from = middleToken;
        route[1].to = outputToken;
        route[1].stable = isStablePair1;

        uint[] memory amounts = dystRouter.getAmountsOut(amountInput, route);

        return amounts[2];
    }

    function _swapExactTokensForTokens(
        address inputToken,
        address outputToken,
        bool isStablePair0,
        uint256 amountInput,
        address recipient,
        uint256 amountOutMin
    ) internal returns (uint256) {

        IERC20(inputToken).approve(address(dystRouter), amountInput);

        uint256 amountOutMin = _getAmountsOut(address(inputToken), address(outputToken), isStablePair0, amountInput);
        if (amountOutMin == 0) {
            return 0;
        }

        IDystopiaRouter.Route[] memory route = new IDystopiaRouter.Route[](1);
        route[0].from = inputToken;
        route[0].to = outputToken;
        route[0].stable = isStablePair0;

        uint[] memory amounts = dystRouter.swapExactTokensForTokens(
            amountInput,
            amountOutMin,
            route,
            recipient,
            block.timestamp + 600
        );

        return amounts[1];
    }

    function _swapExactTokensForTokens(
        address inputToken,
        address middleToken,
        address outputToken,
        bool isStablePair0,
        bool isStablePair1,
        uint256 amountInput,
        address recipient
    ) internal returns (uint256) {

        IERC20(inputToken).approve(address(dystRouter), amountInput);

        uint256 amountOutMin = _getAmountsOut(address(inputToken), address(middleToken), address(outputToken), isStablePair0, isStablePair1, amountInput);
        if (amountOutMin == 0) {
            return 0;
        }

        IDystopiaRouter.Route[] memory route = new IDystopiaRouter.Route[](2);
        route[0].from = inputToken;
        route[0].to = middleToken;
        route[0].stable = isStablePair0;
        route[1].from = middleToken;
        route[1].to = outputToken;
        route[1].stable = isStablePair1;

        uint[] memory amounts = dystRouter.swapExactTokensForTokens(
            amountInput,
            0,
            route,
            recipient,
            block.timestamp + 600
        );

        return amounts[2];
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to
    ) internal returns (uint amountA, uint amountB, uint liquidity) {

        IERC20(tokenA).approve(address(dystRouter), amountADesired);
        IERC20(tokenB).approve(address(dystRouter), amountBDesired);

        return dystRouter.addLiquidity(
            tokenA,
            tokenB,
            true,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            to,
            block.timestamp + 600
        );

    }

    function _removeLiquidity(
        address tokenA,
        address tokenB,
        address lpToken,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to
    ) internal returns (uint amountA, uint amountB) {

        IERC20(lpToken).approve(address(dystRouter), liquidity);

        return dystRouter.removeLiquidity(
            tokenA,
            tokenB,
            true,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            block.timestamp + 600
        );
    }

    uint256[49] private __gap;
}
