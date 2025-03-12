// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../../external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../NoRewardStrategy.sol";
import "../../external/interfaces/idle-tranches/IIdleCDO.sol";

/**
 * @notice Idle Tranches without rewards Strategy implementation
 */
contract IdleTranchesNoReward is NoRewardStrategy {
    using SafeERC20 for IERC20;

    /* ========== CONSTANTS ========== */

    uint256 public constant ONE_TRANCHE_TOKEN = 10**18;

    /* ========== STATE VARIABLES ========== */

    /// @notice Idle tranches contract
    IIdleCDO public immutable idleCDO;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Set initial values
     * @param _idleCDO Idle tranches contract
     * @param _underlying Underlying asset
     * @param _self Self identifier
     */
    constructor(
        IIdleCDO _idleCDO,
        IERC20 _underlying,
        address _self
    )
        NoRewardStrategy(_underlying, 0, 0, 0, false, _self)
    {
        require(address(_idleCDO) != address(0), "IdleTranchesNoReward::constructor: Idle CDO address cannot be 0");
        require(_idleCDO.token() == address(_underlying), "IdleTranchesNoReward::constructor: Wrong underlying token");

        address[] memory incentiveTokens = _idleCDO.getIncentiveTokens();
        require(incentiveTokens.length == 0, "IdleTranchesNoReward::constructor: Strategy should not have any incentive tokens");

        idleCDO = _idleCDO;
    }

    /* ========== VIEWS ========== */

    /**
     * @notice Get strategy balance
     * @return Strategy balance
     */
    function getStrategyBalance() public view override returns(uint128) {
        return SafeCast.toUint128(_getIdleTokenValue(_getBBTokenBalance()));
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    /**
     * @notice Deposit
     * @param amount Amount to deposit
     * @return Minted amount in underlying
     */
    function _deposit(uint128 amount, uint256[] memory) internal override returns(uint128) {
        // deposit underlying
        underlying.safeApprove(address(idleCDO), amount);

        uint256 newBbTokens = idleCDO.depositBB(amount);
        
        _resetAllowance(underlying, address(idleCDO));

        return SafeCast.toUint128(_getIdleTokenValue(newBbTokens));
    }

    /**
     * @notice Withdraw
     * @param shares Shares to withdraw
     * @return Underlying withdrawn
     */
    function _withdraw(uint128 shares, uint256[] memory) internal override returns(uint128) {
        uint256 bbTokensWithdrawAmount = (_getBBTokenBalance() * shares) / strategies[self].totalShares;

        // withdraw idle tokens from vault
        uint256 underlyingBefore = underlying.balanceOf(address(this));
        idleCDO.withdrawBB(bbTokensWithdrawAmount);
        uint256 underlyingWithdrawn = underlying.balanceOf(address(this)) - underlyingBefore;

        return SafeCast.toUint128(underlyingWithdrawn);
    }

    /**
     * @notice Emergency withdraw
     */
    function _emergencyWithdraw(address, uint256[] calldata) internal override {
        idleCDO.withdrawBB(_getBBTokenBalance());
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _getIdleTokenValue(uint256 bbTokenAmount) private view returns(uint256) {
        if (bbTokenAmount == 0)
            return 0;

        return (bbTokenAmount * idleCDO.priceBB()) / ONE_TRANCHE_TOKEN;
    }

    function _getBBTokenBalance() private view returns(uint256) {
        return IERC20(idleCDO.BBTranche()).balanceOf(address(this));
    }
}
