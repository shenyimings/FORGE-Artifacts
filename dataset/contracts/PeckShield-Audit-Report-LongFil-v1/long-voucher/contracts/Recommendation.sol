// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./ILongVoucher.sol";
import "./IRecommendation.sol";
import "./ISlotManager.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

contract Recommendation is
    Ownable2StepUpgradeable,
    EIP712Upgradeable,
    IERC165Upgradeable,
    ISlotManager,
    IRecommendation
{
    uint256 public constant QUALIFICATION_SLOT_ID = 22;
    bytes32 public constant RECOMMENDATION_TYPEHASH = keccak256("Referrer(address referrer,uint256 deadline)");

    struct ReferralData {
        address referrer;
        uint256 bindAt;
        uint256[10] __gap;
    }

    /// storage
    ILongVoucher public longVoucher;

    // referrer => qualification token counter
    mapping(address => uint256) private _referrerQualification;

    // referral => recommendation
    mapping(address => ReferralData) private _referralReferralData;

    /// events

    event Mint(address receiver, uint256 qualificationId);
    event Bind(address indexed referrer, address referral, uint256 bindAt);

    /**
     * initialize method, called by proxy
     */
    function initialize(
        address longVoucher_,
        address initialOwner_
    ) public initializer {
        require(longVoucher_ != address(0), "zero address");
        require(initialOwner_ != address(0), "zero address");

        // call super initialize methods
        Ownable2StepUpgradeable.__Ownable2Step_init();
        EIP712Upgradeable.__EIP712_init(ILongVoucher(longVoucher_).name(), version());

        longVoucher = ILongVoucher(longVoucher_);

        // initialize owner
        _transferOwnership(initialOwner_);

        // take up QUALIFICATION_SLOT_ID by mint new token
        longVoucher.mint(address(this), QUALIFICATION_SLOT_ID, 0);
    }

    // ERC165
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return interfaceId == type(ISlotManager).interfaceId;
    }

    /**
     */
    function name() public view returns (string memory) {
        return longVoucher.name();
    }

    /**
     */
    function version() public pure returns (string memory) {
        return "1";
    }

    /**
     * mint qualification 
     */
    function mint(address receiver) external onlyOwner returns (uint256 qualificationId) {
        require(receiver != address(0), "zero address");

        qualificationId = longVoucher.mint(receiver, QUALIFICATION_SLOT_ID, 0);
        emit Mint(receiver, qualificationId);
    }

    /**
     * bind recommendation relationship
     */
    function bind(address referrer, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(isReferrer(referrer), "missing qualification");
        require(deadline >= block.timestamp, "beyond deadline");

        address referral = ECDSAUpgradeable.recover(
            _hashTypedDataV4(
                keccak256(abi.encode(RECOMMENDATION_TYPEHASH, referrer, deadline))
            ),
            v,
            r,
            s
        );
        require(referrer != referral, "illegal referral");
        require(!_existsReferralData(referral), "already bind");

        // update storage 
        ReferralData storage recommendation = _referralReferralData[referral];
        recommendation.referrer = referrer;
        recommendation.bindAt = block.number;

        emit Bind(referrer, referral, block.number);
    }

    /// implement IRecommendation

    function isReferrer(address referrer) public view override returns (bool) {
        return _referrerQualification[referrer] > 0;
    }

    function getReferralInfo(address referral) external view override returns (bool exists, ReferralInfo memory referralInfo) {
        if (_existsReferralData(referral)) {
            ReferralData memory referralData = _referralReferralData[referral];

            exists = true;
            referralInfo = ReferralInfo({
                referrer: referralData.referrer,
                bindAt: referralData.bindAt
            });
        }
    }

    function _existsReferralData(address referral) private view returns (bool) {
        return _referralReferralData[referral].referrer != address(0);
    }

    /// implement ISlotManager

    function beforeValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) external view override {
        require(_msgSender() == address(longVoucher), "illegal caller");

        // qualification can only be transferred as whole
        if (fromTokenId_ != 0 && toTokenId_ != 0) {
            require(fromTokenId_ == toTokenId_, "illegal transfer");
        }

        from_;
        to_;
        fromTokenId_;
        toTokenId_;
        slot_;
        value_;
    }

    function afterValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) external override {
        require(_msgSender() == address(longVoucher), "illegal caller");

        if (from_ != address(0)) {
            _referrerQualification[from_] -= 1;
            if (_referrerQualification[from_] == 0) {
                delete _referrerQualification[from_];
            }
        }

        if (to_ != address(0)) {
            _referrerQualification[to_] += 1;
        }

        fromTokenId_;
        toTokenId_;
        slot_;
        value_;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}