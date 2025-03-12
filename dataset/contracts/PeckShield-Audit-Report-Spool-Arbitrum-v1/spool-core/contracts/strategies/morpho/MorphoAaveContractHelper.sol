// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../../interfaces/IAaveStrategyContractHelper.sol";

import "../../external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../../external/interfaces/aave/IAToken.sol";
import "../../external/interfaces/morpho/IMorpho.sol";

/**
 * @notice This contract serves as a Morpho strategy helper.
 * @dev
 *
 * This is done as any address can claim MORPHO tokens for another address.
 * Having a separate contract for each Morpho strategy
 * gves us a way to collect the token rewards belonging
 * to this particular Spool strategy.
 * There should be one helper contract per Morpho strategy.
 *
 * It can only be called by the Spool contract.
 * It should be only be used by MorphoStrategy.
 */
contract MorphoAaveContractHelper is IAaveStrategyContractHelper {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IMorpho public immutable morpho;
    IERC20 public immutable aave;
    IAToken public immutable override aToken;
    IERC20 public immutable underlying;
    address public immutable spool;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IMorpho _morpho,
        IERC20 _aave,
        IAToken _aToken,
        IERC20 _underlying,
        address _spool
    ) {
        require(address(_morpho) != address(0), "MorphoAaveContractHelper::constructor: Morpho Token address cannot be 0");
        require(address(_aave) != address(0), "MorphoAaveContractHelper::constructor: AAVE Token address cannot be 0");
        require(address(_aToken) != address(0), "MorphoAaveContractHelper::constructor: Token address cannot be 0");
        require(
            address(_underlying) == _aToken.UNDERLYING_ASSET_ADDRESS(),
            "MorphoAaveContractHelper::constructor: Underlying and aToken underlying do not match"
        );
        require(_spool != address(0), "MorphoAaveContractHelper::constructor: Spool address cannot be 0");

        morpho = _morpho;
        aave = _aave;
        aToken = _aToken;
        underlying = _underlying;
        spool = _spool;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Claim rewards from Morpho proxy
     * @dev
     * Rewards are sent back to the Spool contract
     *
     * @param executeClaim Do execute the claim
     * @return rewards Amount of MORPHO tokens claimed
     */
    function claimRewards(bool executeClaim) external override onlySpool returns (uint256 rewards) {
        if (executeClaim) {
            address[] memory aTokens = new address[](1);
            aTokens[0] = address(aToken);
            morpho.claimRewards(aTokens, false);
        }

        rewards = aave.balanceOf(address(this));

        IERC20(aave).safeTransfer(msg.sender, rewards);
    }

    /**
     * @notice Deposit to Morpho market
     * @dev
     * The Spool should send `underlying` token in size of `amount`
     * before calling this contract.
     * The contract deposits the received underlying and returns the
     * newly received aToken amount.
     *
     * @param amount Amount of underlying to deposit
     * @return amount Gained amount from depositing
     */
    function deposit(uint256 amount) external override onlySpool returns (uint256) {
        underlying.safeApprove(address(morpho), amount);
        morpho.supply(address(aToken), address(this), amount);
        _resetAllowance(underlying, address(morpho));

        return amount;
    }

    /**
     * @notice Withdraw from Morpho market
     * @dev
     * The withdrawn underlying amount is then send back to the Spool.
     *
     * @param aTokenUnderlyingWithdraw Amount of underlying tokens to withdraw
     * @return underlyingToWithdraw Gained underlying amount from withdrawing and on the contract
     */
    function withdraw(uint256 aTokenUnderlyingWithdraw) external override onlySpool returns (uint256) {
        morpho.withdraw(address( aToken ), aTokenUnderlyingWithdraw);
        uint256 underlyingToWithdraw = underlying.balanceOf(address(this));

        // transfer withdrawn back to spool
        underlying.safeTransfer(msg.sender, underlyingToWithdraw);

        return underlyingToWithdraw;
    }

    function withdrawAll(uint256[] calldata) external override onlySpool returns (uint256) {
        morpho.withdraw(address( aToken ), type(uint256).max);

        uint256 underlyingWithdrawn = underlying.balanceOf(address(this));

        // transfer withdrawn back to spool
        underlying.safeTransfer(msg.sender, underlyingWithdrawn);

        return underlyingWithdrawn;
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /**
     * @notice Reset allowance to zero if previously set to a higher value.
     */
    function _resetAllowance(IERC20 token, address spender) internal {
        if (token.allowance(address(this), spender) > 0) {
            token.safeApprove(spender, 0);
        }
    }

    function _onlySpool() private view {
        require(msg.sender == spool, "MorphoAaveContractHelper::_onlySpool: Caller is not the Spool contract");
    }

    /* ========== MODIFIERS ========== */

    modifier onlySpool() {
        _onlySpool();
        _;
    }
}
