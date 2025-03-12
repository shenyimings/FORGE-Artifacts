// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IUniswapV2Router01 {

    function WETH() external pure returns (address);

    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IJoeRouter01 {

    function WAVAX() external pure returns (address);

    function swapExactAVAXForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

/**
 * @dev Contract to learn how to swap on Uniswap
 */
contract BuyonSwap {

    event SwapInfo(uint256 amountIn, uint256 amountOut);

    function buy(address _tokenAddress, address _router) public payable {
        if (_router == address(0x60aE616a2155Ee3d9A68541Ba4544862310933d4)) {
            IJoeRouter01 router = IJoeRouter01(_router);

            address[] memory path = new address[](2);
            path[0] = router.WAVAX();
            path[1] = _tokenAddress;

            uint[] memory amountsOut = router.getAmountsOut(msg.value, path);

            amountsOut = router.swapExactAVAXForTokens{value: msg.value}(
                (amountsOut[1] * 9) / 10,
                path,
                msg.sender,
                block.timestamp + 600
            );

            emit SwapInfo(amountsOut[0], amountsOut[1]);

        } else {
            IUniswapV2Router01 router = IUniswapV2Router01(_router);

            address[] memory path = new address[](2);
            path[0] = router.WETH();
            path[1] = _tokenAddress;

            uint[] memory amountsOut = router.getAmountsOut(msg.value, path);

            amountsOut = router.swapExactETHForTokens{value : msg.value}(
                (amountsOut[1] * 9) / 10,
                path,
                msg.sender,
                block.timestamp + 600
            );

            emit SwapInfo(amountsOut[0], amountsOut[1]);
        }
    }
}
