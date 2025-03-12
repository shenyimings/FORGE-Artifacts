// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface AnnexStablePool {

    // Get the amount of coin j(received) one would receive for swapping _dx of coin i(send).
    function get_dy(int128 sendToken, int128 receivedToken, uint256 _dx) external view returns (uint256);

    function get_dy_underlying(int128 sendToken, int128 receivedToken, uint256 _dx) external view returns (uint256);

    //Perform an exchange between two coins.
    // i: Index value for the coin to send
    // j: Index value of the coin to receive
    // _dx: Amount of i being exchanged
    // _min_dy: Minimum amount of j to receive
    // Returns the actual amount of coin j received. Index values can be found via the coins public getter method.
    function exchange(int128 sendToken, int128 receivedToken, uint256 _dx, uint256 _min_dy) external returns (uint256);

    function exchange_underlying(int128 sendToken, int128 receivedToken, uint256 _dx, uint256 _min_dy) external returns (uint256);

    function coins(uint256 i) external view returns (address);
    function underlying_coins(uint256 i) external view returns (address);

}

// Copy from CurveSwapPlace.sol

library AnnexLibrary {

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountMinOut,
        address pool
    ) internal returns (uint256) {
        IERC20(tokenIn).approve(pool, amountIn);
        (int128 indexIn, int128 indexOut, bool isUnderlying) = getIndexes(tokenIn, tokenOut, pool);

        uint256 backAmount;
        if (isUnderlying) {
            backAmount = AnnexStablePool(pool).exchange_underlying(
                indexIn,
                indexOut,
                amountIn,
                amountMinOut
            );
        } else {
            backAmount = AnnexStablePool(pool).exchange(
                indexIn,
                indexOut,
                amountIn,
                amountMinOut
            );
        }

        return backAmount;
    }


    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address pool
    ) internal view returns (uint256) {
        (int128 indexIn, int128 indexOut, bool isUnderlying) = getIndexes(tokenIn, tokenOut, pool);
        if (isUnderlying) {
            return AnnexStablePool(pool).get_dy_underlying(indexIn, indexOut, amountIn);
        } else {
            return AnnexStablePool(pool).get_dy(indexIn, indexOut, amountIn);
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
        try AnnexStablePool(pool).coins(index) returns (address tokenAddress) {
            return tokenAddress;
        } catch {}
        return address(0);
    }

    function getUnderlyingCoin(address pool, uint256 index) internal view returns (address) {
        try AnnexStablePool(pool).underlying_coins(index) returns (address tokenAddress) {
            return tokenAddress;
        } catch {}
        return address(0);
    }
}
