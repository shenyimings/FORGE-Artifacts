// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IStableSwapPool {

    function add_liquidity(uint256[3] memory _amounts, uint256 _min_mint_amount, bool _use_underlying) external returns (uint256);

    function add_liquidity(uint256[2] memory _amounts, uint256 _min_mint_amount) external returns (uint256);

    function remove_liquidity(uint256 _amount, uint256[3] memory _min_amounts, bool _use_underlying) external returns (uint256[3] memory);

    function remove_liquidity(uint256 _amount, uint256[2] memory _min_amounts) external returns (uint256[2] memory);

    function underlying_coins(uint256 i) external view returns (address);

    function lp_token() external view returns (address);

    function calc_token_amount(uint256[3] memory _amounts, bool _is_deposit) external view returns (uint256);

    function calc_token_amount(uint256[2] memory _amounts, bool _is_deposit) external view returns (uint256);

    function coins(uint256 i) external view returns (address);

    function get_virtual_price() external view returns (uint256);

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

    function calc_withdraw_one_coin(uint256 _token_amount, int128 i) external view returns (uint256);

    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 _min_amount) external returns (uint256);

    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 _min_amount, bool _use_underlying) external returns (uint256);

}

interface IMetaSwapPool {

    // Get the amount of coin j(received) one would receive for swapping _dx of coin i(send).
    function get_dy(address _pool, int128 sendToken, int128 receivedToken, uint256 _dx) external view returns (uint256);

    function get_dy_underlying(address _pool, int128 sendToken, int128 receivedToken, uint256 _dx) external view returns (uint256);

    //Perform an exchange between two coins.
    // i: Index value for the coin to send
    // j: Index value of the coin to receive
    // _dx: Amount of i being exchanged
    // _min_dy: Minimum amount of j to receive
    // Returns the actual amount of coin j received. Index values can be found via the coins public getter method.
    function exchange(address _pool, int128 sendToken, int128 receivedToken, uint256 _dx, uint256 _min_dy) external returns (uint256);

    function exchange_underlying(address _pool, int128 sendToken, int128 receivedToken, uint256 _dx, uint256 _min_dy) external returns (uint256);
}

interface IRewardsOnlyGauge is IERC20 {

    function deposit(uint256 _value, address _addr, bool _claim_rewards) external;

    function deposit(uint256 _value, address _addr) external;

    function deposit(uint256 _value, bool _claim_rewards) external;

    function deposit(uint256 _value) external;

    function withdraw(uint256 _value, bool _claim_rewards) external;

    function withdraw(uint256 _value) external;

    function lp_token() external returns (address);

    function claim_rewards(address _addr, address _receiver) external;

    function claim_rewards(address _addr) external;

    function claim_rewards() external;

    function claimed_reward(address _addr, address _token) external returns (uint256);

    function claimable_reward(address _addr, address _token) external returns (uint256);

    function claimable_reward_write(address _addr, address _token) external returns (uint256);
}

library CurveMetaLibrary {

    function swapByIndex(
        int128  indexIn,
        int128  indexOut,
        bool isUnderlying,
        uint256 amountIn,
        uint256 amountMinOut,
        address meta,
        address pool
    ) internal returns (uint256) {

        uint256 backAmount;
        if (isUnderlying) {
            backAmount = IMetaSwapPool(meta).exchange_underlying(
                pool,
                indexIn,
                indexOut,
                amountIn,
                amountMinOut
            );
        } else {
            backAmount = IMetaSwapPool(meta).exchange(
                pool,
                indexIn,
                indexOut,
                amountIn,
                amountMinOut
            );
        }

        return backAmount;
    }

    function getAmountOutByIndex(
        int128 indexIn,
        int128 indexOut,
        bool isUnderlying,
        uint256 amountIn,
        address meta,
        address pool
    ) internal view returns (uint256) {
        if (isUnderlying) {
            return IMetaSwapPool(meta).get_dy_underlying(pool,indexIn, indexOut, amountIn);
        } else {
            return IMetaSwapPool(meta).get_dy(pool,indexIn, indexOut, amountIn);
        }
    }
}

library CurveLibrary {



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
            backAmount = IStableSwapPool(pool).exchange_underlying(
                indexIn,
                indexOut,
                amountIn,
                amountMinOut
            );
        } else {
            backAmount = IStableSwapPool(pool).exchange(
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
