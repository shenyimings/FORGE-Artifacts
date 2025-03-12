// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import './IUniswap.sol';

contract ControlledExchanger is IUniswapRouterV2 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable ROUTER;
    uint256 public constant MANTISSA = 1e18;

    mapping(address => uint256) private priceUpdates;

    constructor(address _router) public {
        ROUTER = _router;
    }

    function setPriceUpdate(address token, uint256 priceChangeFactor) external {
        priceUpdates[token] = priceChangeFactor;
    }

    function getPriceUpdate(address token) public view returns (uint256) {
        return priceUpdates[token] == 0 ? MANTISSA : priceUpdates[token];
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256
    ) external override returns (uint256[] memory amounts) {
        amounts = getAmountsOut(amountIn, path);
        require(amounts[1] >= amountOutMin, 'ExchangerRouterMock: slippage check');
        executeTransfer(path, amounts, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256
    ) external override returns (uint256[] memory amounts) {
        amounts = getAmountsIn(amountOut, path);
        require(amounts[0] <= amountInMax, 'ExchangerRouterMock: slippage check');
        executeTransfer(path, amounts, to);
    }

    function executeTransfer(
        address[] calldata path,
        uint256[] memory amounts,
        address to
    ) internal {
        require(amounts[1] <= IERC20(path[1]).balanceOf(address(this)), 'ExchangerRouterMock ran out of funds');
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amounts[0]);
        IERC20(path[1]).safeTransfer(to, amounts[1]);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        override
        returns (uint256[] memory amounts)
    {
        amounts = IUniswapRouterV2(ROUTER).getAmountsOut(amountIn, path);
        amounts[1] = amounts[1].mul(getPriceUpdate(path[0])).div(getPriceUpdate(path[1]));
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        override
        returns (uint256[] memory amounts)
    {
        amounts = IUniswapRouterV2(ROUTER).getAmountsIn(amountOut, path);
        amounts[0] = amounts[0].mul(getPriceUpdate(path[1])).div(getPriceUpdate(path[0]));
    }
}
