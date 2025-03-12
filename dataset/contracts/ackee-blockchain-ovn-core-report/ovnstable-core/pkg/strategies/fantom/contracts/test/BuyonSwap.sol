// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../connectors/uniswap/v2/interfaces/IUniswapV2Router02.sol";

/**
 * @dev Contract to learn how to swap on Uniswap
 */
contract BuyonSwap {

    function buy(address _tokenAddress, address _router) public payable {
        IUniswapV2Router02 router = IUniswapV2Router02(_router);

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = _tokenAddress;

        uint[] memory amountsOut = router.getAmountsOut(msg.value, path);

        amountsOut = router.swapExactETHForTokens{value: msg.value}(
            (amountsOut[1] * 9) / 10,
            path,
            msg.sender,
            block.timestamp + 600
        );
    }
}
