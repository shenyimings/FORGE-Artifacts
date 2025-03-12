// SPDX-License-Identifier: MIT

pragma solidity 0.6;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import './IExchanger.sol';
import './IPancakeswap.sol';

contract PancakeswapExchangerAdapter is IExchanger {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable ROUTER;

    constructor(address _router) public {
        require(_router != address(0), 'ICP0');
        ROUTER = _router;
    }

    function exchange(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        bytes calldata exchangeData
    ) external override returns (uint256) {
        (, address[] memory path) = abi.decode(exchangeData, (bytes1, address[]));
        require(path[0] == fromToken && path[path.length - 1] == toToken, 'PEA: invalid path');

        IERC20(fromToken).safeIncreaseAllowance(ROUTER, fromAmount);

        uint256[] memory amounts = PancakeswapRouter(ROUTER).swapExactTokensForTokens(
            fromAmount,
            minToAmount,
            path,
            address(this),
            block.timestamp
        );

        return amounts[path.length - 1];
    }

    /**
     * All of the following functions are not used by any of the L2 connectors.
     * They remain to comply with the L1 IExchanger interface, but must revert to make sure no one calls them by accident.
     */

    function getAmountOut(
        address,
        address,
        uint256
    ) external view override returns (uint256) {
        revert('not implemented');
    }

    function getAmountIn(
        address,
        address,
        uint256
    ) external view override returns (uint256) {
        revert('not implemented');
    }

    function swapFromExact(
        address,
        address,
        uint256,
        uint256
    ) external override returns (uint256) {
        revert('not implemented');
    }

    function swapToExact(
        address,
        address,
        uint256,
        uint256
    ) external override returns (uint256) {
        revert('not implemented');
    }
}
