// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {WadRayMath} from "@morpho-utils/math/WadRayMath.sol";
import {PercentageMath} from "@morpho-utils/math/PercentageMath.sol";

/// @title Constants
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Library exposing constants used in Morpho.
library Constants {
    /// @dev The referral code used for Aave.
    uint8 internal constant NO_REFERRAL_CODE = 0;

    /// @dev The variable interest rate mode of Aave.
    uint8 internal constant VARIABLE_INTEREST_MODE = 2;

    /// @dev The threshold under which the balance is swept to 0.
    uint256 internal constant DUST_THRESHOLD = 1;

    /// @dev A lower bound on the liquidation threshold values of all the listed assets.
    uint256 internal constant LT_LOWER_BOUND = 10_00;

    /// @dev The maximum close factor used during liquidations (100%).
    uint256 internal constant MAX_CLOSE_FACTOR = PercentageMath.PERCENTAGE_FACTOR;

    /// @dev The default close factor used during liquidations (50%).
    uint256 internal constant DEFAULT_CLOSE_FACTOR = PercentageMath.HALF_PERCENTAGE_FACTOR;

    /// @dev Health factor below which the positions can be liquidated.
    uint256 internal constant DEFAULT_LIQUIDATION_MAX_HF = WadRayMath.WAD;

    /// @dev Health factor below which the positions can be liquidated, whether or not the price oracle sentinel allows the liquidation.
    uint256 internal constant DEFAULT_LIQUIDATION_MIN_HF = 0.95e18;

    /// @dev The prefix used for EIP-712 signature.
    string internal constant EIP712_MSG_PREFIX = "\x19\x01";

    /// @dev The name used for EIP-712 signature.
    string internal constant EIP712_NAME = "Morpho-AaveV3";

    /// @dev The version used for EIP-712 signature.
    string internal constant EIP712_VERSION = "0";

    /// @dev The domain typehash used for the EIP-712 signature.
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /// @dev The typehash for approveManagerWithSig Authorization used for the EIP-712 signature.
    bytes32 internal constant EIP712_AUTHORIZATION_TYPEHASH =
        keccak256("Authorization(address delegator,address manager,bool isAllowed,uint256 nonce,uint256 deadline)");

    /// @dev The highest valid value for s in an ECDSA signature pair (0 < s < secp256k1n รท 2 + 1).
    uint256 internal constant MAX_VALID_ECDSA_S = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;
}
