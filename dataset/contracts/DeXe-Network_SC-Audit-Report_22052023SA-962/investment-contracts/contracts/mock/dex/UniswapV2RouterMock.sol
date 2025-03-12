// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UniswapV2RouterMock {
    using SafeERC20 for IERC20;

    bool internal _nonLinear;

    mapping(address => uint256) public reserves;
    mapping(address => mapping(address => uint256)) public bonuses;
    mapping(address => mapping(address => address)) public pairs;

    function switchToNonLinear() external {
        _nonLinear = true;
    }

    function enablePair(address tokenA, address tokenB) external {
        pairs[tokenA][tokenB] = address(1);
        pairs[tokenB][tokenA] = address(1);
    }

    function setBonuses(address tokenA, address tokenB, uint256 amount) external {
        bonuses[tokenA][tokenB] = amount;
    }

    function setReserve(address token, uint256 amount) external {
        uint256 balance = IERC20(token).balanceOf(address(this));

        reserves[token] = amount;

        if (amount > balance) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount - balance);
        } else if (amount < balance) {
            IERC20(token).safeTransfer(msg.sender, balance - amount);
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256
    ) external returns (uint256[] memory amounts) {
        amounts = getAmountsOut(amountIn, path);

        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );

        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256
    ) external returns (uint256[] memory amounts) {
        amounts = getAmountsIn(amountOut, path);

        require(amounts[0] <= amountInMax, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");

        _swap(amounts, path, to);
    }

    function getAmountsOut(
        uint256 amountIn,
        address[] memory path
    ) public view returns (uint256[] memory amounts) {
        require(path.length >= 2, "UniswapV2Library: INVALID_PATH");

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = _getReserves(path[i], path[i + 1]);
            amounts[i + 1] =
                _getAmountOut(amounts[i], reserveIn, reserveOut) +
                bonuses[path[i]][path[i + 1]];
        }
    }

    function getAmountsIn(
        uint256 amountOut,
        address[] memory path
    ) public view returns (uint256[] memory amounts) {
        require(path.length >= 2, "UniswapV2Library: INVALID_PATH");

        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;

        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = _getReserves(path[i - 1], path[i]);
            amounts[i - 1] =
                _getAmountIn(amounts[i], reserveIn, reserveOut) -
                bonuses[path[i]][path[i - 1]];
        }
    }

    function getPair(address tokenA, address tokenB) external view returns (address) {
        return pairs[tokenA][tokenB];
    }

    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal virtual {
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amounts[0]);
        IERC20(path[path.length - 1]).safeTransfer(_to, amounts[amounts.length - 1]);

        for (uint256 i; i < path.length; i++) {
            reserves[path[i]] = IERC20(path[i]).balanceOf(address(this));
        }
    }

    function _getReserves(
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
        require(
            pairs[tokenA][tokenB] != address(0) || pairs[tokenB][tokenA] != address(0),
            "UniswapV2Library: PAIR_DOES_NOT_EXIST"
        );

        return (reserves[tokenA], reserves[tokenB]);
    }

    /// @dev modified formula for simplicity
    function _getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal view returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");

        if (_nonLinear) {
            amountIn = (amountOut * reserveIn) / (reserveOut - amountOut);
        } else {
            amountIn = (amountOut * reserveIn) / reserveOut;
        }
    }

    /// @dev modified formula for simplicity
    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal view returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");

        if (_nonLinear) {
            amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        } else {
            amountOut = (amountIn * reserveOut) / reserveIn;
        }
    }
}
