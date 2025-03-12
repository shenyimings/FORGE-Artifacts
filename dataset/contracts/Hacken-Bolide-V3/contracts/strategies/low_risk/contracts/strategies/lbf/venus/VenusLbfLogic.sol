// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
pragma abicoder v2;

import "../../../interfaces/ISwap.sol";
import "./VenusLogic.sol";

contract VenusLbfLogic is IFarmingLogic, VenusLogic {
    /*** Farming function ***/
    /**
     * @notice Adds liquidity to a BEP20⇄BEP20 pool.
     * @param swap Address of swap router
     * @param tokenA The contract address of one token from your liquidity pair.
     * @param tokenB The contract address of the other token from your liquidity pair.
     * if tokenB is address(0), call to addLiquidityETH()
     * @param amountADesired The amount of tokenA you'd like to provide as liquidity.
     * @param amountBDesired The amount of tokenA you'd like to provide as liquidity.
     * @param amountAMin The minimum amount of tokenA to provide (slippage impact).
     * @param amountBMin The minimum amount of tokenB to provide (slippage impact).
     * @param deadline Unix timestamp deadline by which the transaction must confirm.
     */
    function addLiquidity(
        address swap,
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 deadline
    )
        external
        override
        onlyOwnerAndAdmin
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        if (tokenB == ZERO_ADDRESS) {
            (amountADesired, amountBDesired, amountAMin) = IPancakeRouter01(
                swap
            ).addLiquidityETH{value: amountBDesired}(
                tokenA,
                amountADesired,
                amountAMin,
                amountBMin,
                address(this),
                deadline
            );
        } else {
            (amountADesired, amountBDesired, amountAMin) = IPancakeRouter01(
                swap
            ).addLiquidity(
                    tokenA,
                    tokenB,
                    amountADesired,
                    amountBDesired,
                    amountAMin,
                    amountBMin,
                    address(this),
                    deadline
                );
        }

        return (amountADesired, amountBDesired, amountAMin);
    }

    /**
     * @notice Removes liquidity from a BEP20⇄BEP20 pool.
     * @param swap Address of swap router
     * @param tokenA The contract address of one token from your liquidity pair.
     * @param tokenB The contract address of the other token from your liquidity pair.
     * if tokenB is address(0), call to removeLiquidityETH()
     * @param liquidity The amount of LP Tokens to remove.
     * @param amountAMin he minimum amount of tokenA to provide (slippage impact).
     * @param amountBMin The minimum amount of tokenB to provide (slippage impact).
     * @param deadline Unix timestamp deadline by which the transaction must confirm.
     */
    function removeLiquidity(
        address swap,
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 deadline
    )
        external
        override
        onlyOwnerAndAdmin
        returns (uint256 amountA, uint256 amountB)
    {
        if (tokenB == ZERO_ADDRESS) {
            (amountAMin, amountBMin) = IPancakeRouter01(swap)
                .removeLiquidityETH(
                    tokenA,
                    liquidity,
                    amountAMin,
                    amountBMin,
                    address(this),
                    deadline
                );
        } else {
            (amountAMin, amountBMin) = IPancakeRouter01(swap).removeLiquidity(
                tokenA,
                tokenB,
                liquidity,
                amountAMin,
                amountBMin,
                address(this),
                deadline
            );
        }

        return (amountAMin, amountBMin);
    }

    /**
     * @notice Deposit LP tokens to Master
     * @param swapMaster Address of swap master(Main staking contract)
     * @param _pid pool id
     * @param _amount amount of lp token
     */
    function farmingDeposit(
        address swapMaster,
        uint256 _pid,
        uint256 _amount
    ) external override onlyOwnerAndAdmin {
        IMasterChef(swapMaster).deposit(_pid, _amount);
    }

    /**
     * @notice Withdraw LP tokens from Master
     * @param swapMaster Address of swap master(Main staking contract)
     * @param _pid pool id
     * @param _amount amount of lp token
     */
    function farmingWithdraw(
        address swapMaster,
        uint256 _pid,
        uint256 _amount
    ) external override onlyOwnerAndAdmin {
        IMasterChef(swapMaster).withdraw(_pid, _amount);
    }

    /**
     * @notice Stake BANANA/Cake tokens to STAKING.
     * @param swapMaster Address of swap master(Main staking contract)
     * @param _amount amount of lp token
     */
    function enterStaking(address swapMaster, uint256 _amount)
        external
        onlyOwnerAndAdmin
    {
        IMasterChef(swapMaster).enterStaking(_amount);
    }

    /**
     * @notice Withdraw BANANA/Cake tokens from STAKING.
     * @param swapMaster Address of swap master(Main staking contract)
     * @param _amount amount of lp token
     */
    function leaveStaking(address swapMaster, uint256 _amount)
        external
        onlyOwnerAndAdmin
    {
        IMasterChef(swapMaster).leaveStaking(_amount);
    }
}
