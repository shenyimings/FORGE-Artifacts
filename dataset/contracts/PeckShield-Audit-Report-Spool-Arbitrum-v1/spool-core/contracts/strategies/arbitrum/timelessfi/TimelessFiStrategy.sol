// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../../NoRewardStrategy.sol";

import "../../../external/interfaces/timelessfi/IERC4626Gate.sol";
import "../../../external/interfaces/timelessfi/IXPYT.sol";

/**
 * @notice TimelessFi strategy implementation
 */
contract TimelessFiStrategy is NoRewardStrategy {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */
    
    /// @notice Timeless ERC4626-wrapped token
    IERC20 public immutable xPYT;

    /// @notice ERC4626-wrapped token
    address public immutable vault;

    /// @notice Deposit contract
    IERC4626Gate public immutable gate;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Set initial values
     * @param _xPYT Timeless ERC4626-wrapped token
     * @param _vault ERC4626-wrapped token
     * @param _gate Deposit contract
     * @param _underlying Underlying asset
     */
    constructor(
        IERC20 _xPYT,
        address _vault,
        IERC4626Gate _gate,
        IERC20 _underlying,
        address _self
    )
        NoRewardStrategy(_underlying, 0, 0, 0, false, _self)
    {
        require(
            address(_xPYT) != address(0),
            "TimelessFiStrategy::constructor: xPYT address cannot be 0"
        );
        require(
            _vault != address(0),
            "TimelessFiStrategy::constructor: Vault address cannot be 0"
        );
        require(
            _gate != IERC4626Gate(address(0)),
            "TimelessFiStrategy::constructor: Gate address cannot be 0"
        );

        xPYT = _xPYT;
        vault = _vault;
        gate = _gate;
    }

    /* ========== VIEWS ========== */
    /**
     * @notice Get strategy balance
     * @return Strategy balance
     */
    function getStrategyBalance() public view override returns (uint128) {
        uint256 pytBalance = xPYT.balanceOf(address(this));
        return SafeCast.toUint128(_getPYTTokenValue(pytBalance));
    }

    /**
     * @dev Deposit
     * @param amount Amount to deposit
     * @return Deposited amount
     */
    function _deposit(uint128 amount, uint256[] memory) internal override returns(uint128) {
        underlying.safeApprove(address(gate), amount);
        
        uint256 pytBalanceBefore = xPYT.balanceOf(address(this));
        gate.enterWithUnderlying(
            address(this),
            address(this),
            vault,
            address(xPYT),
            amount
        );
        uint256 pytBalanceNew = xPYT.balanceOf(address(this)) - pytBalanceBefore;

        _resetAllowance(underlying, address(gate));

        return SafeCast.toUint128(_getPYTTokenValue(pytBalanceNew));
    }

    /**
     * @dev Withdraw
     * @param shares Shares to withdraw
     * @return Withdrawn amount
     */
    function _withdraw(uint128 shares, uint256[] memory) internal override returns(uint128) {

        uint256 pytBalance = xPYT.balanceOf(address(this));
        uint256 pytWithdraw = (pytBalance * shares) / strategies[self].totalShares;
        xPYT.safeApprove(address(gate), pytWithdraw);

        uint balanceBefore = underlying.balanceOf(address(this));
        gate.exitToUnderlying(
            address(this),
            vault,
            address(xPYT),
            _getPYTTokenValue(pytWithdraw)
        );
        uint balance = underlying.balanceOf(address(this)) - balanceBefore;
        _resetAllowance(xPYT, address(gate));
        return SafeCast.toUint128(balance);
    }

    /**
     * @dev Emergency withdraw
     * @param recipient Recipient to withdraw to
     */
    function _emergencyWithdraw(address recipient, uint256[] calldata) internal override {
        uint256 pytBalance = xPYT.balanceOf(address(this));
        xPYT.safeApprove(address(gate), pytBalance);

        gate.exitToUnderlying(
            recipient,
            vault,
            address(xPYT),
            _getPYTTokenValue(pytBalance)
        );
        _resetAllowance(xPYT, address(gate));
    }


    function _getPYTTokenValue(uint256 pytTokenAmount) private view returns(uint256) {
        if (pytTokenAmount == 0)
            return 0;
        return IXPYT(address(xPYT)).convertToAssets(pytTokenAmount);
    }
}
