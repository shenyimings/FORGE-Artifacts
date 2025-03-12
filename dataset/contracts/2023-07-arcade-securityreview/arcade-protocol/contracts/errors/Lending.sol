// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../libraries/LoanLibrary.sol";

/**
 * @title LendingErrors
 * @author Non-Fungible Technologies, Inc.
 *
 * This file contains custom errors for the core lending protocol contracts, with errors
 * prefixed by the contract that throws them (e.g., "OC_" for OriginationController).
 * Errors located in one place to make it possible to holistically look at all
 * protocol failure cases.
 */

// ==================================== ORIGINATION CONTROLLER ======================================
/// @notice All errors prefixed with OC_, to separate from other contracts in the protocol.

/// @notice Zero address passed in where not allowed.
error OC_ZeroAddress();

/**
 * @notice Ensure valid loan state for loan lifceycle operations.
 *
 * @param state                         Current state of a loan according to LoanState enum.
 */
error OC_InvalidState(LoanLibrary.LoanState state);

/**
 * @notice Loan duration must be greater than 1hr and less than 3yrs.
 *
 * @param durationSecs                 Total amount of time in seconds.
 */
error OC_LoanDuration(uint256 durationSecs);

/**
 * @notice Interest must be greater than 0.01% and less than 10,000%. (interestRate / 1e18 >= 1)
 *
 * @param interestRate                  InterestRate with 1e18 multiplier.
 */
error OC_InterestRate(uint256 interestRate);

/**
 * @notice One of the predicates for item verification failed.
 *
 * @param borrower                      The address of the borrower.
 * @param lender                        The address of the lender.
 * @param verifier                      The address of the verifier contract.
 * @param collateralAddress             The address of the collateral token.
 * @param collateralId                  The token ID of the collateral.
 * @param data                          The verification data (to be parsed by verifier).
 */
error OC_PredicateFailed(
    address borrower,
    address lender,
    address verifier,
    address collateralAddress,
    uint256 collateralId,
    bytes data
);

/**
 * @notice The predicates array is empty.
 */
error OC_PredicatesArrayEmpty();

/**
 * @notice A caller attempted to approve themselves.
 *
 * @param caller                        The caller of the approve function.
 */
error OC_SelfApprove(address caller);

/**
 * @notice A caller attempted to originate a loan with their own signature.
 *
 * @param caller                        The caller of the approve function, who was also the signer.
 */
error OC_ApprovedOwnLoan(address caller);

/**
 * @notice The signature could not be recovered to the counterparty or approved party.
 *
 * @param target                        The target party of the signature, which should either be the signer,
 *                                      or someone who has approved the signer.
 * @param signer                        The signer determined from ECDSA.recover.
 */
error OC_InvalidSignature(address target, address signer);

/**
 * @notice The verifier contract specified in a predicate has not been whitelisted.
 *
 * @param verifier                      The verifier the caller attempted to use.
 */
error OC_InvalidVerifier(address verifier);

/**
 * @notice The function caller was neither borrower or lender, and was not approved by either.
 *
 * @param caller                        The unapproved function caller.
 */
error OC_CallerNotParticipant(address caller);

/**
 * @notice Signer is attempting to take the wrong side of the loan.
 *
 * @param signer                       The address of the external signer.
 */
error OC_SideMismatch(address signer);

/**
 * @notice Two related parameters for batch operations did not match in length.
 */
error OC_BatchLengthMismatch();

/**
 * @notice Principal must be greater than 9999 Wei.
 *
 * @param principal                     Principal in ether.
 */
error OC_PrincipalTooLow(uint256 principal);

/**
 * @notice Signature must not be expired.
 *
 * @param deadline                      Deadline in seconds.
 */
error OC_SignatureIsExpired(uint256 deadline);

/**
 * @notice New currency does not match for a loan rollover request.
 *
 * @param oldCurrency                   The currency of the active loan.
 * @param newCurrency                   The currency of the new loan.
 */
