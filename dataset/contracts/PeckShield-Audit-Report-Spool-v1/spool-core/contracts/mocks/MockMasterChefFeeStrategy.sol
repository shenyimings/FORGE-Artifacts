// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../external/interfaces/masterchef/IMasterChef.sol";

import "../strategies/masterchef/shared/MasterChefStrategyBase.sol";
import "./MockUniswapHelper.sol";

contract MockMasterChefFeeStrategy is MasterChefStrategyBase, MockUniswapHelper {
    /* ========== CONSTRUCTOR ========== */

    constructor(
        IMasterChef _chef,
        IERC20 _rewardToken,
        uint256 _pid,
        IERC20 _underlying,
        IUniswapV2Router02 _uniswapRouter,
        address _WETH
    )
        MasterChefStrategyBase(_chef, _rewardToken, _pid, _underlying)
        MockUniswapHelper(_uniswapRouter, _WETH)
        SwapHelper(ISwapRouter02(address(_uniswapRouter)), _WETH)
    {}

    function _withdraw(uint128 shares, uint256[] memory) internal override returns(uint128) {
        uint256 balanceBefore = underlying.balanceOf(address(this));
        chef.withdraw(pid, _getSharesToAmount(shares));
        uint256 balanceAfter = underlying.balanceOf(address(this));

        return SafeCast.toUint128(balanceAfter - balanceBefore);
    }

    function _approveAndSwap(
        IERC20 from,
        IERC20 to,
        uint256 amount,
        SwapData calldata swapData
    ) internal override returns (uint256) {
        return _approveAndSwapMock(
            from,
            to,
            amount,
            swapData
        );
    }
}
