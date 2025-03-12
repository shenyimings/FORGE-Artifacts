// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../RewardStrategy.sol";
import "../../shared/SwapHelperMainnet.sol";

import "../../external/interfaces/aave/IAToken.sol";
import "../../external/interfaces/aave/ILendingPoolAddressesProvider.sol";
import "../../external/interfaces/aave/IAaveIncentivesController.sol";
import "../../external/interfaces/aave/ILendingPool.sol";

/**
 * @notice AAVE strategy implementation
 */
contract AaveStrategy is RewardStrategy, SwapHelperMainnet {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    /// @notice AAVE strategy reward token
    IERC20 public immutable stkAave;

    /// @notice AAVE token recieved after depositindinto a lending pool 
    IAToken public immutable aToken;

    /// @notice Lending pool addresses provider
    ILendingPoolAddressesProvider public immutable provider;

    /// @notice AAVE incentive controller
    IAaveIncentivesController public immutable incentive;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Set initial values
     * @param _stkAave AAVE strategy reward token
     * @param _provider Lending pool addresses provider contract address
     * @param _incentive Incentives controller contract address
     * @param _underlying Underlying asset
     * @param _underlying Underlying asset
     */
    constructor(
        IERC20 _stkAave,
        ILendingPoolAddressesProvider _provider,
        IAaveIncentivesController _incentive,
        IERC20 _underlying,
        address _self
    )
        BaseStrategy(_underlying, 1, 0, 0, 0, false, false, _self)
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

    /**
     * @notice Get strategy balance
     * @return Strategy balance
     */
    function getStrategyBalance() public view override returns (uint128) {
        return SafeCast.toUint128(aToken.balanceOf(address(this)));
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    /**
     * @dev Claim rewards
     * @param swapData Swap slippage and path
     */
    function _claimRewards(SwapData[] calldata swapData) internal override returns(Reward[] memory) {
        return _claimAaveRewards(type(uint128).max, swapData);
    }

    /**
     * @dev Claim fast withdraw rewards
     * @param shares Amount
     * @param swapData Swap slippage and path
     * @return Rewards
     */
    function _claimFastWithdrawRewards(uint128 shares, SwapData[] calldata swapData) internal override returns(Reward[] memory) {
        return _claimAaveRewards(shares, swapData);
    }

    /**
     * @dev Deposit
     * @param amount Amount to deposit
     * @return Deposited amount
     */
    function _deposit(uint128 amount, uint256[] memory) internal override returns(uint128) {
        ILendingPool lendingPool = provider.getLendingPool();
        
        underlying.safeApprove(address(lendingPool), amount);
        lendingPool.deposit(
            address(underlying),
            amount,
            address(this),
            0
        );
        _resetAllowance(underlying, address(lendingPool));
        return amount;
    }

    /**
     * @dev Withdraw
     * @param shares Shares to withdraw
     * @return Withdrawn amount
     */
    function _withdraw(uint128 shares, uint256[] memory) internal override returns(uint128) {
        return SafeCast.toUint128(
            provider.getLendingPool().withdraw(
                address(underlying),
                _getSharesToAmount(shares),
                address(this)
            )
        );
    }

    /**
     * @dev Emergency withdraw
     * @param recipient Recipient to withdraw to
     */
    function _emergencyWithdraw(address recipient, uint256[] calldata) internal override {
        provider.getLendingPool().withdraw(
            address(underlying),
            type(uint256).max,
            recipient
        );
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /**
     * @dev Claim AAVE rewards
     * @param shares Amount to claim
     * @param swapData Slippage and path array
     * @return rewards array of claimed rewards
     */
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
