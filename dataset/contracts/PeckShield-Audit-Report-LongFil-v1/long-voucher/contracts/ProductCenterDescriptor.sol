// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./IInterestRate.sol";
import "./IProductCenter.sol";
import "./ILongVoucher.sol";
import "./ILongVoucherMetadataProvider.sol";
import "./utils/StringConverter.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

contract ProductCenterDescriptor is Initializable, ContextUpgradeable, ILongVoucherMetadataProvider
{
    using StringConverter for address;
    using StringConverter for uint256;
    using StringConverter for bytes;

    struct BasicInfo {
        string name;
        string desc;
        string link;
    }

    ILongVoucher public longVoucher;

    // product center => product center info
    mapping(address => BasicInfo) private _productCenterBasics;

    // product id => product information
    mapping(uint256 => BasicInfo) private _productBasics;

    // product cneter => IVoucherSVG
    mapping(address => address) private _productCenterVoucherSVGs;

    // product id => IVoucherSVG
    mapping(uint256 => address) private _productVoucherSVGs;

    /// upgradeable initialize
    function initialize( address longVoucher_) public initializer {
        require(longVoucher_ != address(0), "zero address");

        // initialize
        longVoucher = ILongVoucher(longVoucher_);
    }

    /// admin functions
    function setProductCenterInfo(address productCenter_, BasicInfo memory basicInfo) external {
        IProductCenter productCenter = IProductCenter(productCenter_);
        require(productCenter.isAdmin(_msgSender()), "not admin");

        _productCenterBasics[productCenter_] = basicInfo;
    }

    function setProductInfo(uint256 productId, BasicInfo memory basicInfo) external {
        IProductCenter productCenter = IProductCenter(longVoucher.managerOf(productId));
        require(productCenter.isOperator(productId, _msgSender()), "not operator");

        _productBasics[productId] = basicInfo;
    }

    function setProductCenterVoucherSVG(address productCenter_, address voucherSVG_) external {
        require(voucherSVG_ != address(0), "zero address");
        IProductCenter productCenter = IProductCenter(productCenter_);
        require(productCenter.isAdmin(_msgSender()), "not admin");

        _productCenterVoucherSVGs[productCenter_] = voucherSVG_;
    }

    function setProductVoucherSVG(uint256 productId, address voucherSVG_) external {
        require(voucherSVG_ != address(0), "zero address");

        IProductCenter productCenter = IProductCenter(longVoucher.managerOf(productId));
        require(productCenter.isOperator(productId, _msgSender()), "not operator");

        _productVoucherSVGs[productId] = voucherSVG_;
    }

    /// view functions
    function getProductCenterInfo(address productCenter) external view returns (BasicInfo memory) {
        return _productCenterBasics[productCenter];
    }

    function getProductInfo(uint256 productId) external view returns (BasicInfo memory) {
        return _productBasics[productId];
    }

    function getProductCenterVoucherSVG(address productCenter) public view returns (address) {
        return _productCenterVoucherSVGs[productCenter];
    }

    function getProductVoucherSVG(uint256 productId) public view returns (address) {
        return _productVoucherSVGs[productId];
    }

    function slotMetadata(
        uint256 productId
    ) external view override returns (LongVoucherMetadata memory metadata) {
        IProductCenter productCenter = IProductCenter(longVoucher.managerOf(productId));
        BasicInfo memory productCenterInfo = _productCenterBasics[address(productCenter)];

        BasicInfo memory productInfo = _productBasics[productId];
        IProductCenter.ProductParameters memory parameters = productCenter.getProductParameters(productId);

        metadata.name = productInfo.name;
        metadata.desc = productInfo.desc;
        metadata.link = bytes(productInfo.link).length > 0 ? productInfo.link : productCenterInfo.link;

        metadata.attributes[0] = productCenterNameAttribute(productCenterInfo.name);
        metadata.attributes[1] = productCenterContractAttribute(productCenter);
        metadata.attributes[2] = productStageAttribute(parameters);
        metadata.attributes[3] = productAPRAttribute(parameters);
        metadata.attributes[4] = productTotalEquitiesAttribute(productCenter, productId);
        metadata.attributes[5] = productTotalFundsRaisedAttribute(productCenter, productId);
        metadata.attributes[6] = productTotalFundsLoanedAttribute(productCenter, productId);
        metadata.attributes[7] = productInterestAttribute(productCenter, productId);
    }

    function tokenMetadata(
        uint256 voucherId
    ) external view override returns (LongVoucherMetadata memory metadata) {
        uint256 productId = longVoucher.slotOf(voucherId);
        IProductCenter productCenter = IProductCenter(longVoucher.managerOf(productId));
        BasicInfo memory productCenterInfo = _productCenterBasics[address(productCenter)];

        IProductCenter.ProductParameters memory parameters = productCenter.getProductParameters(productId);
        BasicInfo memory productInfo = _productBasics[productId];

        metadata.name = string.concat(productInfo.name, "#", voucherId.toString());
        metadata.desc = metadata.name; // TODO: 凭单描述
        metadata.link = string.concat(productInfo.link, "/", voucherId.toString());

        metadata.attributes[0] = productCenterNameAttribute(productCenterInfo.name);
        metadata.attributes[1] = productCenterContractAttribute(productCenter);
        metadata.attributes[2] = productIdAttribute(productId);
        metadata.attributes[3] = productNameAttribute(productInfo);
        metadata.attributes[4] = productStageAttribute(parameters);
        metadata.attributes[5] = productAPRAttribute(parameters);
        metadata.attributes[6] = voucherInterestAttribute(productCenter, voucherId);
        metadata.attributes[7] = isRedeemableAttribute(productCenter, voucherId);
    }

    function voucherSVG(
        uint256 voucherId
    ) external view override returns (address) {
        uint256 productId = longVoucher.slotOf(voucherId);
        address productVoucherSVG = _productVoucherSVGs[productId];
        return productVoucherSVG == address(0) ? getProductCenterVoucherSVG(longVoucher.managerOf(productId)) : productVoucherSVG;
    }

    function productCenterNameAttribute(string memory productCenterName)
        private
        pure
        returns (Attribute memory attribute)
    {
        attribute = Attribute({
            name: "product_center",
            desc: "product center name",
            value: productCenterName
        });
    }

    function productCenterContractAttribute(IProductCenter productCenter)
        private
        pure
        returns (Attribute memory attribute)
    {
        attribute = Attribute({
            name: "product_center_contract",
            desc: "contract address of product center",
            value: address(productCenter).toString()
        });
    }

    function productIdAttribute(
        uint256 productId
    ) private pure returns (Attribute memory attribute) {
        attribute = Attribute({
            name: "product_id",
            desc: "product id",
            value: productId.toString()
        });
    }

    function productNameAttribute(
        BasicInfo memory info
    ) private pure returns (Attribute memory attribute) {
        attribute = Attribute({
            name: "product_name",
            desc: "product name",
            value: info.name
        });
    }

    function productStageAttribute(
        IProductCenter.ProductParameters memory parameters
    ) private view returns (Attribute memory attribute) {
        attribute = Attribute({
            name: "product_stage",
            desc: "stage of product",
            value: getProductStage(parameters)
        });
    }

    function getProductStage(
        IProductCenter.ProductParameters memory parameters
    ) private view returns (string memory stage) {
        if (block.number < parameters.beginSubscriptionBlock) {
            stage = "PRE_SUBSCRIPTION";
        } else if (block.number < parameters.endSubscriptionBlock) {
            stage = "SUBSCRIPTION";
        } else {
            stage = "ONLINE";
        }
    }

    function productAPRAttribute(
        IProductCenter.ProductParameters memory parameters
    ) private view returns (Attribute memory attribute) {
        string memory apr = IInterestRate(parameters.interestRate).nowAPR(parameters.beginSubscriptionBlock, parameters.endSubscriptionBlock);
        attribute = Attribute({
            name: "APR",
            desc: "APR at present",
            value: apr
        });
    }

    function productTotalEquitiesAttribute(
        IProductCenter productCenter,
        uint256 productId
    ) private view returns (Attribute memory attribute) {
        attribute = Attribute({
            name: "total_equities",
            desc: "total equities of product",
            value: string(productCenter.getTotalEquities(productId).uint2decimal(18).trim(12))
        });
    }

    function productTotalFundsRaisedAttribute(
        IProductCenter productCenter,
        uint256 productId
    ) private view returns (Attribute memory attribute) {
        attribute = Attribute({
            name: "total_funds_raised",
            desc: "total funds raised of product",
            value: string(productCenter.getTotalFundsRaised(productId).uint2decimal(18).trim(12))
        });
    }

    function productTotalFundsLoanedAttribute(
        IProductCenter productCenter,
        uint256 productId
    ) private view returns (Attribute memory attribute) {
        attribute = Attribute({
            name: "total_funds_loaned",
            desc: "total funds loaned of product",
            value: string(productCenter.getTotalFundsLoaned(productId).uint2decimal(18).trim(12))
        });
    }

    function productInterestAttribute(
        IProductCenter productCenter,
        uint256 productId
    ) private view returns (Attribute memory attribute) {
        attribute = Attribute({
            name: "product_interest",
            desc: "accumulated interest of product",
            value: string(productCenter.productInterest(productId).uint2decimal(18).trim(12))
        });
    }

    function voucherInterestAttribute(
        IProductCenter productCenter,
        uint256 voucherId
    ) private view returns (Attribute memory attribute) {
        attribute = Attribute({
            name: "voucher_interest",
            desc: "accumulated interest of voucher",
            value: string(productCenter.voucherInterest(voucherId).uint2decimal(18).trim(12))
        });
    }

    function isRedeemableAttribute(
        IProductCenter productCenter,
        uint256 voucherId
    ) private view returns (Attribute memory attribute) {
        attribute = Attribute({
            name: "is_redeemable",
            desc: "redeemable or not at present",
            value: productCenter.isRedeemable(voucherId) ? "true" : "false"
        });
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
}