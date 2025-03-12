// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../ClaimFullSingleRewardStrategy.sol";

import "../../external/interfaces/ICErc20.sol";
import "../../external/interfaces/compound/Comptroller/IComptroller.sol";
import "../../interfaces/ICompoundStrategyContractHelper.sol";

contract CompoundStrategy is ClaimFullSingleRewardStrategy {
    using SafeERC20 for IERC20;

    /* ========== CONSTANT VARIABLES ========== */

    /// @notice Helper value
    uint256 public immutable MANTISSA = 10 ** 18;

    /* ========== STATE VARIABLES ========== */

    /// @notice Compound market
    ICErc20 public immutable cToken;
    /// @notice Comptroller implementaiton
    IComptroller public immutable comptroller;
    ICompoundStrategyContractHelper public immutable strategyHelper;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Set initial values
     * @param _comp COMP token, reward token
     * @param _cToken Comptroller implementaiton
     * @param _comptroller Comptroller contract
     * @param _underlying Underlying asset
     */
    constructor(
        IERC20 _comp,
        ICErc20 _cToken,
        IComptroller _comptroller,
        IERC20 _underlying,
        ICompoundStrategyContractHelper _strategyHelper,
        address _self
    )
        BaseStrategy(_underlying, 1, 0, 0, 0, false, false, _self) 
        ClaimFullSingleRewardStrategy(_comp) 
    {
        require(address(_cToken) != address(0), "CompoundStrategy::constructor: Token address cannot be 0");
        require(address(_comptroller) != address(0), "CompoundStrategy::constructor: Comptroller address cannot be 0");
        require(address(_underlying) == _cToken.underlying(), "CompoundStrategy::constructor: Underlying and cToken underlying do not match");
        require(_cToken == _strategyHelper.cToken(), "CompoundStrategy::constructor: cToken is not the same as helpers cToken");
        cToken = _cToken;
        comptroller = _comptroller;
        strategyHelper = _strategyHelper;
    }

    /* ========== VIEWS ========== */

    /**
     * @notice Get strategy balance
     * @return Strategy balance
     */
    function getStrategyBalance() public view override returns(uint128) {
        uint256 cTokenBalance = cToken.balanceOf(address(strategyHelper));
        return SafeCast.toUint128(_getcTokenValue(cTokenBalance));
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    function _claimStrategyReward() internal override returns(uint128) {
        // claim COMP rewards
        uint256 rewardAmount = strategyHelper.claimRewards(true);

        // add already claimed rewards
        rewardAmount += strategies[self].pendingRewards[address(rewardToken)];

        return SafeCast.toUint128(rewardAmount);
    }

    /**
     * @dev Transfers lp tokens to helper contract, to deposit them into the Compound market
     */
    function _deposit(uint128 amount, uint256[] memory) internal override returns(uint128) {
        underlying.safeTransfer(address(strategyHelper), amount);

        uint256 cTokenBalanceNew = strategyHelper.deposit(amount);

        return SafeCast.toUint128(_getcTokenValue(cTokenBalanceNew));
    }

    /**
     * @dev Withdraw lp tokens from the Compound market
     */
    function _withdraw(uint128 shares, uint256[] memory) internal override returns(uint128) {
        // check strategy helper cToken balance
        uint256 cTokenBalance = cToken.balanceOf(address(strategyHelper));
        uint256 cTokenWithdraw = (cTokenBalance * shares) / strategies[self].totalShares;

        uint256 undelyingWithdrawn = strategyHelper.withdraw(cTokenWithdraw);

        return SafeCast.toUint128(undelyingWithdrawn);
    }

    /**
     * @dev Emergency withdraw
     * @param data to perform emergency withdaw
     */
    function _emergencyWithdraw(address, uint256[] calldata data) internal override {
        strategyHelper.withdrawAll(data);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /**
     * @dev Get value of the desire cTkoen amount in the underlying asset
     * @param cTokenBalance cToken value
     * @return underlyingAmount value og `cTokenBalance` in underlying token
     */
    function _getcTokenValue(uint256 cTokenBalance) private view returns(uint256) {
        if (cTokenBalance == 0)
            return 0;

        uint256 exchangeRateCurrent = cToken.exchangeRateStored();
        return (exchangeRateCurrent * cTokenBalance) / MANTISSA;
    }
}
