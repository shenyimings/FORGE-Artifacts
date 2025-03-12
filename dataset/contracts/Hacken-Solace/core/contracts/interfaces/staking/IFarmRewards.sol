// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;


/**
 * @title IFarmRewards
 * @author solace.fi
 * @notice Rewards farmers with [**SOLACE**](./../../SOLACE).
 *
 * Rewards were accumulated by farmers for participating in farms. Rewards will be unlocked linearly over six months and can be redeemed for [**SOLACE**](./../../SOLACE) by paying $0.03/[**SOLACE**](./../../SOLACE).
 */
interface IFarmRewards {

    /***************************************
    EVENTS
    ***************************************/

    event ReceiverSet(address receiver);

    /***************************************
    GLOBAL VARIABLES
    ***************************************/

    /// @notice [**xSOLACE**](./../../staking/xSOLACEV1) Token.
    function xsolace() external view returns (address);

    /// @notice receiver for payments
    function receiver() external view returns (address);

    /// @notice timestamp that rewards start vesting
    function VESTING_START() external view returns (uint256);

    /// @notice timestamp that rewards finish vesting
    function VESTING_END() external view returns (uint256);

    function solacePerXSolace() external view returns (uint256);

    /// @notice The stablecoins that can be used for payment.
    function tokenInSupported(address tokenIn) external view returns (bool);

    /// @notice Total farmed rewards of a farmer.
    function farmedRewards(address farmer) external view returns (uint256);

    /// @notice Redeemed rewards of a farmer.
    function redeemedRewards(address farmer) external view returns (uint256);

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Calculates the amount of token in needed for an amount of [**xSOLACE**](./../../staking/xSOLACEV1) out.
     * @param tokenIn The token to pay with.
     * @param amountOut The amount of [**xSOLACE**](./../../staking/xSOLACEV1) wanted.
     * @return amountIn The amount of `tokenIn` needed.
     */
    function calculateAmountIn(address tokenIn, uint256 amountOut) external view returns (uint256 amountIn);

    /**
     * @notice Calculates the amount of [**xSOLACE**](./../../staking/xSOLACEV1) out for an amount of token in.
     * @param tokenIn The token to pay with.
     * @param amountIn The amount of `tokenIn` in.
     * @return amountOut The amount of [**xSOLACE**](./../../staking/xSOLACEV1) out.
     */
    function calculateAmountOut(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut);

    /**
     * @notice The amount of [**xSOLACE**](./../../staking/xSOLACEV1) that a farmer has vested.
     * Does not include the amount they've already redeemed.
     * @param farmer The farmer to query.
     * @return amount The amount of vested [**xSOLACE**](./../../staking/xSOLACEV1).
     */
    function purchaseableVestedXSolace(address farmer) external view returns (uint256 amount);

    /***************************************
    MUTATOR FUNCTIONS
    ***************************************/

    /**
     * @notice Deposit tokens to redeem rewards.
     * @param tokenIn The token to use as payment.
     * @param amountIn The max amount to pay.
     */
    function redeem(address tokenIn, uint256 amountIn) external;

    /**
     * @notice Deposit tokens to redeem rewards.
     * @param tokenIn The token to use as payment.
     * @param amountIn The max amount to pay.
     * @param depositor The farmer that deposits.
     * @param deadline Time the transaction must go through before.
     * @param v secp256k1 signature
     * @param r secp256k1 signature
     * @param s secp256k1 signature
     */
    function redeemSigned(address tokenIn, uint256 amountIn, address depositor, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    /***************************************
    GOVERNANCE FUNCTIONS
    ***************************************/

    /**
     * @notice Adds support for tokens. Should be stablecoins.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param tokens The tokens to add support for.
     */
    function supportTokens(address[] calldata tokens) external;

    /**
     * @notice Sets the recipient for proceeds.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param receiver_ The new recipient.
     */
    function setReceiver(address payable receiver_) external;

    /**
     * @notice Returns excess [**xSOLACE**](./../../staking/xSOLACEV1).
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param amount Amount to send. Will be sent from this contract to `receiver`.
     */
    function returnXSolace(uint256 amount) external;

    /**
     * @notice Sets the rewards that farmers have earned.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param farmers Array of farmers to set.
     * @param rewards Array of rewards to set.
     */
    function setFarmedRewards(address[] calldata farmers, uint256[] calldata rewards) external;
}