error OC_RolloverCurrencyMismatch(address oldCurrency, address newCurrency);

/**
 * @notice New currency does not match for a loan rollover request.
 *
 * @param oldCollateralAddress          The address of the active loan's collateral.
 * @param newCollateralAddress          The token ID of the active loan's collateral.
 * @param oldCollateralId               The address of the new loan's collateral.
 * @param newCollateralId               The token ID of the new loan's collateral.
 */
error OC_RolloverCollateralMismatch(
    address oldCollateralAddress,
    uint256 oldCollateralId,
    address newCollateralAddress,
    uint256 newCollateralId
);

/**
 * @notice Provided payable currency address is not approved for lending.
 *
 * @param payableCurrency       ERC20 token address supplied in loan terms.
 */
error OC_InvalidCurrency(address payableCurrency);

/**
 * @notice Provided collateral address is not approved for lending.
 *
 * @param collateralAddress       ERC721 or ERC1155 token address supplied in loan terms.
 */
error OC_InvalidCollateral(address collateralAddress);

/**
 * @notice Provided token array does not hold any token addresses.
 */
error OC_ZeroArrayElements();

/**
 * @notice Provided token array holds more than 50 token addresses.
 */
error OC_ArrayTooManyElements();

// ==================================== ITEMS VERIFIER ======================================
/// @notice All errors prefixed with IV_, to separate from other contracts in the protocol.

/**
 * @notice Provided SignatureItem is missing an address.
 */
error IV_ItemMissingAddress();

/**
 * @notice Provided SignatureItem has an invalid collateral type.
 * @dev    Should never actually fire, since cType is defined by an enum, so will fail on decode.
 *
 * @param asset                        The NFT contract being checked.
 * @param cType                        The collateralTytpe provided.
 */
error IV_InvalidCollateralType(address asset, uint256 cType);

/**
 * @notice Provided signature item with no required amount. For single ERC721s, specify 1.
 *
 * @param asset                         The NFT contract being checked.
 * @param amount                        The amount provided (should be 0).
 */
error IV_NoAmount(address asset, uint256 amount);

/**
 * @notice Provided a wildcard for a non-ERC721.
 *
 * @param asset                         The NFT contract being checked.
 */
error IV_InvalidWildcard(address asset);

/**
 * @notice The provided token ID is out of bounds for the given collection.
 *
 * @param tokenId                       The token ID provided.
 */
error IV_InvalidTokenId(int256 tokenId);

/**
 * @notice The provided project ID does not exist on the target contract. Only
 *         used for ArtBlocks.
 *
 * @param projectId                     The project ID provided.
 * @param nextProjectId                 The contract's reported nextProjectId.
 */
error IV_InvalidProjectId(uint256 projectId, uint256 nextProjectId);

// ==================================== REPAYMENT CONTROLLER ======================================
/// @notice All errors prefixed with RC_, to separate from other contracts in the protocol.

/// @notice Zero address passed in where not allowed.
error RC_ZeroAddress();

/**
 * @notice Could not dereference loan from loan ID.
 *
 * @param target                     The loanId being checked.
 */
error RC_CannotDereference(uint256 target);

/**
 * @notice Ensure valid loan state for loan lifceycle operations.
 *
 * @param state                         Current state of a loan according to LoanState enum.
 */
error RC_InvalidState(LoanLibrary.LoanState state);

/**
 * @notice Caller is not the owner of lender note.
 *
 * @param lender                     The owner of the lender note.
 * @param caller                     Msg.sender of the function call.
 */
error RC_OnlyLender(address lender, address caller);

// ==================================== Loan Core ======================================
/// @notice All errors prefixed with LC_, to separate from other contracts in the protocol.

/// @notice Zero address passed in where not allowed.
error LC_ZeroAddress();

/// @notice Borrower address is same as lender address.
error LC_ReusedNote();

/// @notice Zero amount passed in where not allowed.
error LC_ZeroAmount();

