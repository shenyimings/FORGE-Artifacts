// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "../ISwapPlace.sol";
import "../connector/CurveStuff.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract CurveSwapPlace is ISwapPlace {

    using SafeERC20Upgradeable for IERC20Upgradeable;


    function swapPlaceType() external override pure returns (string memory) {
        return "CurveSwapPlace";
    }

    function swap(SwapRoute calldata route) external override returns (uint256) {
        IERC20Upgradeable(route.tokenIn).safeIncreaseAllowance(
            route.pool,
            IERC20(route.tokenIn).balanceOf(address(this))
        );
        (int128 indexIn, int128 indexOut, bool isUnderlying) = getIndexes(route.tokenIn, route.tokenOut, route.pool);

        uint256 transferBackAmount;
        if (isUnderlying) {
            transferBackAmount = IStableSwapPool(route.pool).exchange_underlying(
                indexIn,
                indexOut,
                route.amountIn,
                0
            );
        } else {
            transferBackAmount = IStableSwapPool(route.pool).exchange(
                indexIn,
                indexOut,
                route.amountIn,
                0
            );
        }

        IERC20(route.tokenOut).transfer(msg.sender, IERC20(route.tokenOut).balanceOf(address(this)));
        return transferBackAmount;
    }


    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address pool
    ) external override view returns (uint256) {
        (int128 indexIn, int128 indexOut, bool isUnderlying) = getIndexes(tokenIn, tokenOut, pool);
        if (isUnderlying) {
            return IStableSwapPool(pool).get_dy_underlying(indexIn, indexOut, amountIn);
        } else {
            return IStableSwapPool(pool).get_dy(indexIn, indexOut, amountIn);
        }
    }


    function getIndexes(
        address tokenIn,
        address tokenOut,
        address pool
    ) internal view returns (int128, int128, bool){
        int128 indexIn = type(int128).max;
        int128 indexOut = type(int128).max;

        // search in coins list
        uint256 i;
        while (true) {
            address token = getCoin(pool, i);
            if (token == address(0)) {
                break;
            }

            if (token == tokenIn) {
                indexIn = int128(uint128(i));
            } else if (token == tokenOut) {
                indexOut = int128(uint128(i));
            }
            i++;
        }

        if (indexIn != type(int128).max && indexOut != type(int128).max) {
            return (indexIn, indexOut, false);
        }

        if (indexIn != type(int128).max || indexOut != type(int128).max) {
            // one of tokens found in coins but not found another - it is incorrect
            // setup case for token pairs
            revert("CurveSP: incorrect token pair setup");
        }

        // search in underlying coins list
        i = 0;
        while (true) {
            address token = getUnderlyingCoin(pool, i);
            if (token == address(0)) {
                break;
            }

            if (token == tokenIn) {
                indexIn = int128(uint128(i));
            } else if (token == tokenOut) {
                indexOut = int128(uint128(i));
            }
            i++;
        }

        if (indexIn != type(int128).max && indexOut != type(int128).max) {
            return (indexIn, indexOut, true);
        }

        revert("CurveSP: Can't find index for tokens in pool");
    }


    function getCoin(address pool, uint256 index) internal view returns (address) {
        try IStableSwapPool(pool).coins(index) returns (address tokenAddress) {
            return tokenAddress;
        } catch {}
        return address(0);
    }

    function getUnderlyingCoin(address pool, uint256 index) internal view returns (address) {
        try IStableSwapPool(pool).underlying_coins(index) returns (address tokenAddress) {
            return tokenAddress;
        } catch {}
        return address(0);
    }
}
