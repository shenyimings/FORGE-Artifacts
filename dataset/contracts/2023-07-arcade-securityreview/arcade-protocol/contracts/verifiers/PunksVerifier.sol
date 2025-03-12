// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../interfaces/ISignatureVerifier.sol";
import "../interfaces/IVaultFactory.sol";
import "../external/interfaces/IPunks.sol";

import { IV_InvalidTokenId } from "../errors/Lending.sol";

/**
 * @title PunksVerifier
 * @author Non-Fungible Technologies, Inc.
 *
 * See ItemsVerifier for a more thorough description of the Verifier
 * pattern used in Arcade.xyz's lending protocol. This contract
 * verifies predicates that check ownership of a certain CryptoPunk
 * by an asset vault.
 */
contract PunksVerifier is ISignatureVerifier {
    using SafeCast for int256;

    // ============================================ STATE ==============================================

    // =============== Contract References ===============

    IPunks public immutable punks;

    // ========================================== CONSTRUCTOR ===========================================

    /**
     * @notice Construct a new PunksVerifier contract.
     *
     * @param _punks                        The address of the CryptoPunks contract.
     */
    constructor(address _punks) {
        punks = IPunks(_punks);
    }

    // ==================================== COLLATERAL VERIFICATION =====================================

    /**
     * @notice Verify that the items specified by the packed int256 array are held by the vault.
     * @dev    Reverts on out of bounds token Ids, returns false on missing contents.
     *
     *         Verification for empty predicates array has been addressed in initializeLoanWithItems and
     *         rolloverLoanWithItems.
     *
     * @param collateralAddress             The address of the loan's collateral.
     * @param collateralId                  The tokenId of the loan's collateral.
     * @param predicates                    The int256[] array of punk IDs to check for, packed in bytes.
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
        int256[] memory tokenIds = abi.decode(predicates, (int256[]));

        for (uint256 i = 0; i < tokenIds.length; i++) {
            int256 tokenId = tokenIds[i];

            if (tokenId > 9999) revert IV_InvalidTokenId(tokenId);

            if (tokenId < 0 && punks.balanceOf(vault) == 0) return false;
            // Does not own specifically specified asset
            else if (tokenId >= 0 && punks.punkIndexToAddress(tokenId.toUint256()) != vault) return false;
        }

        // Loop completed - all items found
        return true;
    }
}