/**
 * @notice Check collateral is not already used in a active loan.
 *
 * @param collateralAddress             Address of the collateral.
 * @param collateralId                  ID of the collateral token.
 */
error LC_CollateralInUse(address collateralAddress, uint256 collateralId);

/**
 * @notice The reported settlements are invalid, and LoanCore would lose tokens
 *         attempting to perform the requested operations.
 *
 *
 * @param payout                        Amount of tokens to be paid out.
 * @param collected                     Amount of tokens to collect - should be fewer than payout.
 */
error LC_CannotSettle(uint256 payout, uint256 collected);

/**
 * @notice User attempted to withdraw a pending balance that was in excess
 *         of what is available.
 *
 * @param amount                        Amount of tokens to be withdrawn.
 * @param available                     Amount of tokens available to withdraw.
 */
error LC_CannotWithdraw(uint256 amount, uint256 available);

/**
 * @notice Two arrays were provided that must be of matching length, but were not.
 *
 */
error LC_ArrayLengthMismatch();

/**
 * @notice A proposed affiliate split was submitted that is over the maximum.
 *
 * @param splitBps                     The proposed affiliate split.
 * @param maxSplitBps                  The maximum allowed affiliate split.
 *
 */
error LC_OverMaxSplit(uint96 splitBps, uint96 maxSplitBps);

/**
 * @notice Ensure valid loan state for loan lifceycle operations.
 *
 * @param state                         Current state of a loan according to LoanState enum.
 */
error LC_InvalidState(LoanLibrary.LoanState state);

/**
 * @notice Loan duration has not expired.
 *
 * @param dueDate                       Timestamp of the end of the loan duration.
 */
error LC_NotExpired(uint256 dueDate);

/**
 * @notice User address and the specified nonce have already been used.
 *
 * @param user                          Address of collateral owner.
 * @param nonce                         Represents the number of transactions sent by address.
 */
error LC_NonceUsed(address user, uint160 nonce);

/**
 * @notice Protocol attempted to set an affiliate code which already exists. Affiliate
 *         codes are immutable.
 *
 * @param affiliateCode                 The affiliate code being set.
 */
error LC_AffiliateCodeAlreadySet(bytes32 affiliateCode);

/**
 * @notice Specified note token ID does not have a redeemable receipt.
 *
 * @param loanId                     The loanId being checked.
 */
error LC_NoReceipt(uint256 loanId);

// ==================================== Promissory Note ======================================
/// @notice All errors prefixed with PN_, to separate from other contracts in the protocol.

/**
 * @notice Zero address provided as argument.
 */
error PN_ZeroAddress();

/**
 * @notice Caller of mint function must have the MINTER_ROLE in AccessControl.
 *
 * @param caller                        Address of the function caller.
 */
error PN_MintingRole(address caller);

/**
 * @notice Caller of burn function must have the BURNER_ROLE in AccessControl.
 *
 * @param caller                        Address of the function caller.
 */
error PN_BurningRole(address caller);

// ==================================== Fee Controller ======================================
/// @notice All errors prefixed with FC_, to separate from other contracts in the protocol.

/**
 * @notice Caller attempted to set a fee which is larger than the global maximum.
 */
error FC_FeeOverMax(bytes32 selector, uint256 fee, uint256 maxFee);

// ==================================== ERC721 Permit ======================================
/// @notice All errors prefixed with ERC721P_, to separate from other contracts in the protocol.

/**
 * @notice Deadline for the permit has expired.
 *
 * @param deadline                      Permit deadline parameter as a timestamp.
 */
error ERC721P_DeadlineExpired(uint256 deadline);

/**
 * @notice Address of the owner to also be the owner of the tokenId.
 *
 * @param owner                        Owner parameter for the function call.
 */
error ERC721P_NotTokenOwner(address owner);

/**
 * @notice Invalid signature.
 *
 * @param signer                        Signer recovered from ECDSA sugnature hash.
 */
error ERC721P_InvalidSignature(address signer);


