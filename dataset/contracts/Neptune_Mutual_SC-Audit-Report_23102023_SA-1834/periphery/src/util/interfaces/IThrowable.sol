// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

interface IThrowable {
  error AccessDeniedError(bytes32 requiredRole);
  error AlreadyInitializedError();
  error RelatedArrayItemCountMismatchError();
  error ExternalContractInvocationRevertError();
  error InvalidArgumentError(bytes32 argument);
  error ZeroAmountError(bytes32 argument);
  error ZeroAddressError(bytes32 argument);
  error InsufficientDepositError(uint256 required, uint256 provided);
  error WithdrawalTooHighError(uint256 balance, uint256 requested);
}
