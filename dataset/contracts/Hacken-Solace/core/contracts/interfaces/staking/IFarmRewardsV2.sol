// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;


/**
 * @title FarmRewardsV2
 * @author solace.fi
 * @notice Rewards farmers with [**SOLACE**](./../../SOLACE).
 *
 * [FarmRewards V1](./../../staking/FarmRewards) rewarded CpFarmers in [**xSOLACEV1**](./../../staking/xSOLACEV1) linearly vested until May 2022. [**xSOLACEV1**](./../../staking/xSOLACEV1) was deprecated for [**xsLocker**](./../../staking/xsLocker) and will stop receiving rebases. FarmRewards V2 attachs on top of [FarmRewards V1](./../../staking/FarmRewards) and allows farmers to early withdraw their [**xSOLACEV1**](./../../staking/xSOLACEV1) and deposit it into a lock, as long as that lock ends after May 2022. This will give them staking rewards and voting power.
 *
 * FarmRewards V2 is an optional alternative to [FarmRewards V1](./../../staking/FarmRewards). Each user will decide how they would like their rewards. Either way, farmers will need to pay $0.03/[**SOLACE**](./../../SOLACE).
 */
interface IFarmRewardsV2 {

    /***************************************
    EVENTS
    ***************************************/

    event ReceiverSet(address receiver);

    /***************************************
    GLOBAL VARIABLES
    ***************************************/

    /// @notice Address of the [**SOLACE**](./../../SOLACE) contract.
    function solace() external view returns (address);
    /// @notice Address of the [**xSOLACEV1**](./../../staking/xSOLACEV1) contract.
    function xsolacev1() external view returns (address);
    /// @notice Address of the [**xsLocker**](./../../staking/xsLocker) contract.
    function xsLocker() external view returns (address);
    /// @notice Address of the [**FarmRewardsV1**](./../../staking/FarmRewards) contrcat.
    function farmRewardsv1() external view returns (address);
    /// @notice Receiver for payments.
    function receiver() external view returns (address);

    /// @notice timestamp that rewards finish vesting
    function VESTING_END() external view returns (uint256); // midnight UTC before May 1, 2022

    /// @notice The ID of the user's lock.
    function userLock(address user) external view returns (uint256 xsLockID);

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Calculates the amount of token in needed for an amount of [**SOLACE**](./../../SOLACE) out.
     * @param tokenIn The token to pay with.
     * @param amountOut The amount of [**SOLACE**](./../../SOLACE) wanted.
     * @return amountIn The amount of `tokenIn` needed.
     */
    function calculateAmountIn(address tokenIn, uint256 amountOut) external view returns (uint256 amountIn);

    /**
     * @notice Calculates the amount of [**SOLACE**](./../../SOLACE) out for an amount of token in.
     * @param tokenIn The token to pay with.
     * @param amountIn The amount of `tokenIn` in.
     * @return amountOut The amount of [**SOLACE**](./../../SOLACE) out.
     */
    function calculateAmountOut(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut);

    /**
     * @notice The amount of [**xSOLACEV1**](./xSOLACEV1) that a farmer can purchase.
     * Does not include the amount they've already redeemed.
     * @param farmer The farmer to query.
     * @return amount The amount of [**xSOLACEV1**](./xSOLACEV1).
     */
    function purchaseableXSolace(address farmer) external view returns (uint256 amount);

    /**
     * @notice The amount of [**SOLACE**](./../../SOLACE) that a farmer can purchase.
     * Does not include the amount they've already redeemed.
     * @param farmer The farmer to query.
     * @return amount The amount of [**SOLACE**](./../../SOLACE).
     */
    function purchaseableSolace(address farmer) external view returns (uint256 amount);

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
     * @notice Sets the recipient for proceeds.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param receiver_ The new recipient.
     */
    function setReceiver(address payable receiver_) external;

    /**
     * @notice Accepts the governance role for the FarmRewards V1 contract.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     */
    function acceptFarmRewardsV1Governance() external;

    /**
     * @notice Sets the pending governance role for the FarmRewards V1 contract.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param newGovernor The pending new governor.
     * @param newReceiver The FarmRewardsV1 receiver.
     */
    function setFarmRewardsV1Governance(address newGovernor, address newReceiver) external;

    /**
     * @notice Rescues tokens that may have been accidentally transferred in.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param token The token to rescue.
     * @param amount Amount of the token to rescue.
     */
    function rescueTokens(address token, uint256 amount) external;
}
