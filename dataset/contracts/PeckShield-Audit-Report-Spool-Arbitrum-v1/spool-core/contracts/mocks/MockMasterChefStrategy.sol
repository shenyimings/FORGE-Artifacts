// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../external/interfaces/masterchef/IMasterChef.sol";

import "../strategies/masterchef/shared/MasterChefStrategyBase.sol";
import "./MockUniswapHelper.sol";

contract MockMasterChefStrategy is MasterChefStrategyBase, MockUniswapHelper {
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
