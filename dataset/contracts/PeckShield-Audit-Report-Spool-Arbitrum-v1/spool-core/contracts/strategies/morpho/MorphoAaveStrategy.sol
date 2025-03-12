// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../ClaimFullSingleRewardStrategy.sol";
import "../../external/interfaces/aave/IAToken.sol";
import "../../external/interfaces/morpho/IMorpho.sol";
import "../../external/interfaces/morpho/aave/ILens.sol";
import "../../interfaces/IAaveStrategyContractHelper.sol";

contract MorphoAaveStrategy is ClaimFullSingleRewardStrategy {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    /// @notice Morpho contract
    IMorpho public immutable morpho;
    /// @notice Aave market
    IAToken public immutable aToken;
    /// @notice Morpho Lens contract
    ILens public immutable lens;
    /// @notice helper contract that holds funds
    IAaveStrategyContractHelper public immutable strategyHelper;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Set initial values
     * @param _morpho Morpho contract
     * @param _aave AAVE token, reward token
     * @param _aToken Comptroller implementaiton
     * @param _underlying Underlying asset
     */
    constructor(
        IMorpho _morpho,
        IERC20 _aave,
        IAToken _aToken,
        IERC20 _underlying,
        IAaveStrategyContractHelper _strategyHelper,
        ILens _lens,
        address _self
    )
        BaseStrategy(_underlying, 1, 0, 0, 0, false, false, _self) 
        ClaimFullSingleRewardStrategy(_aave) 
    {
        require(address(_morpho) != address(0), "MorphoAaveStrategy::constructor: Morpho address cannot be 0");
        require(address(_aToken) != address(0), "MorphoAaveStrategy::constructor: aToken address cannot be 0");
        require(address(_lens) != address(0), "MorphoAaveStrategy::constructor: Lens address cannot be 0");
        require(address(_underlying) == _aToken.UNDERLYING_ASSET_ADDRESS(), "MorphoAaveStrategy::constructor: Underlying and aToken underlying do not match");
        require(_aToken == _strategyHelper.aToken(), "MorphoAaveStrategy::constructor: aToken is not the same as helpers aToken");
        require(_lens.isMarketCreated(address(_aToken)), "MorphoAaveStrategy::constructor: Morpho market not valid");
        morpho = _morpho;
        aToken = _aToken;
        strategyHelper = _strategyHelper;
        lens = _lens;
    }

    /* ========== VIEWS ========== */

    /**
     * @notice Get strategy balance
     * @return Strategy balance
     */
    function getStrategyBalance() public view override returns(uint128) {
        return SafeCast.toUint128(_getTotalBalance());
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    /**
     * @notice claim AAVE from the morpho contract
     */
    function _claimStrategyReward() internal override returns(uint128) {
        // claim AAVE rewards
        uint256 rewardAmount = strategyHelper.claimRewards(true);

        // add already claimed rewards
        rewardAmount += strategies[self].pendingRewards[address(rewardToken)];

        return SafeCast.toUint128(rewardAmount);
    }

    /**
     * @dev Transfers underlying tokens to the morpho contract
     */
    function _deposit(uint128 amount, uint256[] memory) internal override returns(uint128) {
        underlying.safeTransfer(address(strategyHelper), amount);

        strategyHelper.deposit(amount);

        return amount;
    }

    /**
     * @dev Withdraw lp tokens from the Morpho market
     */
    function _withdraw(uint128 shares, uint256[] memory) internal override returns(uint128) {

        // get withdraw amount
        uint256 withdrawAmount = (_getTotalBalance() * shares) / strategies[self].totalShares;
        uint256 undelyingWithdrawn = strategyHelper.withdraw(withdrawAmount);

        return SafeCast.toUint128(undelyingWithdrawn);
    }

    /**
     * @dev Emergency withdraw
     */
    function _emergencyWithdraw(address, uint256[] calldata data) internal override {
        strategyHelper.withdrawAll(data);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _getTotalBalance() private view returns(uint256) {
        (,, uint256 totalBalance) = lens.getCurrentSupplyBalanceInOf(address(aToken), address(strategyHelper));
        return totalBalance;
    }
}
