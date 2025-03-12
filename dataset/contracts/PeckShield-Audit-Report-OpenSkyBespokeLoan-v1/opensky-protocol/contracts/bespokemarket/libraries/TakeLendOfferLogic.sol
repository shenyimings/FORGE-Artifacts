// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import '../interfaces/IOpenSkyBespokeSettings.sol';
import '../interfaces/IOpenSkyBespokeLendOfferStrategy.sol';
import '../interfaces/ITransferAdapterCurrency.sol';
import '../interfaces/ITransferAdapterNFT.sol';

import './BespokeLogic.sol';
import './BespokeTypes.sol';

library TakeLendOfferLogic {
    using SafeERC20 for IERC20;

    event TakeLendOffer(
        bytes32 offerHash,
        uint256 indexed loanId,
        address indexed lender,
        address indexed borrower,
        address onBehalfOf,
        uint256 nonce,
        uint256 nonceOrder
    );

    struct TakeLendOfferLocalVars {
        bytes32 offerHash;
        bytes32 domainSeparator;
        address nftManager;
        address currencyTransferAdapter;
        uint256 loanId;
    }

    function executeTakeLendOffer(
        mapping(address => mapping(uint256 => BespokeTypes.NonceInfo)) storage _nonce,
        mapping(address => uint256) storage minNonce,
        mapping(uint256 => BespokeTypes.LoanData) storage _loans,
        BespokeTypes.Counter storage _loanIdTracker,
        BespokeTypes.Offer memory offerData,
        BespokeTypes.TakeLendInfo memory params,
        IOpenSkyBespokeSettings BESPOKE_SETTINGS
    ) public returns (uint256) {
        TakeLendOfferLocalVars memory vars;

        vars.offerHash = BespokeLogic.hashOffer(offerData);
        vars.domainSeparator = BespokeLogic.getDomainSeparator();

        require(offerData.offerType == BespokeTypes.OfferType.LEND, 'BM_TAKE_OFFER_INVALID_OFFER_TYPE');

        // comment validation
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

        //validate strategy
        require(offerData.strategy != address(0), 'BM_TAKE_LEND_STRATEGY_EMPTY');

        require(BESPOKE_SETTINGS.isStrategyWhitelisted(offerData.strategy), 'BM_TAKE_LEND_STRATEGY_NOT_IN_WHITE_LIST');

        IOpenSkyBespokeLendOfferStrategy(offerData.strategy).validate(
            offerData,
            BespokeTypes.TakeLendInfoForStrategy({taker: msg.sender, tokenId: params.tokenId, params: params.params})
        );

        // update nonce
        _nonce[offerData.signer][offerData.nonce].usedTimes++;
        if (_nonce[offerData.signer][offerData.nonce].offerHash == 0) {
            _nonce[offerData.signer][offerData.nonce].offerHash = vars.offerHash;
        }
        if (_nonce[offerData.signer][offerData.nonce].usedTimes >= offerData.nonceMaxTimes) {
            _nonce[offerData.signer][offerData.nonce].invalid = true;
        }
        vars.nftManager = BESPOKE_SETTINGS.getNftTransferAdapter(offerData.tokenAddress);

        require(vars.nftManager != address(0), 'BM_TRANSFER_NFT_ADAPTER_NOT_AVAILABLE');
        ITransferAdapterNFT(vars.nftManager).transferCollateralIn(
            offerData.tokenAddress,
            msg.sender,
            params.tokenId,
            offerData.tokenAmount
        );

        vars.currencyTransferAdapter = BESPOKE_SETTINGS.getCurrencyTransferAdapter(offerData.lendAsset);
        IERC20(offerData.lendAsset).safeTransferFrom(offerData.signer, address(this), params.borrowAmount);
        IERC20(offerData.lendAsset).approve(vars.currencyTransferAdapter, params.borrowAmount);

        ITransferAdapterCurrency(vars.currencyTransferAdapter).transferOnLend(
            offerData.lendAsset,
            address(this),
            params.onBehalfOf,
            params.borrowAmount,
            offerData
        );

        // mint loanNft
        vars.loanId = BespokeLogic.mintLoanNFT(_loanIdTracker, params.onBehalfOf, offerData.signer, BESPOKE_SETTINGS);
        // create loan
        BespokeLogic.createLoan(
            _loans,
            offerData,
            vars.loanId,
            params.borrowAmount,
            params.borrowDuration,
            vars.nftManager,
            params.tokenId,
            BESPOKE_SETTINGS
        );

        emit TakeLendOffer(
            vars.offerHash,
            vars.loanId,
            offerData.signer,
            msg.sender,
            params.onBehalfOf,
            offerData.nonce,
            _nonce[offerData.signer][offerData.nonce].usedTimes
        );
        return vars.loanId;
    }
}
