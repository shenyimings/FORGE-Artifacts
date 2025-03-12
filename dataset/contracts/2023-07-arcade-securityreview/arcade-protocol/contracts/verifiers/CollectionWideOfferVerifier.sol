// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../interfaces/ISignatureVerifier.sol";
import "../interfaces/IVaultFactory.sol";

import {
    IV_NoAmount,
    IV_InvalidWildcard,
    IV_ItemMissingAddress,
    IV_InvalidCollateralType
} from "../errors/Lending.sol";

/**
 * @title CollectionWideOfferVerifier
 * @author Non-Fungible Technologies, Inc.
 *
 * This contract can be used for verifying a collection-wide offer for
 * an ERC721, and is agnostic in that it can verify both vaulted
 * and unbundled collateral. This is a common use case for many lenders,
 * who do not care whether the collateral is vauled.
 *
 * Predicates for this verify are _always_ wildcards: the caller's
 * predicate payload is a NFT address only, and the verifier will
 * check for _any_ balance of that asset.
 */
contract CollectionWideOfferVerifier is ISignatureVerifier {
    // ==================================== COLLATERAL VERIFICATION =====================================

    /**
     * @notice Verify that the items specified by the predicate calldata match the loan terms
     *         based on reported collateral address and ID, or that the collateral address
     *         is a vault factory and the vault contains the specified item.
     *
     * @param collateralAddress             The address of the loan's collateral.
     * @param collateralId                  The tokenId of the loan's collateral.
     * @param data                          The calldata needed for the verifier.
     *
     * @return verified                     Whether the bundle contains the specified items.
     */
    function verifyPredicates(
        address, address,
        address collateralAddress,
        uint256 collateralId,
        bytes calldata data
    ) external view override returns (bool) {
        // Unpack items
        (address token) = abi.decode(data, (address));

        // Unvaulted case - collateral will be escrowed directly
        if (collateralAddress == token) return true;

        // Do vault check
        address vaultAddress = address(uint160(collateralId));

        if (!IVaultFactory(collateralAddress).isInstance(vaultAddress)) return false;

        return IERC721(token).balanceOf(vaultAddress) > 0;
    }
}
