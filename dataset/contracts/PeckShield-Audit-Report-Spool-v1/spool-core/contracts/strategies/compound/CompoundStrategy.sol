// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../ClaimFullSingleRewardStrategy.sol";

import "../../external/interfaces/ICErc20.sol";
import "../../external/interfaces/compound/Comptroller/IComptroller.sol";

contract CompoundStrategy is ClaimFullSingleRewardStrategy {
    using SafeERC20 for IERC20;

    /* ========== CONSTANT VARIABLES ========== */

    uint256 public immutable MANTISSA = 10 ** 18;

    /* ========== STATE VARIABLES ========== */

    ICErc20 public immutable cToken;
    IComptroller public immutable comptroller;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IERC20 _comp,
        ICErc20 _cToken,
        IComptroller _comptroller,
        IERC20 _underlying
    )
        BaseStrategy(_underlying, 1, 0, 0, 0, false) 
        ClaimFullSingleRewardStrategy(_comp) 
    {
        require(address(_cToken) != address(0), "CompoundStrategy::constructor: Token address cannot be 0");
        require(address(_comptroller) != address(0), "CompoundStrategy::constructor: Comptroller address cannot be 0");
        require(address(_underlying) != _cToken.underlying(), "CompoundStrategy::constructor: Underlying and cToken underlying do not match");
        cToken = _cToken;
        comptroller = _comptroller;
    }

    /* ========== VIEWS ========== */

    function getStrategyBalance() public view override returns(uint128) {
        uint256 cTokenBalance = cToken.balanceOf(address(this));
        return SafeCast.toUint128(_getcTokenValue(cTokenBalance));
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    /**
     * @dev Enter Compound market
     */
    function initialize() external override {
        address[] memory markets = new address[](1);
        markets[0] = address(cToken);

        uint256[] memory results = comptroller.enterMarkets(markets);

        require(
            results[0] == 0,
            "CompoundStrategy::constructor: Compound Enter Failed"
        );
    }

    function _claimStrategyReward() internal override returns(uint128) {
        address[] memory markets = new address[](1);
        markets[0] = address(cToken);

        // claim
        uint256 compBefore = rewardToken.balanceOf(address(this));
        comptroller.claimComp(address(this), markets);
        uint256 rewardAmount = rewardToken.balanceOf(address(this)) - compBefore;

        // add already claimed rewards
        rewardAmount += strategies[self].pendingRewards[address(rewardToken)];

        return SafeCast.toUint128(rewardAmount);
    }

    function _deposit(uint128 amount, uint256[] memory) internal override returns(uint128) {
        underlying.safeApprove(address(cToken), amount);

        uint256 cTokenBalancebefore = cToken.balanceOf(address(this));
        require(
            cToken.mint(amount) == 0,
            "CompoundStrategy::_deposit: Compound Minting Error"
        );
        uint256 cTokenBalanceNew = cToken.balanceOf(address(this)) - cTokenBalancebefore;


        return SafeCast.toUint128(_getcTokenValue(cTokenBalanceNew));
    }

    function _withdraw(uint128 shares, uint256[] memory) internal override returns(uint128) {
        uint256 cTokenBalance = cToken.balanceOf(address(this));
        uint256 cTokenWithdraw = (cTokenBalance * shares) / strategies[self].totalShares;

        uint256 undelyingBefore = underlying.balanceOf(address(this));
        uint redemResult = cToken.redeem(cTokenWithdraw);

        require(
            redemResult == 0,
            "CompoundStrategy::_withdraw: Redemption Error"
        );
        uint256 undelyingWithdrawn = underlying.balanceOf(address(this)) - undelyingBefore;

        return SafeCast.toUint128(undelyingWithdrawn);
    }

    function _emergencyWithdraw(address, uint256[] calldata data) internal override {
        uint256 redemResult = cToken.redeem(cToken.balanceOf(address(this)));

        // if slippage length is 0 do not verify the error code
        require(
            redemResult == 0 ||
            data.length == 0 ||
            data[0] == 0,
            "CompoundStrategy::_emergencyWithdraw: Redemption Error"
        );
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _getcTokenValue(uint256 cTokenBalance) private view returns(uint256) {
        if (cTokenBalance == 0)
            return 0;

        uint256 exchangeRateCurrent = cToken.exchangeRateStored();
        return (exchangeRateCurrent * cTokenBalance) / MANTISSA;
    }
}