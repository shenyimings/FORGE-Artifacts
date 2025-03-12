// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../external/uniswap/interfaces/IUniswapV2Router02.sol";
import "../shared/SwapHelper.sol";

contract MockUniswapHelper {
    using SafeERC20 for IERC20;

    // Uniswap Info
    IUniswapV2Router02 private immutable uniswapRouter;
    address private immutable WETH;

    constructor(IUniswapV2Router02 _uniswapRouter, address _WETH) {
        uniswapRouter = _uniswapRouter;
        WETH = _WETH;
    }

    function _approveAndSwapMock(
        IERC20 from,
        IERC20 to,
        uint256 amount,
        SwapData calldata swapData
    ) internal returns (uint256) {
        uint256 available = from.allowance(
            address(this),
            address(uniswapRouter)
        );

        if (available < amount) from.safeApprove(address(uniswapRouter), amount);

        // get swap action from first byte
        SwapAction action = SwapAction(uint8(swapData.path[0]));
        // slice the rest of the byte and use it as path
        // bytes memory bytesPath = swapData.path[1:];

        uint256 result;

        if (action == SwapAction.UNI_V2_DIRECT) { // V2 Direct
            address[] memory path = new address[](2);
            result = _swap(from, to, amount, swapData.slippage, path);
        } else if (action == SwapAction.UNI_V2_WETH) { // V2 WETH
            address[] memory path = new address[](3);
            path[1] = WETH;
            result = _swap(from, to, amount, swapData.slippage, path);
        } else if (action == SwapAction.UNI_V2) { // V2 Custom
            revert("SwapHelper::_approveAndSwap: Custom V2 not supported");
            // address[] memory path = _getV2Path(swapDetails.path);
            // return _swap(from, to, amount, swapData.slippage, path);
        } else {
            revert("SwapHelper::_approveAndSwap: No action");
        }

        if (from.allowance(address(this), address(uniswapRouter)) > 0) {
            from.safeApprove(address(uniswapRouter), 0);
        }

        return result;
    }

    function _swap(
        IERC20 from,
        IERC20 to,
        uint256 amount,
        uint256 slippage,
        address[] memory path
    ) internal virtual returns (uint256) {
        path[0] = address(from);
        path[path.length - 1] = address(to);

        uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
            amount,
            slippage,
            path,
            address(this),
            block.timestamp
        );

        return amounts[amounts.length - 1];
    }

    // function _getV2Path(bytes memory pathBytes) internal pure returns(address[] memory) {
    //     require(pathBytes.length % ADDR_SIZE == 0, "SwapHelper::_getV2Path: Bad V2 path");

    //     uint256 pathLength = pathBytes.length / ADDR_SIZE;
    //     address[] memory path = new address[](pathLength + 2);

    //     for (uint256 i = 0; i < pathLength; i++) {
    //         path[i + 1] = pathBytes.toAddress(i * ADDR_SIZE);
    //     }

    //     return path;
    // }
}
