// SPDX-License-Identifier: BUSL-1.1
// solhint-disable-next-line compiler-version
pragma solidity ^0.7.6;
pragma abicoder v2;

import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { PositionKey } from "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";

import { ISpotPricingStrategy } from "./_interfaces/ISpotPricingStrategy.sol";
import { IAlphaProVault } from "./_interfaces/external/IAlphaProVault.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/// @title UsdcSpotManager
/// @notice This contract is a programmatic manager for the USDC-SPOT Charm AlphaProVault.
contract UsdcSpotManager {
    /// @dev Token Constants.
    uint256 public constant ONE_SPOT = 1e9;
    uint256 public constant ONE_USDC = 1e6;

    /// @dev Decimals.
    uint256 public constant DECIMALS = 18;
    uint256 public constant ONE = (10 ** DECIMALS);

    /// @dev We bound the deviation factor to 100.0.
    uint256 public constant MAX_DEVIATION = 100 * ONE; // 100.0

    //-------------------------------------------------------------------------
    // Storage

    /// @notice The USDC-SPOT charm alpha vault.
    IAlphaProVault public immutable VAULT;

    /// @notice The underlying USDC-SPOT univ3 pool.
    IUniswapV3Pool public immutable POOL;

    /// @notice The vault's token0, the USDC token.
    address public immutable USDC;

    /// @notice The vault's token1, the SPOT token.
    address public immutable SPOT;

    /// @notice Pricing strategy to price the SPOT token.
    ISpotPricingStrategy public pricingStrategy;

    /// @notice The contract owner.
    address public owner;

    //-------------------------------------------------------------------------
    // Manager storage

    /// @notice The recorded deviation factor at the time of the last successful rebalance operation.
    uint256 public prevDeviation;

    //--------------------------------------------------------------------------
    // Modifiers

    modifier onlyOwner() {
        // solhint-disable-next-line custom-errors
        require(msg.sender == owner, "Unauthorized caller");
        _;
    }

    //-----------------------------------------------------------------------------
    // Constructor and Initializer

    /// @notice Constructor initializes the contract with provided addresses.
    /// @param vault_ Address of the AlphaProVault contract.
    /// @param pricingStrategy_ Address of the spot appraiser.
    constructor(IAlphaProVault vault_, ISpotPricingStrategy pricingStrategy_) {
        owner = msg.sender;

        VAULT = vault_;
        POOL = vault_.pool();
        USDC = vault_.token0();
        SPOT = vault_.token1();

        pricingStrategy = pricingStrategy_;
        // solhint-disable-next-line custom-errors
        require(pricingStrategy.decimals() == DECIMALS, "Invalid decimals");
    }

    //--------------------------------------------------------------------------
    // Owner only methods

    /// @notice Updates the owner role.
    function transferOwnership(address owner_) external onlyOwner {
        owner = owner_;
    }

    /// @notice Updates the Spot pricing strategy reference.
    function updatePricingStrategy(
        ISpotPricingStrategy pricingStrategy_
    ) external onlyOwner {
        pricingStrategy = pricingStrategy_;
    }

    /// @notice Updates the vault's liquidity range parameters.
    function setLiquidityRanges(
        int24 baseThreshold,
        uint24 fullRangeWeight,
        int24 limitThreshold
    ) external onlyOwner {
        // Update liquidity parameters on the vault.
        VAULT.setBaseThreshold(baseThreshold);
        VAULT.setFullRangeWeight(fullRangeWeight);
        VAULT.setLimitThreshold(limitThreshold);
    }

    /// @notice Forwards the given calldata to the vault.
    /// @param callData The calldata to pass to the vault.
    /// @return The data returned by the vault method call.
    function execOnVault(
        bytes calldata callData
    ) external onlyOwner returns (bytes memory) {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory r) = address(VAULT).call(callData);
        // solhint-disable-next-line custom-errors
        require(success, "Vault call failed");
        return r;
    }

    //--------------------------------------------------------------------------
    // External write methods

    /// @notice Executes vault rebalance.
    function rebalance() public {
        (uint256 deviation, bool deviationValid) = computeDeviationFactor();

        // We rebalance if the deviation factor has crossed ONE (in either direction).
        bool forceLiquidityUpdate = ((deviation <= ONE && prevDeviation > ONE) ||
            (deviation >= ONE && prevDeviation < ONE));

        // Execute rebalance.
        // NOTE: the vault.rebalance() will revert if enough time has not elapsed.
        // We thus override with a force rebalance.
        // https://learn.charm.fi/charm/technical-references/core/alphaprovault#rebalance
        forceLiquidityUpdate ? _execForceRebalance() : VAULT.rebalance();

        // We only activate the limit range liquidity, when
        // the vault sells SPOT and deviation is above ONE, or when
        // the vault buys SPOT and deviation is below ONE
        bool extraSpot = isOverweightSpot();
        bool activeLimitRange = deviationValid &&
            ((deviation >= ONE && extraSpot) || (deviation <= ONE && !extraSpot));

        // Trim positions after rebalance.
        if (!activeLimitRange) {
            _removeLimitLiquidity();
        }

        // Update rebalance state.
        prevDeviation = deviation;
    }

    /// @notice Computes the deviation between SPOT's market price and it's FMV price.
    /// @return The computed deviation factor.
    function computeDeviationFactor() public returns (uint256, bool) {
        uint256 spotMarketPrice = getSpotUSDPrice();
        (uint256 spotTargetPrice, bool spotTargetPriceValid) = pricingStrategy
            .perpPrice();
        (, bool usdcPriceValid) = pricingStrategy.usdPrice();
        bool deviationValid = (spotTargetPriceValid && usdcPriceValid);
        uint256 deviation = spotTargetPrice > 0
            ? FullMath.mulDiv(spotMarketPrice, ONE, spotTargetPrice)
            : type(uint256).max;
        deviation = (deviation > MAX_DEVIATION) ? MAX_DEVIATION : deviation;
        return (deviation, deviationValid);
    }

    //-----------------------------------------------------------------------------
    // External Public view methods

    /// @return The computed SPOT price in USD from the underlying univ3 pool.
    function getSpotUSDPrice() public view returns (uint256) {
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(VAULT.getTwap());
        uint256 ratioX192 = uint256(sqrtPriceX96) * sqrtPriceX96;
        uint256 usdcPerSpot = FullMath.mulDiv(ONE, (1 << 192), ratioX192);
        return FullMath.mulDiv(usdcPerSpot, ONE_SPOT, ONE_USDC);
    }

    /// @notice Checks the vault is overweight SPOT, and looking to sell the extra SPOT for USDC.
    function isOverweightSpot() public view returns (bool) {
        // NOTE: This assumes that in the underlying univ3 pool and
        // token0 is USDC and token1 is SPOT.
        int24 _marketPrice = VAULT.getTwap();
        int24 _limitLower = VAULT.limitLower();
        int24 _limitUpper = VAULT.limitUpper();
        int24 _limitPrice = (_limitLower + _limitUpper) / 2;
        // The limit range has more token1 than token0 if `_marketPrice >= _limitPrice`,
        // so the vault looks to sell token1.
        return (_marketPrice >= _limitPrice);
    }

    /// @return Number of decimals representing 1.0.
    function decimals() external pure returns (uint8) {
        return uint8(DECIMALS);
    }

    //-----------------------------------------------------------------------------
    // Private methods

    /// @dev A low-level method, which interacts directly with the vault and executes
    ///      a rebalance even when enough time hasn't elapsed since the last rebalance.
    function _execForceRebalance() private {
        uint32 _period = VAULT.period();
        VAULT.setPeriod(0);
        VAULT.rebalance();
        VAULT.setPeriod(_period);
    }

    /// @dev Removes the vault's limit range liquidity.
    ///      To be invoked right after a rebalance operation, as it assumes that
    ///      the vault has a active limit range liquidity.
    function _removeLimitLiquidity() private {
        int24 _limitLower = VAULT.limitLower();
        int24 _limitUpper = VAULT.limitUpper();
        (uint128 limitLiquidity, , , , ) = _position(_limitLower, _limitUpper);
        // docs: https://learn.charm.fi/charm/technical-references/core/alphaprovault#emergencyburn
        VAULT.emergencyBurn(_limitLower, _limitUpper, limitLiquidity);
    }

    /// @dev Wrapper around `IUniswapV3Pool.positions()`.
    function _position(
        int24 tickLower,
        int24 tickUpper
    ) private view returns (uint128, uint256, uint256, uint128, uint128) {
        bytes32 positionKey = PositionKey.compute(address(VAULT), tickLower, tickUpper);
        return POOL.positions(positionKey);
    }
}
