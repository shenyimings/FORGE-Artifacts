// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import '../../libraries/math/MathUtils.sol';
import '../../libraries/math/WadRayMath.sol';
import '../../libraries/math/PercentageMath.sol';

import '../interfaces/IOpenSkyBespokeSettings.sol';
import '../interfaces/IOpenSkyBespokeLoanNFT.sol';
import './BespokeTypes.sol';
import './SignatureChecker.sol';

library BespokeLogic {
    using PercentageMath for uint256;
    using WadRayMath for uint256;

    // keccak256("Offer(bool isProrated,bool autoConvertWhenRepay,uint8 offerType,address tokenAddress,uint256 tokenId,uint256 tokenAmount,address signer,uint256 borrowAmountMin,uint256 borrowAmountMax,uint40 borrowDurationMin,uint40 borrowDurationMax,uint128 borrowRate,address currency,address lendAsset,uint256 nonce,uint256 nonceMaxTimes,uint256 deadline,address strategy,bytes params)")
    bytes32 internal constant OFFER_HASH = 0x5898afb02f4982fe09fa9b4daac8eb8efd917a7c9412c0671717c798ae97aa99;

    function hashOffer(BespokeTypes.Offer memory offerData) public pure returns (bytes32) {
        return
            keccak256(
                bytes.concat(
                    abi.encode(
                        OFFER_HASH,
                        offerData.isProrated,
                        offerData.autoConvertWhenRepay,
                        offerData.offerType,
                        offerData.tokenAddress,
                        offerData.tokenId,
                        offerData.tokenAmount,
                        offerData.signer,
                        offerData.borrowAmountMin,
                        offerData.borrowAmountMax,
                        offerData.borrowDurationMin,
                        offerData.borrowDurationMax,
                        offerData.borrowRate
                    ),
                    abi.encode(
                        offerData.currency,
                        offerData.lendAsset,
                        offerData.nonce,
                        offerData.nonceMaxTimes,
                        offerData.deadline,
                        offerData.strategy,
                        keccak256(offerData.params)
                    )
                )
            );
    }

    function getDomainSeparator() public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f, // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
                    0xf0cf7ce475272740cae17eb3cadd6d254800be81c53f84a2f273b99036471c62, // keccak256("OpenSkyBespokeMarket")
                    0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6, // keccak256(bytes("1")) for versionId = 1
                    block.chainid,
                    address(this)
                )
            );
    }

    function validateOfferCommon(
        mapping(address => mapping(uint256 => BespokeTypes.NonceInfo)) storage _nonce,
        mapping(address => uint256) storage minNonce,
        BespokeTypes.Offer memory offerData,
        bytes32 offerHash,
        uint256 amount,
        uint256 duration,
        bytes32 DOMAIN_SEPARATOR,
        IOpenSkyBespokeSettings BESPOKE_SETTINGS //,
    ) public view {
        // check nonce
        require(
            !_nonce[offerData.signer][offerData.nonce].invalid && offerData.nonce >= minNonce[offerData.signer],
            'BM_TAKE_OFFER_NONCE_INVALID'
        );
        require(offerData.nonceMaxTimes >= 1, 'BM_TAKE_OFFER_NONCE_MAX_TIMES_INVALIDE');

        require(
            _nonce[offerData.signer][offerData.nonce].usedTimes < offerData.nonceMaxTimes,
            'BM_TAKE_OFFER_NONCE_EXHAUST'
        );

        if (_nonce[offerData.signer][offerData.nonce].offerHash != 0) {
            require(
                _nonce[offerData.signer][offerData.nonce].offerHash == offerHash,
                'BM_TAKE_OFFER_NONCE_USED_BY_OTHER_OFFER'
            );
        }

        require(BESPOKE_SETTINGS.isCurrencyWhitelisted(offerData.currency), 'BM_TAKE_BORROW_CURRENCY_NOT_IN_WHITELIST');

        require(
            !BESPOKE_SETTINGS.isWhitelistOn() || BESPOKE_SETTINGS.inWhitelist(offerData.tokenAddress),
            'BM_TAKE_BORROW_NFT_NOT_IN_WHITELIST'
        );

        require(block.timestamp <= offerData.deadline, 'BM_TAKE_BORROW_SIGNING_EXPIRATION');

        (uint256 minBorrowDuration, uint256 maxBorrowDuration, ) = BESPOKE_SETTINGS.getBorrowDurationConfig(
            offerData.tokenAddress
        );

        // check borrow duration
        require(
            offerData.borrowDurationMin <= offerData.borrowDurationMax &&
                offerData.borrowDurationMin >= minBorrowDuration &&
                offerData.borrowDurationMax <= maxBorrowDuration,
            'BM_TAKE_BORROW_OFFER_DURATION_NOT_ALLOWED'
        );

        require(
            duration > 0 && duration >= offerData.borrowDurationMin && duration <= offerData.borrowDurationMax,
            'BM_TAKE_BORROW_TAKER_DURATION_NOT_ALLOWED'
        );

        // check borrow amount
        require(
            offerData.borrowAmountMin > 0 && offerData.borrowAmountMin <= offerData.borrowAmountMax,
            'BM_TAKE_BORROW_OFFER_AMOUNT_NOT_ALLOWED'
        );

        require(
            amount >= offerData.borrowAmountMin && amount <= offerData.borrowAmountMax,
            'BM_TAKE_BORROW_SUPPLY_AMOUNT_NOT_ALLOWED'
        );
        require(
            SignatureChecker.verify(
                offerHash,
                offerData.signer,
                offerData.v,
                offerData.r,
                offerData.s,
                DOMAIN_SEPARATOR
            ),
            'BM_TAKE_BORROW_SIGNATURE_INVALID'
        );
    }

    function createLoan(
        mapping(uint256 => BespokeTypes.LoanData) storage _loans,
        BespokeTypes.Offer memory offerData,
        uint256 loanId,
        uint256 supplyAmount,
        uint256 supplyDuration,
        address nftManager,
        uint256 tokenId,
        IOpenSkyBespokeSettings BESPOKE_SETTINGS
    ) public {
        uint256 borrowRateRay = uint256(offerData.borrowRate).rayDiv(10000);
        (, , uint256 overdueDuration) = BESPOKE_SETTINGS.getBorrowDurationConfig(offerData.tokenAddress);

        BespokeTypes.LoanData memory loan = BespokeTypes.LoanData({
            tokenAddress: offerData.tokenAddress,
            tokenId: tokenId,
            tokenAmount: offerData.tokenAmount,
            nftManager: nftManager,
            borrower: offerData.offerType == BespokeTypes.OfferType.BORROW ? offerData.signer : msg.sender,
            lender: offerData.offerType == BespokeTypes.OfferType.BORROW ? msg.sender : offerData.signer,
            amount: supplyAmount,
            borrowRate: uint128(borrowRateRay),
            interestPerSecond: uint128(MathUtils.calculateBorrowInterestPerSecond(borrowRateRay, supplyAmount)),
            currency: offerData.currency,
            lendAsset: offerData.lendAsset,
            reserveFactor: BESPOKE_SETTINGS.reserveFactor(),
            overdueLoanFeeFactor: BESPOKE_SETTINGS.overdueLoanFeeFactor(),
            borrowDuration: uint40(supplyDuration),
            borrowBegin: uint40(block.timestamp),
            borrowOverdueTime: uint40(block.timestamp + supplyDuration),
            liquidatableTime: uint40(block.timestamp + supplyDuration + overdueDuration),
            isProrated: offerData.isProrated,
            autoConvertWhenRepay: offerData.autoConvertWhenRepay,
            status: BespokeTypes.LoanStatus.BORROWING
        });

        _loans[loanId] = loan;
    }

    function getLoanStatus(BespokeTypes.LoanData memory loan) public view returns (BespokeTypes.LoanStatus) {
        BespokeTypes.LoanStatus status = loan.status;
        if (status == BespokeTypes.LoanStatus.BORROWING) {
            if (loan.liquidatableTime < block.timestamp) {
                status = BespokeTypes.LoanStatus.LIQUIDATABLE;
            } else if (loan.borrowOverdueTime < block.timestamp) {
                status = BespokeTypes.LoanStatus.OVERDUE;
            }
        }
        return status;
    }

    function getLoanDataWithStatus(BespokeTypes.LoanData memory loan)
        public
        view
        returns (BespokeTypes.LoanData memory)
    {
        loan.status = getLoanStatus(loan);
        return loan;
    }

    function getLoanParties(IOpenSkyBespokeSettings BESPOKE_SETTINGS, uint256 loanId)
        public
        view
        returns (address borrower, address lender)
    {
        lender = IERC721(BESPOKE_SETTINGS.lendLoanAddress()).ownerOf(loanId);
        borrower = IERC721(BESPOKE_SETTINGS.borrowLoanAddress()).ownerOf(loanId);
    }

    function getBorrowInterest(BespokeTypes.LoanData memory loan) public view returns (uint256) {
        uint256 endTime = block.timestamp < loan.borrowOverdueTime
            ? (loan.isProrated ? block.timestamp : loan.borrowOverdueTime)
            : loan.borrowOverdueTime;
        return uint256(loan.interestPerSecond).rayMul(endTime -loan.borrowBegin);
    }

    // @dev principal + interest
    function getBorrowBalance(BespokeTypes.LoanData memory loan) public view returns (uint256) {
        return loan.amount + getBorrowInterest(loan);
    }

    function getPenalty(BespokeTypes.LoanData memory loan) public view returns (uint256) {
        BespokeTypes.LoanData memory loan = getLoanDataWithStatus(loan);
        uint256 penalty = 0;
        if (loan.status == BespokeTypes.LoanStatus.OVERDUE) {
            penalty = loan.amount.percentMul(loan.overdueLoanFeeFactor);
        }
        return penalty;
    }

    function calculateRepayAmountAndProtocolFee(BespokeTypes.LoanData memory loan)
        public
        view
        returns (
            uint256 total,
            uint256 lenderAmount,
            uint256 protocolFee
        )
    {
        uint256 penalty = getPenalty(loan);
        total = getBorrowBalance(loan) + penalty;
        protocolFee = (getBorrowInterest(loan) + penalty).percentMul(loan.reserveFactor);
        lenderAmount = total - protocolFee;
    }

    function burnLoanNft(
        mapping(uint256 => BespokeTypes.LoanData) storage _loans,
        uint256 tokenId,
        IOpenSkyBespokeSettings BESPOKE_SETTINGS
    ) public {
        IOpenSkyBespokeLoanNFT(BESPOKE_SETTINGS.borrowLoanAddress()).burn(tokenId);
        IOpenSkyBespokeLoanNFT(BESPOKE_SETTINGS.lendLoanAddress()).burn(tokenId);
        delete _loans[tokenId];
    }

    function mintLoanNFT(
        BespokeTypes.Counter storage _loanIdTracker,
        address borrower,
        address lender,
        IOpenSkyBespokeSettings BESPOKE_SETTINGS
    ) internal returns (uint256) {
        _loanIdTracker._value = _loanIdTracker._value + 1;
        uint256 tokenId = _loanIdTracker._value;

        IOpenSkyBespokeLoanNFT(BESPOKE_SETTINGS.borrowLoanAddress()).mint(tokenId, borrower);
        IOpenSkyBespokeLoanNFT(BESPOKE_SETTINGS.lendLoanAddress()).mint(tokenId, lender);

        return tokenId;
    }
}
