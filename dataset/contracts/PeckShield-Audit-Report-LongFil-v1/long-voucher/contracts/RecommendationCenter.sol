// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./ILongVoucher.sol";
import "./IProductCenter.sol";
import "./IRecommendation.sol";
import "./IRecommendationCenter.sol";
import "./IVoucherProvider.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

contract RecommendationCenter is
    Ownable2StepUpgradeable,
    IRecommendationCenter,
    IVoucherProvider,
    IERC165Upgradeable
{
    uint256 private constant MANTISSA_ONE = 1e18;

    uint256 public constant EARNINGS_VOUCHER_SLOT_ID = 23;

    struct ReferredProduct {
        address productCenter; 
        uint256 productId;
        uint256 totalEquities;
        uint256 settledInterest;
        uint256[10] __gap;
    }

    struct ReferrerData {
        uint256 distributedEarnings;
        ReferredProduct[] allReferredProducts;
        mapping(uint256 => uint256) allReferredProductsIndex;
        uint256[10] __gap;
    }

    /// storage

    ILongVoucher public longVoucher;
    IRecommendation public recommendation;
    uint256 public referrerEarningsRatio;

    // referrer => referrer data
    mapping(address => ReferrerData) private _referrerDataMapping;

    // voucher id => tracking flag
    mapping(uint256 => bool) private _voucherTrackingFlag;


    /// events

    event Settlement(address indexed referrer, uint256 productId, uint256 settledInterest);
    event Claimed(address indexed referrer, address receiver, uint256 earnings, uint256 voucherId);

    /**
     * initialize method, called by proxy
     */
    function initialize(
        address longVoucher_,
        address recommendation_,
        uint256 defaultReferrerEarningsRatio_,
        address initialOwner_
    ) public initializer {
        require(longVoucher_ != address(0), "zero address");
        require(recommendation_ != address(0), "zero address");
        require(defaultReferrerEarningsRatio_ <= MANTISSA_ONE, "illegal ratio of referrer earnings");
        require(initialOwner_ != address(0), "zero address");

        // call super initialize methods
        Ownable2StepUpgradeable.__Ownable2Step_init();

        // set storage values
        longVoucher = ILongVoucher(longVoucher_);
        recommendation = IRecommendation(recommendation_);
        referrerEarningsRatio = defaultReferrerEarningsRatio_;

        // initialize owner
        _transferOwnership(initialOwner_);

        // take up EARNINGS_SLOT_ID by mint new token
        longVoucher.mint(address(this), EARNINGS_VOUCHER_SLOT_ID, 0);
    }

    // ERC165
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return interfaceId == type(IRecommendationCenter).interfaceId || interfaceId == type(IVoucherProvider).interfaceId;
    }

    ///

    function isVoucherTracked(uint256 voucherId) external view returns (bool) {
        return _voucherTrackingFlag[voucherId];
    }

    function referredProductCount(address referrer) public view returns (uint256) {
        return _referrerDataMapping[referrer].allReferredProducts.length;
    }

    function referredProductIdByIndex(address referrer, uint256 index) external view returns (uint256) {
        require(index < referredProductCount(referrer), "index exceeds");
        return _referrerDataMapping[referrer].allReferredProducts[index].productId;
    }

    function getDistributedEarnings(address referrer) external view returns (uint256) {
        return _referrerDataMapping[referrer].distributedEarnings;
    }

    function getTotalEquities(address referrer, uint256 productId) external view returns (uint256) {
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        if (!_existsReferredProduct(referrerData, productId)) {
            return 0;
        }
        return _getReferredProduct(referrerData, productId).totalEquities;
    }

    function getSettledInterest(address referrer, uint256 productId) external view returns (uint256) {
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        if (!_existsReferredProduct(referrerData, productId)) {
            return 0;
        }
        return _getReferredProduct(referrerData, productId).settledInterest;
    }

    function accruedEarnings(address referrer) external view returns (uint256) {
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        uint256 allReferredProductsCount = referrerData.allReferredProducts.length;

        uint256 undistributedEarnings = 0;
        for (uint256 i = 0; i < allReferredProductsCount; i++) {
            ReferredProduct memory referredProduct = referrerData.allReferredProducts[i];

            uint256 unsettledInterest = _productUnsettledInterest(referredProduct);
            undistributedEarnings += _calculateEarnings(unsettledInterest);
        }

        return referrerData.distributedEarnings + undistributedEarnings;
    }

    function accruedEarnings(address referrer, uint256 productId) external view returns (uint256) {
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        if (!_existsReferredProduct(referrerData, productId)) {
            return 0;
        }

        ReferredProduct memory referredProduct = _getReferredProduct(referrerData, productId);
        uint256 unsettledInterest = _productUnsettledInterest(referredProduct);

        return _calculateEarnings(unsettledInterest);
    }

    // claim distributed earnings
    function claimEarnings(address receiver) external {
        require(receiver != address(0), "zero address");

        address referrer = _msgSender();
        _claimDistributedEarnings(referrer, receiver);
    }

    function claimEarnings(address receiver, uint256[] calldata productIdSet) external {
        require(receiver != address(0), "zero address");

        address referrer = _msgSender();
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        for (uint256 i = 0; i < productIdSet.length; i++) {
            uint256 productId = productIdSet[i];
            if (_existsReferredProduct(referrerData, productId)) {
                _settleProduct(referrer, referrerData, productId);
            }
        }

        _claimDistributedEarnings(referrer, receiver);
    }

    function _claimDistributedEarnings(address referrer, address receiver) private {
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        if (referrerData.distributedEarnings > 0) {
            // save referrerData.distributedEarnings
            uint256 distributedEarnings = referrerData.distributedEarnings;
            // set settledEarnings to 0
            referrerData.distributedEarnings = 0;
            uint256 voucherId = longVoucher.mint(receiver, EARNINGS_VOUCHER_SLOT_ID, distributedEarnings);

            emit Claimed(referrer, receiver, distributedEarnings, voucherId);
        }
    }

    function _settleProduct(address referrer, ReferrerData storage referrerData, uint256 productId) private {
        ReferredProduct storage referredProduct = _getReferredProduct(referrerData, productId);
        uint256 currentInterest = _productCurrentInterest(referredProduct); 
        uint256 unsettledInterest = currentInterest - referredProduct.settledInterest;

        referrerData.distributedEarnings += _calculateEarnings(unsettledInterest);
        referredProduct.settledInterest = currentInterest;

        emit Settlement(referrer, productId, unsettledInterest);
    }

    function _productUnsettledInterest(ReferredProduct memory referredProduct) private view returns (uint256) {
        return _productCurrentInterest(referredProduct) - referredProduct.settledInterest;
    }

    function _productCurrentInterest(ReferredProduct memory referredProduct) private view returns (uint256) {
        return _calculateProductInterest(
            referredProduct.productCenter, referredProduct.productId, referredProduct.totalEquities, block.number);
    }

    function _calculateProductInterest(
        address productCenter, 
        uint256 productId, 
        uint256 equities, 
        uint256 endBlock
    ) private view returns (uint256) {
        IProductCenter.ProductParameters memory parameters = 
            IProductCenter(productCenter).getProductParameters(productId);
        
        if (endBlock <= parameters.endSubscriptionBlock) {
            return 0;
        }

        return parameters.interestRate.calculate(
            equities, 
            parameters.beginSubscriptionBlock, 
            parameters.endSubscriptionBlock, 
            parameters.endSubscriptionBlock, 
            endBlock
        );
    }

    function _existsReferredProduct(ReferrerData storage referrerData, uint256 productId) private view returns (bool) {
        return referrerData.allReferredProducts.length > 0 && _getReferredProduct(referrerData, productId).productId == productId;
    }

    function _getReferredProduct(ReferrerData storage referrerData, uint256 productId) private view returns (ReferredProduct storage) {
        return referrerData.allReferredProducts[referrerData.allReferredProductsIndex[productId]];
    }

    function _calculateEarnings(uint256 interest) private view returns (uint256) {
        return interest * referrerEarningsRatio / MANTISSA_ONE;
    }

    /// implement IVoucherProvider

    function isRedeemable(uint256 voucherId) external view returns (bool) {
        require(longVoucher.slotOf(voucherId) == EARNINGS_VOUCHER_SLOT_ID, "Not earings voucher");
        return true;
    }

    function getRedeemableAmount(uint256 voucherId) external view returns (uint256) {
        require(longVoucher.slotOf(voucherId) == EARNINGS_VOUCHER_SLOT_ID, "Not earings voucher");
        return longVoucher.balanceOf(voucherId);
    }

    /// implement IRecommendation

    function beforeEquitiesTransfer(
        address productCenter_,
        uint256 productId_,
        address from_,
        address to_,
        uint256 fromVoucherId_,
        uint256 toVoucherId_,
        uint256 value_
    ) external override {
        require(_msgSender() == productCenter_, "illegal caller");

        (bool fromExistsReferralInfo, IRecommendation.ReferralInfo memory fromReferralInfo) = recommendation.getReferralInfo(from_);
        (bool toExistsReferralInfo, IRecommendation.ReferralInfo memory toReferralInfo) = recommendation.getReferralInfo(to_);

        if (fromExistsReferralInfo) {
            _tryTrackProduct(productCenter_, productId_, fromReferralInfo);
            _tryTrackVoucher(productCenter_, productId_, fromVoucherId_, fromReferralInfo);
        }

        if (toExistsReferralInfo) {
            _tryTrackProduct(productCenter_, productId_, toReferralInfo);
            _tryTrackVoucher(productCenter_, productId_, toVoucherId_, toReferralInfo);
        }
        
        value_;
    }

    function _tryTrackProduct(
        address productCenter, 
        uint256 productId, 
        IRecommendation.ReferralInfo memory referralInfo
    ) private {
        ReferrerData storage referrerData = _referrerDataMapping[referralInfo.referrer];
        if (!_existsReferredProduct(referrerData, productId)) {
            uint256 index = referrerData.allReferredProducts.length;

            // resize 
            referrerData.allReferredProducts.push();

            ReferredProduct storage referredProduct = referrerData.allReferredProducts[index];
            referredProduct.productCenter = productCenter;
            referredProduct.productId = productId;

            referrerData.allReferredProductsIndex[productId] = index;
        // } else {
        //     require(_getReferredProduct(referrerData, productId).productCenter == productCenter);
        }
    }

    function _tryTrackVoucher(
        address productCenter, 
        uint256 productId, 
        uint256 voucherId, 
        IRecommendation.ReferralInfo memory referralInfo
    ) private {
        ReferrerData storage referrerData = _referrerDataMapping[referralInfo.referrer];
        ReferredProduct storage referredProduct = _getReferredProduct(referrerData, productId);

        if (!_voucherTrackingFlag[voucherId] && longVoucher.existsToken(voucherId)) {
            uint256 equities = longVoucher.balanceOf(voucherId);
            // 计算voucher自起息区块至推荐关系绑定区块期间的利息，当作已清算的利息
            uint256 settledInterest = _calculateProductInterest(productCenter, productId, equities, referralInfo.bindAt);

            referredProduct.totalEquities += equities;
            referredProduct.settledInterest += settledInterest;

            _voucherTrackingFlag[voucherId] = true;
        }
    }

    function afterEquitiesTransfer(
        address productCenter_,
        uint256 productId_,
        address from_,
        address to_,
        uint256 fromVoucherId_,
        uint256 toVoucherId_,
        uint256 value_
    ) external override {
        require(_msgSender() == productCenter_, "illegal caller");
        if (value_ == 0) {
            return;
        }

        (bool fromExistsReferralInfo, IRecommendation.ReferralInfo memory fromReferralInfo) = recommendation.getReferralInfo(from_);
        (bool toExistsReferralInfo, IRecommendation.ReferralInfo memory toReferralInfo) = recommendation.getReferralInfo(to_);

        if (fromExistsReferralInfo) {
            // if transfer between referrals of same referrer
            if (toExistsReferralInfo &&  fromReferralInfo.referrer == toReferralInfo.referrer) {
                return;
            }

            ReferrerData storage referrerData = _referrerDataMapping[fromReferralInfo.referrer];
            ReferredProduct storage referredProduct = _getReferredProduct(referrerData, productId_);

            uint256 interestToSettle = _calculateProductInterest(productCenter_, productId_, value_, block.number);
            if (interestToSettle < referredProduct.settledInterest) {
                referredProduct.settledInterest -= interestToSettle;
            } else {
                referrerData.distributedEarnings = _calculateEarnings(interestToSettle - referredProduct.settledInterest);
                referredProduct.settledInterest = 0;
            }
            referredProduct.totalEquities -= value_;

            if (referredProduct.totalEquities == 0) {
                _removeReferredProduct(referrerData, productId_);
            }
        }

        if (toExistsReferralInfo) {
            ReferrerData storage referrerData = _referrerDataMapping[toReferralInfo.referrer];
            ReferredProduct storage referredProduct = _getReferredProduct(referrerData, productId_);

            uint256 interestDeduction = _calculateProductInterest(productCenter_, productId_, value_, block.number);
            
            referredProduct.totalEquities += value_;
            referredProduct.settledInterest += interestDeduction;

            _voucherTrackingFlag[toVoucherId_] = true;
        }

        fromVoucherId_;
    }

    function _removeReferredProduct(ReferrerData storage referrerData, uint256 productId) private {
        uint256 lastReferredProductIndex = referrerData.allReferredProducts.length - 1;
        ReferredProduct memory lastReferredProduct = referrerData.allReferredProducts[lastReferredProductIndex];
        uint256 targetIndex = referrerData.allReferredProductsIndex[productId];

        referrerData.allReferredProducts[targetIndex] = lastReferredProduct;
        referrerData.allReferredProductsIndex[lastReferredProduct.productId] = targetIndex;

        delete referrerData.allReferredProductsIndex[productId];
        referrerData.allReferredProducts.pop();
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
}