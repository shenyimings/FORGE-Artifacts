// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '../libraries/BespokeTypes.sol';

interface IOpenSkyBespokeMarket {
    event CancelAllOffers(address indexed sender, uint256 nonce);

    event CancelMultipleOffers(address indexed sender, uint256[] nonces);

    event TakeBorrowOffer(
        bytes32 offerHash,
        uint256 indexed loanId,
        address indexed lender,
        address indexed borrower,
        uint256 nonce
    );

    event TakeLendOffer(
        bytes32 offerHash,
        uint256 indexed loanId,
        address indexed lender,
        address indexed borrower,
        address onBehalfOf,
        uint256 nonce,
        uint256 nonceOrder
    );

    event Repay(uint256 indexed loanId, address indexed operator, address indexed receiver);

    event Foreclose(uint256 indexed loanId, address indexed operator, address indexed receiver);

    function takeBorrowOffer(
        BespokeTypes.Offer memory offerData,
        uint256 supplyAmount,
        uint256 supplyDuration,
        address lendAsset,
        bool autoConvertWhenRepay
    ) external returns (uint256);

    function takeLendOffer(
        BespokeTypes.Offer memory offerData,
        uint256 tokenId,
        uint256 borrowAmount,
        uint256 borrowDuration,
        address onBehalfOf,
        bytes memory params
    ) external returns (uint256);

    function repay(uint256 loanId) external;

    function foreclose(uint256 loanId) external;

    function cancelAllBorrowOffersForSender(uint256 minNonce_) external;

    function cancelMultipleBorrowOffers(uint256[] calldata offerNonces) external;

    function isValidNonce(address account, uint256 nonce) external view returns (bool);

    function getLoanData(uint256 loanId) external view returns (BespokeTypes.LoanData memory);

    function getStatus(uint256 loanId) external view returns (BespokeTypes.LoanStatus);

    function getBorrowInterest(uint256 loanId) external view returns (uint256);

    function getBorrowBalance(uint256 loanId) external view returns (uint256);

    function getPenalty(uint256 loanId) external view returns (uint256);
}
