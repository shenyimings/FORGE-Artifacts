// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../../interfaces/ICompoundStrategyContractHelper.sol";

import "../../external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../../external/interfaces/ICErc20.sol";
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
contract MorphoContractHelper is ICompoundStrategyContractHelper {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IMorpho public immutable morpho;
    IERC20 public immutable comp;
    ICErc20 public immutable override cToken;
    IERC20 public immutable underlying;
    address public immutable spool;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IMorpho _morpho,
        IERC20 _comp,
        ICErc20 _cToken,
        IERC20 _underlying,
        address _spool
    ) {
        require(address(_morpho) != address(0), "MorphoContractHelper::constructor: Morpho Token address cannot be 0");
        require(address(_comp) != address(0), "MorphoContractHelper::constructor: COMP Token address cannot be 0");
        require(address(_cToken) != address(0), "MorphoContractHelper::constructor: Token address cannot be 0");
        require(
            address(_underlying) == _cToken.underlying(),
            "MorphoContractHelper::constructor: Underlying and cToken underlying do not match"
        );
        require(_spool != address(0), "MorphoContractHelper::constructor: Spool address cannot be 0");

        morpho = _morpho;
        cToken = _cToken;
        comp = _comp;
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
            address[] memory cTokens = new address[](1);
            cTokens[0] = address(cToken);
            morpho.claimRewards(cTokens, false);
        }

        rewards = comp.balanceOf(address(this));

        IERC20(comp).safeTransfer(msg.sender, rewards);
    }

    /**
     * @notice Deposit to Morpho market
     * @dev
     * The Spool should send `underlying` token in size of `amount`
     * before calling this contract.
     * The contract deposits the received underlying and returns the
     * newly received cToken amount.
     *
     * @param amount Amount of underlying to deposit
     * @return cTokenBalanceNew Gained cToken amount from depositing
     */
    function deposit(uint256 amount) external override onlySpool returns (uint256) {
        underlying.safeApprove(address(morpho), amount);

        uint256 cTokenBefore = _getcTokenBalance();
        morpho.supply(address(cToken), address(this), amount);
        uint256 cTokenNew = _getcTokenBalance() - cTokenBefore;
        _resetAllowance(underlying, address(morpho));

        return cTokenNew;
    }

    /**
     * @notice Withdraw from Morpho market
     * @dev
     * The the withdrawn underlying amount is then send back to the Spool.
     *
     * @param cTokenUnderlyingWithdraw Amount of underlying tokens to withdraw
     * @return undelyingWithdrawn Gained underlying amount from withdrawing
     */
    function withdraw(uint256 cTokenUnderlyingWithdraw) external override onlySpool returns (uint256) {
        morpho.withdraw(address( cToken ), cTokenUnderlyingWithdraw);
        uint256 undelyingWithdrawn = underlying.balanceOf(address(this));

        // transfer withdrawn back to spool
        underlying.safeTransfer(msg.sender, undelyingWithdrawn);

        return undelyingWithdrawn;
    }

    function withdrawAll(uint256[] calldata) external override onlySpool returns (uint256) {
        morpho.withdraw(address( cToken ), type(uint256).max);

        uint256 undelyingWithdrawn = underlying.balanceOf(address(this));

        // transfer withdrawn back to spool
        underlying.safeTransfer(msg.sender, undelyingWithdrawn);

        return undelyingWithdrawn;
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

    /**
     * @dev Get cToken balance from the Morpho contract.
     */
    function _getcTokenBalance() private view returns(uint256) {
        (uint inP2P, uint onPool) = morpho.supplyBalanceInOf(address(cToken), address(this));
        return (inP2P + onPool);
    }

    function _onlySpool() private view {
        require(msg.sender == spool, "MorphoStrategy::_onlySpool: Caller is not the Spool contract");
    }

    /* ========== MODIFIERS ========== */

    modifier onlySpool() {
        _onlySpool();
        _;
    }
}
