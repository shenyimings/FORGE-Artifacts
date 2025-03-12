// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../../interfaces/ICompoundStrategyContractHelper.sol";

import "../../external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../../external/interfaces/ICErc20.sol";
import "../../external/interfaces/compound/Comptroller/IComptroller.sol";

/**
 * @notice This contract serves as a Compound strategy helper.
 * @dev
 *
 * This is done as any address can claim COMP tokens for another address.
 * Having a separate contract for each Compound strategy
 * gves us a way to collect the COMP token rewards belonging
 * to this particular Spool strategy.
 * There should be one helper contract per Compound strategy.
 *
 * It can only be called by the Spool contract.
 * It should be only be used by CompoundStrategy.
 */
contract CompoundContractHelper is ICompoundStrategyContractHelper {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public immutable comp;
    ICErc20 public immutable override cToken;
    IERC20 public immutable underlying;
    IComptroller public immutable comptroller;
    address public immutable spool;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IERC20 _comp,
        ICErc20 _cToken,
        IComptroller _comptroller,
        IERC20 _underlying,
        address _spool
    ) {
        require(address(_comp) != address(0), "CompoundContractHelper::constructor: COMP Token address cannot be 0");
        require(address(_cToken) != address(0), "CompoundContractHelper::constructor: Token address cannot be 0");
        require(
            address(_comptroller) != address(0),
            "CompoundContractHelper::constructor: Comptroller address cannot be 0"
        );
        require(
            address(_underlying) == _cToken.underlying(),
            "CompoundContractHelper::constructor: Underlying and cToken underlying do not match"
        );
        require(_spool != address(0), "CompoundContractHelper::constructor: Spool address cannot be 0");

        comp = _comp;
        cToken = _cToken;
        underlying = _underlying;
        comptroller = _comptroller;
        spool = _spool;

        address[] memory markets = new address[](1);
        markets[0] = address(cToken);
        uint256[] memory results = comptroller.enterMarkets(markets);

        require(results[0] == 0, "CompoundContractHelper::constructor: Compound Enter Failed");
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Claim COMP rewards from Comptroller
     * @dev
     * Rewards are sent back to the Spool contract
     *
     * @param executeClaim Do execute the claim
     * @return rewards Amount of COMP tokens claimed
     */
    function claimRewards(bool executeClaim) external override onlySpool returns (uint256 rewards) {
        if (executeClaim) {
            address[] memory markets = new address[](1);
            markets[0] = address(cToken);
            comptroller.claimComp(address(this), markets);
        }

        rewards = comp.balanceOf(address(this));

        IERC20(comp).safeTransfer(msg.sender, rewards);
    }

    /**
     * @notice Deposit to Compound market
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
        underlying.safeApprove(address(cToken), amount);

        uint256 cTokenBalancebefore = cToken.balanceOf(address(this));
        require(cToken.mint(amount) == 0, "CompoundContractHelper::deposit: Compound Minting Error");
        uint256 cTokenBalanceNew = cToken.balanceOf(address(this)) - cTokenBalancebefore;
        _resetAllowance(underlying, address(cToken));

        return cTokenBalanceNew;
    }

    /**
     * @notice Withdraw from Compound market
     * @dev
     * The the withdrawn underlying amount is then send back to the Spool.
     *
     * @param cTokenWithdraw Amount of tokens to withdraw
     * @return undelyingWithdrawn Gained underlying amount from withdrawing
     */
    function withdraw(uint256 cTokenWithdraw) external override onlySpool returns (uint256) {
        require(cToken.redeem(cTokenWithdraw) == 0, "CompoundContractHelper::withdraw: Redemption Error");
        uint256 undelyingWithdrawn = underlying.balanceOf(address(this));

        // transfer withdrawn back to spool
        underlying.safeTransfer(msg.sender, undelyingWithdrawn);

        return undelyingWithdrawn;
    }

    function withdrawAll(uint256[] calldata data) external override onlySpool returns (uint256) {
        uint256 redemResult = cToken.redeem(cToken.balanceOf(address(this)));

        // if slippage length is 0 do not verify the error code
        require(
            redemResult == 0 || data.length == 0 || data[0] == 0,
            "CompoundStrategy::withdrawAll: Redemption Error"
        );

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

    function _onlySpool() private view {
        require(msg.sender == spool, "CompoundStrategy::_onlySpool: Caller is not the Spool contract");
    }

    /* ========== MODIFIERS ========== */

    modifier onlySpool() {
        _onlySpool();
        _;
    }
}
