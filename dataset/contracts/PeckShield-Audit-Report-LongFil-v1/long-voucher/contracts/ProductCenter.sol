// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./Errors.sol";
import "./IInterestRate.sol";
import "./ILongVoucher.sol";
import "./IProductCenter.sol";
import "./IRecommendationCenter.sol";
import "./ISlotManager.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ProductCenter is AccessControl, ISlotManager, IProductCenter {
    /// constants
    bytes32 public constant ADMIN_ROLE = keccak256("admin");
    bytes32 public constant OPERATOR_ROLE = keccak256("operator");
    bytes32 public constant CASHIER_ROLE = keccak256("cashier");

    struct SubscriptionData {
        uint256 atBlock;
        address subscriber;
        uint256 principal;
        uint256 voucherId;
    }

    struct ProductData {
        uint256 productId;
        ProductParameters parameters;
        uint256 totalEquities;
        uint256 totalFundsRaised;
        uint256 totalFundsLoaned;
    }

    /// storage

    ILongVoucher public longVoucher;
    address public recommendationCenter;

    // all products
    ProductData[] private _allProducts;

    // productId => index in _allProducts
    mapping(uint256 => uint256) private _allProductsIndex;

    // subscriber => productId => subscriptions
    mapping(address => mapping(uint256 => SubscriptionData)) private _subscriptions;

    /// events
    event InterestRateChanged(uint256 indexed productId, address oldInterestRate, address newInterestRate);

    event SetRecommendationCenter(address recommendationCenter);

    event ProductCreated(uint256 indexed productId, ProductParameters parameters, address operator);

    event Subscribe(uint256 indexed productId, address subscriber, uint256 principal, uint256 voucherId);

    event CancelSubscription(uint256 indexed productId, address subscriber, uint256 principal, uint256 voucherId);

    event OfferLoans(uint256 indexed productId, address receiver, uint256 amount, address cashier);

    /**
     * initialize method, called by proxy
     */
    constructor(address longVoucher_, address initialAdmin_, address recommendationCenter_) {
        require(longVoucher_ != address(0), Errors.ZERO_ADDRESS);
        require(initialAdmin_ != address(0), Errors.ZERO_ADDRESS);

        longVoucher = ILongVoucher(longVoucher_);

        if (recommendationCenter_ != address(0)) {
            IRecommendationCenter(recommendationCenter_).beforeEquitiesTransfer(address(this), 0, address(0), address(0), 0, 0, 0);
            recommendationCenter = recommendationCenter_;
            emit SetRecommendationCenter(recommendationCenter_);
        }

        // grant roles
        _grantRole(ADMIN_ROLE, initialAdmin_);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(CASHIER_ROLE, ADMIN_ROLE);
    }

    // ERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return
            interfaceId == type(ISlotManager).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// view functions

    function isAdmin(address account) external view override returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    function isOperator(uint256 productId, address account) external view override returns (bool) {
        productId;
        return hasRole(OPERATOR_ROLE, account);
    }

    function productCount() public view override returns (uint256) {
        return _allProducts.length;
    }

    function productIdByIndex(
        uint256 index_
    ) external view override returns (uint256) {
        require(index_ < productCount(), Errors.INDEX_EXCEEDS);
        return _allProducts[index_].productId;
    }

    function getProductParameters(
        uint256 productId
    ) external view override returns (ProductParameters memory parameters) {
        _requireExistsProduct(productId);
        return _allProducts[_allProductsIndex[productId]].parameters;
    }

    function getTotalEquities(
        uint256 productId
    ) external view override returns (uint256) {
        _requireExistsProduct(productId);
        return _allProducts[_allProductsIndex[productId]].totalEquities;
    }

    function getTotalFundsRaised(
        uint256 productId
    ) external view override returns (uint256) {
        _requireExistsProduct(productId);
        return _allProducts[_allProductsIndex[productId]].totalFundsRaised;
    }

    function getTotalFundsLoaned(
        uint256 productId
    ) external view override returns (uint256) {
        _requireExistsProduct(productId);
        return _allProducts[_allProductsIndex[productId]].totalFundsLoaned;
    }

    function isSubscriber(
        uint256 productId,
        address subscriber
    ) public view override returns (bool) {
        _requireExistsProduct(productId);
        return _existsSubscription(productId, subscriber);
    }

    function getSubscription(
        uint256 productId,
        address subscriber
    ) external view override returns (Subscription memory subscription) {
        _requireIsSubscriber(productId, subscriber);

        SubscriptionData memory subscriptionData = _subscriptions[subscriber][productId];

        subscription.subscriber = subscriptionData.subscriber;
        subscription.atBlock = subscriptionData.atBlock;
        subscription.principal = subscriptionData.principal;
        subscription.voucherId = subscriptionData.voucherId;
    }

    function voucherInterest(uint256 voucherId) external view override returns (uint256) {
        uint256 productId = longVoucher.slotOf(voucherId);
        _requireExistsProduct(productId);

        ProductParameters memory parameters = _allProducts[_allProductsIndex[productId]].parameters;
        if (!_isInOnlineStage(parameters)) {
            return 0;
        }

        return IInterestRate(parameters.interestRate).calculate(longVoucher.balanceOf(voucherId), 
            parameters.beginSubscriptionBlock, parameters.endSubscriptionBlock, parameters.endSubscriptionBlock, block.number);
    }

    function productInterest(uint256 productId) external view override returns (uint256) {
        _requireExistsProduct(productId);

        ProductData storage product = _allProducts[_allProducts.length - 1];
        ProductParameters memory parameters = product.parameters;
        if (!_isInOnlineStage(parameters)) {
            return 0;
        }

        return IInterestRate(parameters.interestRate).calculate(product.totalEquities,
            parameters.beginSubscriptionBlock, parameters.endSubscriptionBlock, parameters.endSubscriptionBlock, block.number);
    }

    /// implement IVoucherProvider

    function isRedeemable(
        uint256 voucherId
    ) public view override returns (bool) {
        uint256 productId = longVoucher.slotOf(voucherId);
        _requireExistsProduct(productId);

        ProductParameters memory parameters = _allProducts[_allProductsIndex[productId]].parameters;
        return _isRedeemable(parameters);
    }

    function getRedeemableAmount(
        uint256 voucherId
    ) external view override returns (uint256) {
        require(isRedeemable(voucherId), Errors.NOT_REDEEMABLE_AT_PRESENT);

        uint256 productId = longVoucher.slotOf(voucherId);
        ProductParameters memory parameters = _allProducts[_allProductsIndex[productId]].parameters;

        uint256 equities = longVoucher.balanceOf(voucherId);
        uint256 interest = IInterestRate(parameters.interestRate).calculate(equities, parameters.beginSubscriptionBlock, 
            parameters.endSubscriptionBlock, parameters.endSubscriptionBlock, block.number);
        
        return equities + interest;
    }

    /// admin functions

    function setInterestRate(
        uint256 productId,
        address interestRate_
    ) external onlyRole(OPERATOR_ROLE) {
        require(interestRate_ != address(0), Errors.ZERO_ADDRESS);
        _requireExistsProduct(productId);

        ProductParameters storage parameters = _allProducts[_allProductsIndex[productId]].parameters;
        require(
            block.number < parameters.beginSubscriptionBlock ||
                block.number >= parameters.endSubscriptionBlock,
            Errors.INVALID_PRODUCT_STAGE
        );

        address oldInterestRate = address(parameters.interestRate);
        parameters.interestRate = IInterestRate(interestRate_);

        emit InterestRateChanged(productId, oldInterestRate, interestRate_);
    }

    function setRecommendationCenter(address recommendationCenter_) external onlyRole(ADMIN_ROLE) {
        require(recommendationCenter == address(0), Errors.RECOMMENDATION_CENTER); 
        require(recommendationCenter_ != address(0), Errors.ZERO_ADDRESS); 

        // test 
        IRecommendationCenter(recommendationCenter_).beforeEquitiesTransfer(address(this), 0, address(0), address(0), 0, 0, 0);

        // set storage
        recommendationCenter = recommendationCenter_;

        emit SetRecommendationCenter(recommendationCenter_);
    }

    /// state functions

    function create(
        uint256 productId,
        ProductParameters memory parameters
    ) external onlyRole(OPERATOR_ROLE) {
        require(!_existsProduct(productId), Errors.DUPLICATED_PRODUCT_ID);
        require(!longVoucher.existsSlot(productId), Errors.NOT_AVAILABLE_PRODUCT_ID);

        require(parameters.totalQuota > 0, Errors.BAD_TOTALQUOTA);
        require(
            parameters.totalQuota >= parameters.minSubscriptionAmount,
            Errors.BAD_MINSUBSCRIPTIONAMOUNT
        );
        require(
            parameters.beginSubscriptionBlock >= block.number,
            Errors.BAD_BEGINSUBSCRIPTIONBLOCK
        );
        require(
            parameters.endSubscriptionBlock > parameters.beginSubscriptionBlock,
            Errors.BAD_ENDSUBSCRIPTIONBLOCK
        );
        require(
            address(parameters.interestRate) != address(0),
            Errors.ZERO_ADDRESS
        );

        // change state
        // resize _allProducts
        _allProducts.push();

        ProductData storage product = _allProducts[_allProducts.length - 1];
        product.productId = productId;
        product.parameters.totalQuota = parameters.totalQuota;
        product.parameters.minSubscriptionAmount = parameters.minSubscriptionAmount;
        product.parameters.beginSubscriptionBlock = parameters.beginSubscriptionBlock;
        product.parameters.endSubscriptionBlock = parameters.endSubscriptionBlock;
        product.parameters.minHoldingDuration = parameters.minHoldingDuration;
        product.parameters.interestRate = parameters.interestRate;

        _allProductsIndex[productId] = _allProducts.length - 1;

        // claim slot via mint zero amount,
        longVoucher.mint(address(this), productId, 0);

        // emit events
        emit ProductCreated(productId, parameters, _msgSender());
        emit InterestRateChanged(productId, address(0), address(parameters.interestRate));
    }

    function subscribe(
        uint256 productId
    ) external payable returns (uint256 voucherId) {
        _requireExistsProduct(productId);

        address subscriber = _msgSender();
        uint256 principal = msg.value;

        // ref ProductData
        ProductData storage product = _allProducts[_allProductsIndex[productId]];
        ProductParameters memory parameters = product.parameters;

        // check whether subscription is opening
        _requireInSubscriptionStage(parameters);
        require(
            product.totalFundsRaised + principal <= parameters.totalQuota,
            Errors.EXCEEDS_TOTALQUOTA
        );

        // if additional subscription, re mint voucher
        if (_existsSubscription(productId, subscriber)) {
            SubscriptionData storage subscription = _subscriptions[subscriber][productId];

            uint256 oldVoucherId = subscription.voucherId;
            uint256 oldEquities = longVoucher.balanceOf(oldVoucherId);

            uint256 addedInterestDuringSubscription = IInterestRate(
                parameters.interestRate
            ).calculate(
                    principal,
                    parameters.beginSubscriptionBlock,
                    parameters.endSubscriptionBlock,
                    block.number,
                    parameters.endSubscriptionBlock
                );
            uint256 addedEquities = principal + addedInterestDuringSubscription;
            uint256 newEquities = oldEquities + addedEquities;

            // burn old voucher
            longVoucher.burn(oldVoucherId);

            // mint new voucher
            voucherId = longVoucher.mint(subscriber, productId, newEquities);

            // update state
            product.totalFundsRaised += principal;
            subscription.atBlock = block.number;
            subscription.principal += principal;
            subscription.voucherId = voucherId;

            emit Subscribe(productId, subscriber, subscription.principal, voucherId);
        } else {
            require(principal >= parameters.minSubscriptionAmount, Errors.LESS_THAN_MINSUBSCRIPTIONAMOUNT);

            uint256 interestDuringSubscription = IInterestRate(
                parameters.interestRate
            ).calculate(
                    principal,
                    parameters.beginSubscriptionBlock,
                    parameters.endSubscriptionBlock,
                    block.number,
                    parameters.endSubscriptionBlock
                );
            uint256 equities = principal + interestDuringSubscription;

            // mint voucher
            voucherId = longVoucher.mint(subscriber, productId, equities);

            // update states
            product.totalFundsRaised += principal;

            SubscriptionData storage subscription = _subscriptions[subscriber][productId];
            subscription.atBlock = block.number;
            subscription.subscriber = subscriber;
            subscription.principal = principal;
            subscription.voucherId = voucherId;

            emit Subscribe(productId, subscriber, subscription.principal, voucherId);
        }
    }

    function cancelSubscription(
        uint256 productId,
        uint256 amount,
        address receiver
    ) external returns (uint256 newVoucherId) {
        _requireIsSubscriber(productId, _msgSender());
        require(receiver != address(0), Errors.ZERO_ADDRESS);

        // ref ProductData
        ProductData storage product = _allProducts[_allProductsIndex[productId]];
        ProductParameters memory parameters = product.parameters;

        // check whether subscription is opening
        _requireInSubscriptionStage(parameters);

        address subscriber = _msgSender();
        SubscriptionData memory subscription = _subscriptions[subscriber][productId];

        // check balance
        require(amount <= subscription.principal, Errors.INSUFFICIENT_BALANCE);

        // redeem all
        if (amount == subscription.principal) {
            // burn old voucher
            longVoucher.burn(subscription.voucherId);

            // update product
            product.totalFundsRaised -= subscription.principal;

            // delete subscription
            delete _subscriptions[subscriber][productId];

            // send Fil
            (bool sent, ) = receiver.call{value: subscription.principal}("");
            require(sent, Errors.SEND_ERROR);

            emit CancelSubscription(productId, subscriber, subscription.principal, subscription.voucherId);
        } else {
            uint256 newPrincipal = subscription.principal - amount;
            require(newPrincipal >= parameters.minSubscriptionAmount, Errors.LESS_THAN_MINSUBSCRIPTIONAMOUNT);

            // calculate new interest during subscription
            uint256 newInterestDuringSubscription = IInterestRate(
                parameters.interestRate
            ).calculate(
                    newPrincipal,
                    parameters.beginSubscriptionBlock,
                    parameters.endSubscriptionBlock,
                    block.number,
                    parameters.endSubscriptionBlock
                );
            uint256 newEquities = newPrincipal + newInterestDuringSubscription;

            // burn old voucher
            longVoucher.burn(subscription.voucherId);

            // mint new voucher
            newVoucherId = longVoucher.mint(subscriber, productId, newEquities);

            // update state
            product.totalFundsRaised -= amount;
            _subscriptions[subscriber][productId] = SubscriptionData({
                atBlock: block.number,
                subscriber: subscriber,
                principal: newPrincipal,
                voucherId: newVoucherId
            });

            // send Fil
            (bool sent, ) = receiver.call{value: amount}("");
            require(sent, Errors.SEND_ERROR);

            emit CancelSubscription(productId, subscriber, subscription.principal, subscription.voucherId);
            emit Subscribe(productId, subscriber, newPrincipal, newVoucherId);
        }
    }

    function loan(
        uint256 productId,
        uint256 amount,
        address receiver
    ) external onlyRole(CASHIER_ROLE) {
        _requireExistsProduct(productId);
        require(receiver != address(0), Errors.ZERO_ADDRESS);

        ProductData storage product = _allProducts[_allProductsIndex[productId]];

        // check whether subscription is closed
        _requireInOnlineStage(product.parameters);
        require(product.totalFundsLoaned + amount <= product.totalFundsRaised, Errors.INSUFFICIENT_BALANCE);

        // add to total loans
        product.totalFundsLoaned += amount;

        // send Fil
        (bool sent, ) = receiver.call{value: amount}("");
        require(sent, Errors.SEND_ERROR);

        emit OfferLoans(productId, receiver, amount, _msgSender());
    }

    /// internal functions

    function _requireExistsProduct(uint256 productId) private view {
        require(_existsProduct(productId), Errors.PRODUCT_NOT_EXISTS);
    }

    function _existsProduct(uint256 productId) private view returns (bool) {
        return
            _allProducts.length > 0 &&
            _allProducts[_allProductsIndex[productId]].productId == productId;
    }

    function _requireInSubscriptionStage(
        ProductParameters memory parameters
    ) private view {
        require(
            block.number >= parameters.beginSubscriptionBlock && block.number < parameters.endSubscriptionBlock,
            Errors.INVALID_PRODUCT_STAGE
        );
    }

    function _requireInOnlineStage(
        ProductParameters memory parameters
    ) private view {
        require(
            _isInOnlineStage(parameters),
            Errors.INVALID_PRODUCT_STAGE
        );
    }

    function _isInOnlineStage(ProductParameters memory parameters) private view returns (bool) {
        return block.number >= parameters.endSubscriptionBlock;
    }

    function _isRedeemable(
        ProductParameters memory parameters
    ) private view returns (bool) {
        return
            block.number >=
            parameters.endSubscriptionBlock + parameters.minHoldingDuration;
    }

    function _requireIsSubscriber(
        uint256 productId,
        address subscriber
    ) private view {
        require(isSubscriber(productId, subscriber), Errors.NOT_SUBSCRIBER);
    }

    function _existsSubscription(
        uint256 productId,
        address subscriber
    ) private view returns (bool) {
        return _subscriptions[subscriber][productId].subscriber == subscriber;
    }

    /// implement ISlotManager

    function beforeValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) external override {
        require(_msgSender() == address(longVoucher), Errors.ILLEGAL_CALLER);

        ProductParameters memory parameters = _allProducts[_allProductsIndex[slot_]].parameters;
        // only mint or brun before online
        if (block.number < parameters.endSubscriptionBlock) {
            require(
                (from_ == address(0) && fromTokenId_ == 0) || (to_ == address(0) && toTokenId_ == 0),
                Errors.TRANSFORM_CONTROL
            );
        }

        if (recommendationCenter != address(0)) {
            IRecommendationCenter(recommendationCenter).beforeEquitiesTransfer(address(this), slot_, from_, to_, fromTokenId_, toTokenId_, value_);
        }
    }

    function afterValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) external override {
        require(_msgSender() == address(longVoucher), Errors.ILLEGAL_CALLER);

        ProductData storage product = _allProducts[_allProductsIndex[slot_]];

        // if mint, increase product equities
        if (from_ == address(0) && fromTokenId_ == 0) {
            product.totalEquities += value_;
        }

        // if burn, reduce product equities
        if (to_ == address(0) && toTokenId_ == 0) {
            product.totalEquities -= value_;
        }

        if (address(recommendationCenter) != address(0)) {
            IRecommendationCenter(recommendationCenter).afterEquitiesTransfer(address(this), slot_, from_, to_, fromTokenId_, toTokenId_, value_);
        }
    }
}