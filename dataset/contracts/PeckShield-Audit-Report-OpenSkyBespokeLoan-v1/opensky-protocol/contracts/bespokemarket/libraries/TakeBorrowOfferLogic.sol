// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import '../interfaces/IOpenSkyBespokeSettings.sol';
import '../interfaces/ITransferAdapterCurrency.sol';
import '../interfaces/ITransferAdapterNFT.sol';

import './BespokeTypes.sol';
import './BespokeLogic.sol';

library TakeBorrowOfferLogic {
    using SafeERC20 for IERC20;

    event TakeBorrowOffer(
        bytes32 offerHash,
        uint256 indexed loanId,
        address indexed lender,
        address indexed borrower,
        uint256 nonce
    );

    struct TakeBorrowOfferLocalVars {
        bytes32 offerHash;
        bytes32 domainSeparator;
        address nftManager;
        address currencyTransferAdapter;
        uint256 loanId;
    }

    function executeTakeBorrowOffer(
        mapping(address => mapping(uint256 => BespokeTypes.NonceInfo)) storage _nonce,
        mapping(address => uint256) storage minNonce,
        mapping(uint256 => BespokeTypes.LoanData) storage _loans,
        BespokeTypes.Counter storage _loanIdTracker,
        BespokeTypes.Offer memory offerData,
        BespokeTypes.TakeBorrowInfo memory params,
        IOpenSkyBespokeSettings BESPOKE_SETTINGS
    ) public returns (uint256) {
        TakeBorrowOfferLocalVars memory vars;
        vars.offerHash = BespokeLogic.hashOffer(offerData);
        vars.domainSeparator = BespokeLogic.getDomainSeparator();

        require(offerData.offerType == BespokeTypes.OfferType.BORROW, 'BM_TAKE_BORROW_OFFER_INVALID_OFFER_TYPE');

        // For a borrower who created a borrow offer:
        // 1.No need to care what lender use to lend or what lender will get when loan repaid.
        // 2.So field 'autoConvertWhenRepay' and 'lendAsset' of offer data should be kept default value, and will be determined by lender/taker.
        require(
            offerData.autoConvertWhenRepay == false,
            'BM_TAKE_BORROW_OFFER_INVALID_FIELD_VALUE_AUTO_CONVERT_WHENR_EPAY'
        );
        require(offerData.lendAsset == address(0), 'BM_TAKE_BORROW_OFFER_INVALID_FIELD_VALUE_LEND_ASSET');

        // Borrower offer can only be used once by design
        require(offerData.nonceMaxTimes == 1, 'BM_TAKE_BORROW_OFFER_INVALID_FIELD_VALUE_NONCE_MAX_TIMES');
        
        require(offerData.strategy == address(0), 'BM_BORROW_OFFER_STRATEGY_SHOULD_BE_ZERO');


        // Comment validation
        BespokeLogic.validateOfferCommon(
            _nonce,
            minNonce,
            offerData,
            vars.offerHash,
            params.borrowAmount,
            params.borrowDuration,
            vars.domainSeparator,
            BESPOKE_SETTINGS
        );

        // Overwrite default value from lender/taker after common validation
        offerData.autoConvertWhenRepay = params.autoConvertWhenRepay;
        offerData.lendAsset = params.lendAsset;

        // prevents replay
        _nonce[offerData.signer][offerData.nonce].invalid = true;

        vars.nftManager = BESPOKE_SETTINGS.getNftTransferAdapter(offerData.tokenAddress);
        require(vars.nftManager != address(0), 'BM_TRANSFER_NFT_ADAPTER_NOT_AVAILABLE');
        ITransferAdapterNFT(vars.nftManager).transferCollateralIn(
            offerData.tokenAddress,
            offerData.signer,
            offerData.tokenId,
            offerData.tokenAmount
        );

        vars.currencyTransferAdapter = BESPOKE_SETTINGS.getCurrencyTransferAdapter(offerData.lendAsset);
        IERC20(offerData.lendAsset).safeTransferFrom(msg.sender, address(this), params.borrowAmount);
        IERC20(offerData.lendAsset).approve(vars.currencyTransferAdapter, params.borrowAmount);
        ITransferAdapterCurrency(vars.currencyTransferAdapter).transferOnLend(
            offerData.lendAsset,
            address(this),
            offerData.signer,
            params.borrowAmount,
            offerData
        );

        vars.loanId = BespokeLogic.mintLoanNFT(_loanIdTracker, offerData.signer, msg.sender, BESPOKE_SETTINGS);

        BespokeLogic.createLoan(
            _loans,
            offerData,
            vars.loanId,
            params.borrowAmount,
            params.borrowDuration,
            vars.nftManager,
            offerData.tokenId,
            BESPOKE_SETTINGS
        );

        emit TakeBorrowOffer(vars.offerHash, vars.loanId, msg.sender, offerData.signer, offerData.nonce);
        return vars.loanId;
    }
}
