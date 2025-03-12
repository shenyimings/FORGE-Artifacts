// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/ISignatureVerifier.sol";
import "../interfaces/IVaultFactory.sol";

import {
    IV_NoAmount,
    IV_InvalidWildcard,
    IV_ItemMissingAddress,
    IV_InvalidCollateralType
} from "../errors/Lending.sol";

/**
 * @title ArcadeItemsVerifier
 * @author Non-Fungible Technologies, Inc.
 *
 * This contract can be used for verifying complex signature-encoded
 * bundle descriptions. This resolves on a new array of SignatureItems[],
 * which outside of verification, is passed around as bytes memory.
 *
 * Each SignatureItem has the following fields:
 *      - cType (collateral Type)
 *      - asset (contract address of the asset)
 *      - tokenId (token ID of the asset, if applicable)
 *      - amount (amount of the asset, if applicable - if ERC721, set to "1")
 *      - anyIdAllowed (whether a wildcard is supported - see below)
 *
 * - For token ids part of ERC721, other features beyond direct tokenIds are supported:
 *      - If anyIdAllowed is true, then any token ID can be passed - the field will be ignored.
 *      - If anyIdAllowed is true, then the "amount" field can be read to require
 *          a specific amount of assets from the collection.
 *      - Wildcard token ids are not supported for ERC1155 or ERC20.
 * - All amounts are taken as minimums. For instance, if the "amount" field of an ERC1155 is 5,
 *      then a bundle with 8 of those ERC1155s are accepted.
 * - For an ERC20 cType, tokenId is ignored. For an ERC721 cType, amount is ignored unless wildcard (see above).
        If a wildcard is used, 0 amount is invalid, and all nonzero amounts are ignored.
 *
 * - Any deviation from the above rules represents an unparseable signature and will always
 *      return invalid.
 *
 * - All multi-item signatures assume AND - any optional expressed by OR
 *      can be implemented by simply signing multiple separate signatures.
 */
contract ArcadeItemsVerifier is ISignatureVerifier {
    /// @dev Enum describing the collateral type of a signature item
    enum CollateralType {
        ERC_721,
        ERC_1155,
        ERC_20
    }

    /// @dev Enum describing each item that should be validated
    struct SignatureItem {
        // The type of collateral - which interface does it implement
        CollateralType cType;
        // The address of the collateral contract
        address asset;
        // The token ID of the collateral (only applicable to 721 and 1155).
        uint256 tokenId;
        // The minimum amount of collateral. For ERC721 assets, pass 1 or the
        // amount of assets needed to be held for a wildcard predicate. If the
        // tokenId is specified, the amount is assumed to be 1.
        uint256 amount;
        // Whether any token ID should be allowed. Only applies to ERC721.
        // Supersedes tokenId.
        bool anyIdAllowed;
    }

    // ==================================== COLLATERAL VERIFICATION =====================================

    /**
     * @notice Verify that the items specified by the packed SignatureItem array are held by the vault.
     * @dev    Reverts on a malformed SignatureItem, returns false on missing contents.
     *
     *         Verification for empty predicates array has been addressed in initializeLoanWithItems and
     *         rolloverLoanWithItems.
     *
     * @param collateralAddress             The address of the loan's collateral.
     * @param collateralId                  The tokenId of the loan's collateral.
     * @param predicates                    The calldata needed for the verifier.
     *
     * @return verified                     Whether the bundle contains the specified items.
     */
    // solhint-disable-next-line code-complexity
    function verifyPredicates(
        address, address,
        address collateralAddress,
        uint256 collateralId,
        bytes calldata predicates
    ) external view override returns (bool) {
        address vault = IVaultFactory(collateralAddress).instanceAt(collateralId);

        // Unpack items
        SignatureItem[] memory items = abi.decode(predicates, (SignatureItem[]));

        for (uint256 i = 0; i < items.length; i++) {
            SignatureItem memory item = items[i];

            // No asset provided
            if (item.asset == address(0)) revert IV_ItemMissingAddress();

            // No amount provided
            if (item.amount == 0) revert IV_NoAmount(item.asset, item.amount);


            if (item.cType == CollateralType.ERC_721) {
                IERC721 asset = IERC721(item.asset);
                uint256 id = item.tokenId;

                // Wildcard, but vault has no assets or not enough specified
                if (item.anyIdAllowed && asset.balanceOf(vault) < item.amount) return false;
                // Does not own specifically specified asset
                if (!item.anyIdAllowed && asset.ownerOf(id) != vault) return false;
            } else if (item.cType == CollateralType.ERC_1155) {
                IERC1155 asset = IERC1155(item.asset);

                // Wildcard not allowed, since we can't check overall 1155 balances
                if (item.anyIdAllowed) revert IV_InvalidWildcard(item.asset);

                // Does not own specifically specified asset
                if (asset.balanceOf(vault, item.tokenId) < item.amount) return false;
            } else if (item.cType == CollateralType.ERC_20) {
                IERC20 asset = IERC20(item.asset);

                // Wildcard not allowed, since nonsensical
                if (item.anyIdAllowed) revert IV_InvalidWildcard(item.asset);

                // Does not own specifically specified asset
                if (asset.balanceOf(vault) < item.amount) return false;
            } else {
                // Interface could not be parsed - fail
                revert IV_InvalidCollateralType(item.asset, uint256(item.cType));
            }
        }

        // Loop completed - all items found
        return true;
    }
}
