// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../RewardStrategy.sol";

import "../../../external/interfaces/aave/IAToken.sol";
import "../../../external/interfaces/aave/IPool.sol";
import "../../../external/interfaces/aave/IPoolAddressesProvider.sol";
import "../../../external/interfaces/aave/IRewardsController.sol";

/**
 * @notice AAVE V3 strategy implementation
 */
contract AaveV3Strategy is RewardStrategy {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    /// @notice AAVE token recieved after depositing into a lending pool 
    IAToken public immutable aToken;

    /// @notice Pool addresses provider
    IPoolAddressesProvider public immutable provider;

    /// @notice AAVE incentive controller
    IRewardsController public immutable incentive;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Set initial values
     * @param _provider Pool addresses provider contract address
     * @param _incentive Incentives controller contract address
     * @param _underlying Underlying asset
     */
    constructor(
        IPoolAddressesProvider _provider,
        IRewardsController _incentive,
        IERC20 _underlying,
        address _self
    )
        BaseStrategy(_underlying, 1, 0, 0, 0, false, false, _self)
        SwapHelper(Protocol.UNISWAP)
    {
        require(
            _provider != IPoolAddressesProvider(address(0)),
            "AaveV3Strategy::constructor: PoolAddressesProvider address cannot be 0"
        );
        require(
            _incentive != IRewardsController(address(0)),
            "AaveV3Strategy::constructor: RewardsController address cannot be 0"
        );

        provider = _provider;
        incentive = _incentive;

        IPool.ReserveData memory reserve = _provider
            .getPool()
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
        IPool pool = provider.getPool();
        
        underlying.safeApprove(address(pool), amount);
        pool.supply(
            address(underlying),
            amount,
            address(this),
            0
        );
        _resetAllowance(underlying, address(pool));
        return amount;
    }

    /**
     * @dev Withdraw
     * @param shares Shares to withdraw
     * @return Withdrawn amount
     */
    function _withdraw(uint128 shares, uint256[] memory) internal override returns(uint128) {
        return SafeCast.toUint128(
            provider.getPool().withdraw(
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
        provider.getPool().withdraw(
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
           
            (address[] memory rewardsAddresses, uint[] memory rewardAmounts) 
               = incentive.getAllUserRewards(tokens, address(this));
           
            if(rewardsAddresses.length > 0) {
                rewards = new Reward[](rewardsAddresses.length);
                
                for(uint i=0; i<rewards.length; i++){
                    address rewardsAddress = rewardsAddresses[i];
                    uint pendingReward = rewardAmounts[i];

                    uint256 claimAmount = _getRewardClaimAmount(shares, pendingReward);

                    if (claimAmount > 0) {
                        // we claim directly to uniswap router
                        incentive.claimRewards(
                            tokens,
                            claimAmount,
                            address(uniswapRouter),
                            rewardsAddress
                        );

                        // set amount to uint256 max, so uniswap helper knows the amount is already at the router
                        rewards[i] = Reward(type(uint256).max, IERC20(rewardsAddress));
                    }
                }
            }
        }
    }
}
