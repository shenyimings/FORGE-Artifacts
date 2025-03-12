// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../RewardStrategy.sol";
import "../../shared/SwapHelperMainnet.sol";

import "../../external/interfaces/aave/IAToken.sol";
import "../../external/interfaces/aave/ILendingPoolAddressesProvider.sol";
import "../../external/interfaces/aave/IAaveIncentivesController.sol";
import "../../external/interfaces/aave/ILendingPool.sol";

contract AaveStrategy is RewardStrategy, SwapHelperMainnet {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public immutable stkAave;
    IAToken public immutable aToken;
    ILendingPoolAddressesProvider public immutable provider;
    IAaveIncentivesController public immutable incentive;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IERC20 _stkAave,
        ILendingPoolAddressesProvider _provider,
        IAaveIncentivesController _incentive,
        IERC20 _underlying
    )
        BaseStrategy(_underlying, 1, 0, 0, 0, false)
    {
        require(
            _stkAave != IERC20(address(0)),
            "AaveStrategy::constructor: stkAAVE address cannot be 0"
        );
        require(
            _provider != ILendingPoolAddressesProvider(address(0)),
            "AaveStrategy::constructor: LendingPoolAddressesProvider address cannot be 0"
        );
        require(
            _incentive != IAaveIncentivesController(address(0)),
            "AaveStrategy::constructor: AaveIncentivesController address cannot be 0"
        );

        stkAave = _stkAave;
        provider = _provider;
        incentive = _incentive;

        ILendingPool.ReserveData memory reserve = _provider
            .getLendingPool()
            .getReserveData(address(_underlying));
        aToken = IAToken(reserve.aTokenAddress);
    }

    /* ========== VIEWS ========== */

    function getStrategyBalance() public view override returns (uint128) {
        return SafeCast.toUint128(aToken.balanceOf(address(this)));
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    function _claimRewards(SwapData[] calldata swapData) internal override returns(Reward[] memory) {
        return _claimAaveRewards(type(uint128).max, swapData);
    }

    function _claimFastWithdrawRewards(uint128 shares, SwapData[] calldata swapData) internal override returns(Reward[] memory) {
        return _claimAaveRewards(shares, swapData);
    }

    function _deposit(uint128 amount, uint256[] memory) internal override returns(uint128) {
        ILendingPool lendingPool = provider.getLendingPool();
        
        underlying.safeApprove(address(lendingPool), amount);
        lendingPool.deposit(
            address(underlying),
            amount,
            address(this),
            0
        );

        return amount;
    }

    function _withdraw(uint128 shares, uint256[] memory) internal override returns(uint128) {
        return SafeCast.toUint128(
            provider.getLendingPool().withdraw(
                address(underlying),
                _getSharesToAmount(shares),
                address(this)
            )
        );
    }

    function _emergencyWithdraw(address recipient, uint256[] calldata) internal override {
        provider.getLendingPool().withdraw(
            address(underlying),
            type(uint256).max,
            recipient
        );
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _claimAaveRewards(uint128 shares, SwapData[] calldata swapData) private returns(Reward[] memory rewards) {
        if (swapData.length > 0 && swapData[0].slippage > 0) {
            address[] memory tokens = new address[](1);
            tokens[0] = address(aToken);

            uint256 pendingReward = incentive.getRewardsBalance(tokens, address(this));

            if (pendingReward > 0) {
                uint256 claimAmount = _getRewardClaimAmount(shares, pendingReward);

                if (claimAmount > 0) {
                    // we claim directly to uniswap router
                    incentive.claimRewards(
                        tokens,
                        claimAmount,
                        address(uniswapRouter)
                    );

                    rewards = new Reward[](1);
                    // set amout to uint256 max, so uniswap helper knows the amount is already at the router
                    rewards[0] = Reward(type(uint256).max, stkAave);
                }
            }
        }
    }
}