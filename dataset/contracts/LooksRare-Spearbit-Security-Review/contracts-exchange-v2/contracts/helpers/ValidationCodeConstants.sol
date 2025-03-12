// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// 0. No error
uint256 constant ORDER_EXPECTED_TO_BE_VALID = 0;

// 1. Strategy & currency-related errors
uint256 constant CURRENCY_NOT_WHITELISTED = 101;
uint256 constant STRATEGY_NOT_IMPLEMENTED = 111;
uint256 constant STRATEGY_TAKER_BID_SELECTOR_INVALID = 112;
uint256 constant STRATEGY_TAKER_ASK_SELECTOR_INVALID = 113;
uint256 constant STRATEGY_NOT_ACTIVE = 114;

// 2. Maker order struct-related errors
uint256 constant MAKER_ORDER_INVALID_STANDARD_SALE = 201;
uint256 constant MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE = 211; // The order cannot become valid again
uint256 constant MAKER_ORDER_WRONG_CURRENCY_NON_STANDARD_SALE = 212; // The order cannot become valid again due to wrong currency
uint256 constant MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE = 213; // The order can potentially become valid again

// 3. Nonce-related errors
uint256 constant USER_SUBSET_NONCE_CANCELLED = 301;
uint256 constant USER_ORDER_NONCE_EXECUTED_OR_CANCELLED = 311;
uint256 constant USER_ORDER_NONCE_IN_EXECUTION_WITH_OTHER_HASH = 312;
uint256 constant USER_GLOBAL_BID_NONCE_HIGHER = 321;
uint256 constant USER_GLOBAL_BID_NONCE_LOWER = 322;
uint256 constant USER_GLOBAL_ASK_NONCE_HIGHER = 323;
uint256 constant USER_GLOBAL_ASK_NONCE_LOWER = 324;

// 4. Errors related to signatures (EOA, EIP-1271) and Merkle Tree computations
uint256 constant ORDER_HASH_PROOF_NOT_IN_MERKLE_TREE = 401;
uint256 constant WRONG_SIGNATURE_LENGTH = 411;
uint256 constant INVALID_S_PARAMETER_EOA = 412;
uint256 constant INVALID_V_PARAMETER_EOA = 413;
uint256 constant NULL_SIGNER_EOA = 414;
uint256 constant WRONG_SIGNER_EOA = 415;
uint256 constant MISSING_IS_VALID_SIGNATURE_FUNCTION_EIP1271 = 421;
uint256 constant SIGNATURE_INVALID_EIP1271 = 422;

// 5. Timestamp-related validation errors
uint256 constant START_TIME_GREATER_THAN_END_TIME = 501;
uint256 constant TOO_LATE_TO_EXECUTE_ORDER = 502;
uint256 constant TOO_EARLY_TO_EXECUTE_ORDER = 503;

// 6. Transfer-related (ERC20, ERC721, ERC1155 tokens), including transfers and approvals, errors
uint256 constant SAME_ITEM_ID_IN_BUNDLE = 601;
uint256 constant ERC20_BALANCE_INFERIOR_TO_PRICE = 611;
uint256 constant ERC20_APPROVAL_INFERIOR_TO_PRICE = 612;
uint256 constant ERC721_ITEM_ID_DOES_NOT_EXIST = 621;
uint256 constant ERC721_ITEM_ID_NOT_IN_BALANCE = 622;
uint256 constant ERC721_NO_APPROVAL_FOR_ALL_OR_ITEM_ID = 623;
uint256 constant ERC1155_BALANCE_OF_DOES_NOT_EXIST = 631;
uint256 constant ERC1155_BALANCE_OF_ITEM_ID_INFERIOR_TO_AMOUNT = 632;
uint256 constant ERC1155_IS_APPROVED_FOR_ALL_DOES_NOT_EXIST = 633;
uint256 constant ERC1155_NO_APPROVAL_FOR_ALL = 634;

// 7. Asset-type suggestion
uint256 constant POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC721 = 701;
uint256 constant POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC1155 = 702;
uint256 constant ASSET_TYPE_NOT_SUPPORTED = 711;

// 8. Transfer manager-related
uint256 constant NO_TRANSFER_MANAGER_APPROVAL_BY_USER_FOR_EXCHANGE = 801;
uint256 constant TRANSFER_MANAGER_APPROVAL_REVOKED_BY_OWNER_FOR_EXCHANGE = 802;

// 9. Creator fee-related errors
uint256 constant BUNDLE_ERC2981_NOT_SUPPORTED = 901;
uint256 constant CREATOR_FEE_TOO_HIGH = 902;
