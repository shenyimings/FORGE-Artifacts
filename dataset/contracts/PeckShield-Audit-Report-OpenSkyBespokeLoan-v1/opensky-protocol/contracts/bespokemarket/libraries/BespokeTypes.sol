// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

library BespokeTypes {
    struct Offer {
        bool isProrated; // whether to pay interest a fixed-time when repay early
        bool autoConvertWhenRepay; // when currency!=lendAsset, whether to convert currency to lendAsset for lender when repay. Determained by lender.
        OfferType offerType;
        address tokenAddress;
        uint256 tokenId;
        uint256 tokenAmount; // 1 for ERC721, 1+ for ERC1155
        address signer; //borrower or lender
        uint256 borrowAmountMin;
        uint256 borrowAmountMax;
        uint40 borrowDurationMin;
        uint40 borrowDurationMax;
        uint128 borrowRate;
        address currency;  // Asset received by borrower when loan created. Borrower should also use it for repay.
        address lendAsset; // Using which oToken to lend. Determained by lender and should be zero address for a borrow offer.
        uint256 nonce;
        uint256 nonceMaxTimes;// should be 1 for a borrow offer
        uint256 deadline;
        address strategy; // used for lend offer. should be zero address for borrow offer
        bytes params;
        uint8 v; // v: parameter (27 or 28)
        bytes32 r; // r: parameter
        bytes32 s; // s: parameter
    }

    struct LoanData {
        address tokenAddress;
        uint256 tokenId;
        uint256 tokenAmount; // 1 for ERC721, 1+ for ERC1155
        address nftManager;
        address borrower;
        address lender;
        uint256 amount;
        uint128 borrowRate;
        uint128 interestPerSecond;
        address currency;
        address lendAsset;
        uint256 reserveFactor;
        uint256 overdueLoanFeeFactor;
        uint40 borrowDuration;
        uint40 borrowBegin;
        uint40 borrowOverdueTime;
        uint40 liquidatableTime;
        bool isProrated;
        bool autoConvertWhenRepay;
        LoanStatus status;
    }

    enum OfferType {
        BORROW, // borrow offer
        LEND // lend offer
    }

    struct TakeBorrowInfo {
        uint256 borrowAmount;
        uint256 borrowDuration;
        address lendAsset;
        bool autoConvertWhenRepay;
    }

    struct TakeLendInfo {
        uint256 borrowAmount;
        uint256 borrowDuration;
        uint256 tokenId;
        address onBehalfOf;
        bytes params;
    }

    // params for lend strategy
    struct TakeLendInfoForStrategy {
        address taker;
        uint256 tokenId;
        bytes params;
    }

    enum LoanStatus {
        NONE,
        BORROWING,
        OVERDUE,
        LIQUIDATABLE
    }

    struct WhitelistInfo {
        bool enabled;
        uint256 minBorrowDuration;
        uint256 maxBorrowDuration;
        uint256 overdueDuration;
    }

    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    struct NonceInfo {
        bool invalid;
        uint256 usedTimes;
        bytes32 offerHash;
    }
}
