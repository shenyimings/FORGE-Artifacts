// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

/// @title Blockscape Errors
/// @notice Shared contract for Blockscape Validator and Stake ETH NFTs to define the errors
/// @dev This contract is abstract and cannot be deployed
abstract contract BlockscapeErrors {
    /// @dev The vault is in the wrong state
    error ErrorVaultState(bool _isOpen);

    /// @dev more RPL stake has to be done in order to open vault
    error NotEnoughRPLStake();

    /// @dev Deposit value needs to align with RP poolsizes as specified in `curETHlimit`
    error IncorrectDepositValueSent();

    /// @dev The vault is already preparing for withdrawal
    error AlreadyPreparingForWithdrawal();

    /// @dev The withdrawal has a timelock which is not yet reached
    error WithdrawalTimelockNotReached(uint256 unlockTimestamp);

    /// @dev user does not own the NFT
    error YouDontOwnThisNft(uint256 _tokenID);

    /// @dev msg.value is zero
    error MsgValueZero();

    /// @dev rocket pool commission fee is too high
    error RPCommFee8TooHigh();

    /// @dev withdrawal fee is too low
    error WithdrawFeeTooHigh();

    /// @dev timelock is too high
    error TimelockTooHigh();
}
