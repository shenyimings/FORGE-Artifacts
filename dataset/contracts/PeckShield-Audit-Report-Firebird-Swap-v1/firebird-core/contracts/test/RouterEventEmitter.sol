pragma solidity =0.7.6;

import '../interfaces/IFireBirdRouter.sol';

contract RouterEventEmitter {
    event Amounts(uint[] amounts);

    receive() external payable {}

    function swapExactTokensForTokens(
        address router,
        address tokenIn,
        address tokenOut,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external {
        (bool success, bytes memory returnData) = router.delegatecall(abi.encodeWithSelector(
                IFireBirdRouter(router).swapExactTokensForTokens.selector, tokenIn, tokenOut, amountIn, amountOutMin, path, to, deadline
            ));
        assert(success);
        emit Amounts(abi.decode(returnData, (uint[])));
    }

    function swapTokensForExactTokens(
        address router,
        address tokenIn,
        address tokenOut,
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external {
        (bool success, bytes memory returnData) = router.delegatecall(abi.encodeWithSelector(
                IFireBirdRouter(router).swapTokensForExactTokens.selector, tokenIn, tokenOut, amountOut, amountInMax, path, to, deadline
            ));
        assert(success);
        emit Amounts(abi.decode(returnData, (uint[])));
    }

    function swapExactETHForTokens(
        address router,
        address tokenOut,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable {
        (bool success, bytes memory returnData) = router.delegatecall(abi.encodeWithSelector(
                IFireBirdRouter(router).swapExactETHForTokens.selector, tokenOut, amountOutMin, path, to, deadline
            ));
        assert(success);
        emit Amounts(abi.decode(returnData, (uint[])));
    }

    function swapTokensForExactETH(
        address router,
        address tokenIn,
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external {
        (bool success, bytes memory returnData) = router.delegatecall(abi.encodeWithSelector(
                IFireBirdRouter(router).swapTokensForExactETH.selector, tokenIn, amountOut, amountInMax, path, to, deadline
            ));
        assert(success);
        emit Amounts(abi.decode(returnData, (uint[])));
    }

    function swapExactTokensForETH(
        address router,
        address tokenIn,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external {
        (bool success, bytes memory returnData) = router.delegatecall(abi.encodeWithSelector(
                IFireBirdRouter(router).swapExactTokensForETH.selector, tokenIn, amountIn, amountOutMin, path, to, deadline
            ));
        assert(success);
        emit Amounts(abi.decode(returnData, (uint[])));
    }

    function swapETHForExactTokens(
        address router,
        address tokenOut,
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable {
        (bool success, bytes memory returnData) = router.delegatecall(abi.encodeWithSelector(
                IFireBirdRouter(router).swapETHForExactTokens.selector, tokenOut, amountOut, path, to, deadline
            ));
        assert(success);
        emit Amounts(abi.decode(returnData, (uint[])));
    }
}
