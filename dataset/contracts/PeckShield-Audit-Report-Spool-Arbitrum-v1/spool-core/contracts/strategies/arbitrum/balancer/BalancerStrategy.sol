// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../../NoRewardStrategy.sol";

import "../../../external/@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "../../../external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../../../external/interfaces/balancer/IBalancerVault.sol";
import "../../../external/interfaces/balancer/IStablePool.sol";

/**
 * @notice Balancer Strategy implementation
 */
contract BalancerStrategy is NoRewardStrategy {
    using SafeERC20 for IERC20;

    /* ========== CONSTANT VARIABLES ========== */

    uint256 internal immutable MANTISSA;

    /* ========== STATE VARIABLES ========== */

    /// @notice Vault contract
    IBalancerVault public immutable vault;

    /// @notice Pool contract (BPT: Balancer Pool Token)
    IStablePool public immutable pool;

    /// @notice Balancer Pool ID
    bytes32 public immutable poolId;

    /// @notice index of underlying coin in pool
    uint256 public immutable nCoin;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Set initial values
     * @param _pool Pool contract
     * @param _underlying Underlying asset
     * @param _nCoin index of underlying coin in pool
     */
    constructor(
        IStablePool _pool,
        IERC20Metadata _underlying,
        uint256 _nCoin,
        address _self
    )
        NoRewardStrategy(_underlying, 1, 1, 1, false, _self)
    {
        require(address(_pool) != address(0), "BalancerStrategy::constructor: Pool address cannot be 0");
        vault = IBalancerVault(_pool.getVault());
        poolId = _pool.getPoolId();
        (IAsset[] memory _assets,,) = vault.getPoolTokens(poolId);

        require(address(_underlying) == address( _assets[_nCoin] ), "BalancerStrategy::constructor: Underlying address and nCoin invalid");

        pool = _pool;
        nCoin = _nCoin;

        // we derive the underlying amount from BPT token amount; the mantissa
        // is used to convert (see _lpToCoin()).
        // BPT and underlying token decimals may differ, so we handle that here.
        int uDecimals = int(int8(_underlying.decimals()));
        int pDecimals = int(int8(_pool.decimals()));
        MANTISSA =  10 ** uint(pDecimals + (pDecimals - uDecimals));
    }

    /* ========== VIEWS ========== */

    /**
     * @notice Get strategy balance
     * @return Strategy balance
     */
    function getStrategyBalance() public view override returns(uint128) {
        return _lpToCoin(_lpBalance());
    }

    /* ========== OVERRIDDEN FUNCTIONS ========== */

    /**
     * @notice Deposit
     * @param amount Amount to deposit
     * @param slippages Slippages array
     * @return minted BPT amount
     */
    function _deposit(uint128 amount, uint256[] memory slippages) internal override returns(uint128) {
        (bool isDeposit, uint256 slippage) = _getSlippageAction(slippages[0]);
        require(isDeposit, "BalancerStrategy::_deposit: Withdraw slippage provided");
        
        (IAsset[] memory _assets,,) = vault.getPoolTokens(poolId);
        uint256[] memory _maxAmountsIn = new uint256[](_assets.length);
        uint256[] memory _amountsIn = new uint256[](_assets.length);

        _maxAmountsIn[nCoin] = amount;
        _amountsIn[nCoin] = amount;

        bytes memory _userData = abi.encode(
            IStablePool.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
            _amountsIn,
            slippage
        );

        JoinPoolRequest memory poolRequest = JoinPoolRequest({
            assets : _assets,
            maxAmountsIn : _maxAmountsIn,
            userData : _userData,
            fromInternalBalance : false
        });

        // deposit underlying
        underlying.safeApprove(address(vault), amount);

        uint256 bptTokenBefore = pool.balanceOf(address(this));
        vault.joinPool(poolId, address(this), address(this), poolRequest);
        uint256 bptTokenNew = pool.balanceOf(address(this)) - bptTokenBefore;
        _resetAllowance(underlying, address(vault));

        require(
            bptTokenNew >= slippage,
            "BalancerStrategy::_deposit: Insufficient BPT Amount Minted"
        );

        emit Slippage(self, underlying, true, amount, bptTokenNew);

        strategies[self].lpTokens += bptTokenNew;

        return _lpToCoin(bptTokenNew);
    }

    /**
     * @notice Withdraw
     * @param shares Shares to withdraw
     * @param slippages Slippages array
     * @return Underlying withdrawn
     */
    function _withdraw(uint128 shares, uint256[] memory slippages) internal override returns(uint128) {
        (bool isDeposit, uint256 slippage) = _getSlippageAction(slippages[0]);
        require(!isDeposit, "BalancerStrategy::_withdraw: Deposit slippage provided");

        uint256 totalLp = _lpBalance();

        uint256 bptTokenWithdraw = (totalLp * shares) / strategies[self].totalShares;
        strategies[self].lpTokens -= bptTokenWithdraw;

        (IAsset[] memory _assets,,) = vault.getPoolTokens(poolId);
        uint256[] memory _minAmountsOut = new uint256[](_assets.length);

        _minAmountsOut[nCoin] = slippage;

        bytes memory _userData = abi.encode(
            IStablePool.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
            bptTokenWithdraw,
            nCoin
        );

        ExitPoolRequest memory poolRequest = ExitPoolRequest({
            assets : _assets,
            minAmountsOut : _minAmountsOut,
            userData : _userData,
            toInternalBalance : false
        });

        // withdraw idle tokens from vault
        uint256 underlyingBefore = underlying.balanceOf(address(this));
        vault.exitPool(poolId, address(this), address(this), poolRequest);
        uint256 underlyingWithdrawn = underlying.balanceOf(address(this)) - underlyingBefore;
        
        return SafeCast.toUint128(underlyingWithdrawn);
    }

    /**
     * @notice Emergency withdraw
     * @param recipient Address to withdraw to
     * @param data Data to perform emergency withdrawal
     */
    function _emergencyWithdraw(address recipient, uint256[] calldata data) internal override {
        // if no data provided set max loss to 100%
        uint256 maxLoss = data.length > 0 ? data[0] : 0;

        (IAsset[] memory _assets,,) = vault.getPoolTokens(poolId);
        uint256[] memory _minAmountsOut = new uint256[](_assets.length);
        _minAmountsOut[nCoin] = maxLoss;

        bytes memory _userData = abi.encode(
            IStablePool.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
            _lpBalance(),
            nCoin
        );

        ExitPoolRequest memory poolRequest = ExitPoolRequest({
            assets : _assets,
            minAmountsOut : _minAmountsOut,
            userData : _userData,
            toInternalBalance : false
        });

        vault.exitPool(poolId, address(this), recipient, poolRequest);
        strategies[self].lpTokens = 0;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /// @notice get lp tokens for the strategy
    function _lpBalance() internal view returns (uint256) {
        return strategies[self].lpTokens;
    }

    /**
     * @notice convert LP to underlying
     * @param lp amount of lp tokens to convert
     */
    function _lpToCoin(uint256 lp) internal view returns (uint128) {
        if (lp == 0)
            return 0;
        
        uint256 lpToCoin = pool.getRate();

        uint256 result = (lp * lpToCoin) / MANTISSA;

        return SafeCast.toUint128(result);
    }
}
