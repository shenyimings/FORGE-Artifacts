// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Trait is Ownable, ERC721Holder, ERC1155Holder {
    event OfferCreated(StructOffer);

    event Status(StructOffer, OfferStatus);

    event ExecludedFromFees(address contractAddress);
    event IncludedFromFees(address contractAddress);
    event FeesClaimedByAdmin(uint256 feesValue);
    event ExchangeFeesUpdated(uint256 prevFees, uint256 updatedFees);

    enum OfferStatus {
        pending,
        withdrawan,
        accepted,
        rejected
    }

    struct StructERC20Value {
        address erc20Contract;
        uint256 erc20Value;
    }

    struct StructERC721Value {
        address erc721Contract;
        uint256 erc721Id;
    }

    struct StructERC1155Value {
        address erc1155Contract;
        uint256 erc1155Id;
        uint256 amount;
        bytes data;
    }

    struct StructOffer {
        uint256 offerId;
        address sender;
        address receiver;
        uint256 offeredETH;
        uint256 requestedETH;
        StructERC20Value offeredERC20;
        StructERC20Value requestedERC20;
        StructERC721Value[] offeredERC721;
        StructERC721Value[] requestedERC721;
        StructERC1155Value[] offeredERC1155;
        StructERC1155Value[] requestedERC1155;
        uint256 timeStamp;
        uint256 validDuration;
        OfferStatus status;
    }

    struct StructAccount {
        uint256[] offersReceived;
        uint256[] offersCreated;
    }

    uint256 private _offerIds;
    address[] private _excludedFeesContracts;
    uint256 private _fees;
    uint256 private _feesCollected;
    uint256 private _feesClaimed;
    bool private _isTransacting;

    mapping(uint256 => StructOffer) private _mappingOffer;
    mapping(address => StructAccount) private _mappingAccounts;

    constructor(uint256 _feesInWei) {
        _fees = _feesInWei;
    }

    receive() external payable {}

    modifier noReentrancy() {
        require(
            !_isTransacting,
            "whileTreansacting(): Contract is already transaction"
        );
        _isTransacting = true;
        _;
        _isTransacting = false;
    }

    modifier isOfferValidForWithdrawal(uint256 _offerId) {
        StructOffer memory offerAccount = _mappingOffer[_offerId];

        require(
            offerAccount.sender != address(0),
            "Address zero cannot make offer."
        );

        require(
            offerAccount.receiver != address(0),
            "Cannot make offer to address zero."
        );

        require(
            offerAccount.status != OfferStatus.accepted,
            "Offer already used."
        );

        require(
            offerAccount.status != OfferStatus.withdrawan,
            "Offer already withdrawan."
        );
        _;
    }

    modifier isValidOffer(uint256 _offerId) {
        StructOffer memory offerAccount = _mappingOffer[_offerId];

        require(
            offerAccount.sender != address(0),
            "Address zero cannot make offer."
        );

        require(
            offerAccount.receiver != address(0),
            "Cannot make offer to address zero."
        );

        require(
            offerAccount.status == OfferStatus.pending,
            "Offer already accepted or withdrawan."
        );
        _;
    }

    modifier isReceiver(uint256 _offerId) {
        StructOffer memory offerAccount = _mappingOffer[_offerId];
        require(
            msg.sender == offerAccount.receiver,
            "You are not the receiver of this offer."
        );
        _;
    }

    function createOffer(StructOffer memory _structOffer)
        external
        payable
        returns (uint256 offerId)
    {
        require(
            _structOffer.receiver != address(0),
            "createOffer(): _receiver cannot be address zero."
        );
        require(
            _structOffer.offeredERC721.length < type(uint8).max,
            "createOffer(): Offered erc721 cannot be more than 255"
        );
        require(
            _structOffer.requestedERC721.length < type(uint8).max,
            "createOffer(): requested erc721 cannot be more than 255"
        );
        require(
            _structOffer.offeredERC1155.length < type(uint8).max,
            "createOffer(): Offered erc721 cannot be more than 255"
        );
        require(
            _structOffer.requestedERC1155.length < type(uint8).max,
            "createOffer(): Offered erc721 cannot be more than 255"
        );

        uint256 msgValue = msg.value;
        address msgSender = msg.sender;
        uint256 currentTime = block.timestamp;

        offerId = _offerIds;

        if (!_isBalanceExcludedFromFees(msgSender)) {
            require(
                msgValue >= _fees + _structOffer.offeredETH,
                "createOffer(): user is not included in exclude from fees and msgValue no included fees amount."
            );
            _feesCollected += _fees;
        } else {
            require(
                msgValue == _structOffer.offeredETH,
                "createOffer(): msgValue is not equal to ethOffered."
            );
        }

        StructOffer storage offerAccount = _mappingOffer[offerId];

        offerAccount.offerId = offerId;
        offerAccount.sender = msgSender;
        offerAccount.receiver = _structOffer.receiver;
        offerAccount.offeredETH = _structOffer.offeredETH;
        offerAccount.requestedETH = _structOffer.requestedETH;
        offerAccount.offeredERC20 = _structOffer.offeredERC20;
        offerAccount.requestedERC20 = _structOffer.requestedERC20;

        ///@dev please ensure that there is sufficient allowance to successfully invoke the transferFrom function.
        if (
            _structOffer.offeredERC20.erc20Contract != address(0) &&
            _structOffer.offeredERC20.erc20Value > 0
        ) {
            IERC20(_structOffer.offeredERC20.erc20Contract).transferFrom(
                msgSender,
                address(this),
                _structOffer.offeredERC20.erc20Value
            );
        }

        ///@dev please ensure that there is sufficient allowance to successfully invoke the transferFrom function.

        for (uint8 i; i < _structOffer.offeredERC721.length; ++i) {
            IERC721(_structOffer.offeredERC721[i].erc721Contract)
                .safeTransferFrom(
                    msgSender,
                    address(this),
                    _structOffer.offeredERC721[i].erc721Id
                );
            offerAccount.offeredERC721.push(_structOffer.offeredERC721[i]);
        }

        for (uint8 i; i < _structOffer.requestedERC721.length; ++i) {
            offerAccount.requestedERC721.push(_structOffer.requestedERC721[i]);
        }

        for (uint8 i; i < _structOffer.offeredERC1155.length; ++i) {
            IERC1155(_structOffer.offeredERC1155[i].erc1155Contract)
                .safeTransferFrom(
                    msgSender,
                    address(this),
                    _structOffer.offeredERC1155[i].erc1155Id,
                    _structOffer.offeredERC1155[i].amount,
                    _structOffer.offeredERC1155[i].data
                );

            offerAccount.offeredERC1155.push(_structOffer.offeredERC1155[i]);
        }

        for (uint8 i; i < _structOffer.requestedERC1155.length; ++i) {
            offerAccount.requestedERC1155.push(
                _structOffer.requestedERC1155[i]
            );
        }

        offerAccount.timeStamp = currentTime;
        offerAccount.validDuration = _structOffer.validDuration;
        offerAccount.status = OfferStatus.pending;

        _mappingAccounts[msgSender].offersCreated.push(offerId);
        _mappingAccounts[_structOffer.receiver].offersReceived.push(offerId);

        emit OfferCreated(_mappingOffer[offerId]);

        _offerIds++;
    }

    function acceptOffer(uint256 _offerId)
        external
        payable
        noReentrancy
        isValidOffer(_offerId)
        isReceiver(_offerId)
    {
        address msgSender = msg.sender;
        uint256 msgValue = msg.value;

        StructOffer storage offerAccount = _mappingOffer[_offerId];
        require(
            msgValue >= offerAccount.requestedETH,
            "Receiver has not sent enough eth, offer creator requested."
        );
        require(
            block.timestamp <
                offerAccount.timeStamp + offerAccount.validDuration,
            "Offer expired."
        );

        ///@dev please ensure that there is sufficient allowance to successfully invoke the transferFrom function.
        for (uint8 i; i < offerAccount.offeredERC721.length; i++) {
            IERC721(offerAccount.offeredERC721[i].erc721Contract).transferFrom(
                address(this),
                offerAccount.receiver,
                offerAccount.offeredERC721[i].erc721Id
            );
        }

        for (uint8 i; i < offerAccount.offeredERC1155.length; i++) {
            IERC1155(offerAccount.offeredERC1155[i].erc1155Contract)
                .safeTransferFrom(
                    address(this),
                    offerAccount.receiver,
                    offerAccount.offeredERC1155[i].erc1155Id,
                    offerAccount.offeredERC1155[i].amount,
                    offerAccount.offeredERC1155[i].data
                );
        }

        ///@dev please ensure that there is sufficient allowance to successfully invoke the transferFrom function.
        for (uint8 i; i < offerAccount.requestedERC721.length; i++) {
            IERC721(offerAccount.requestedERC721[i].erc721Contract)
                .transferFrom(
                    offerAccount.receiver,
                    offerAccount.sender,
                    offerAccount.requestedERC721[i].erc721Id
                );
        }

        for (uint8 i; i < offerAccount.requestedERC1155.length; i++) {
            IERC1155(offerAccount.requestedERC1155[i].erc1155Contract)
                .safeTransferFrom(
                    offerAccount.receiver,
                    offerAccount.sender,
                    offerAccount.requestedERC1155[i].erc1155Id,
                    offerAccount.requestedERC1155[i].amount,
                    "0x"
                );
        }

        if (offerAccount.offeredETH > 0) {
            payable(offerAccount.receiver).transfer(offerAccount.offeredETH);
        }

        if (offerAccount.requestedETH > 0) {
            payable(offerAccount.sender).transfer(offerAccount.requestedETH);
        }

        if (
            offerAccount.requestedERC20.erc20Contract != address(0) &&
            offerAccount.requestedERC20.erc20Value > 0
        ) {
            IERC20(offerAccount.requestedERC20.erc20Contract).transferFrom(
                msgSender,
                offerAccount.sender,
                offerAccount.requestedERC20.erc20Value
            );
        }

        ///@dev please ensure that there is sufficient allowance to successfully invoke the transferFrom function.
        if (
            offerAccount.offeredERC20.erc20Contract != address(0) &&
            offerAccount.offeredERC20.erc20Value > 0
        ) {
            IERC20(offerAccount.offeredERC20.erc20Contract).transfer(
                offerAccount.receiver,
                offerAccount.offeredERC20.erc20Value
            );
        }

        offerAccount.status = OfferStatus.accepted;
        emit Status(offerAccount, OfferStatus.accepted);
    }

    function rejectOffer(uint256 _offerId)
        external
        noReentrancy
        isValidOffer(_offerId)
        isReceiver(_offerId)
    {
        StructOffer storage offerAccount = _mappingOffer[_offerId];

        offerAccount.status = OfferStatus.rejected;
        emit Status(offerAccount, OfferStatus.rejected);
    }

    function withdrawOffer(uint256 _offerId)
        external
        noReentrancy
        isOfferValidForWithdrawal(_offerId)
    {
        address msgSender = msg.sender;

        StructOffer storage offerAccount = _mappingOffer[_offerId];

        require(
            msgSender == offerAccount.sender,
            "Only offer creator can withdrawOffer."
        );

        for (uint8 i; i < offerAccount.offeredERC721.length; i++) {
            IERC721(offerAccount.offeredERC721[i].erc721Contract).transferFrom(
                address(this),
                offerAccount.sender,
                offerAccount.offeredERC721[i].erc721Id
            );
        }

        for (uint8 i; i < offerAccount.offeredERC1155.length; i++) {
            IERC1155(offerAccount.offeredERC1155[i].erc1155Contract)
                .safeTransferFrom(
                    address(this),
                    offerAccount.sender,
                    offerAccount.offeredERC1155[i].erc1155Id,
                    offerAccount.offeredERC1155[i].amount,
                    offerAccount.offeredERC1155[i].data
                );
        }

        if (offerAccount.offeredETH > 0) {
            payable(offerAccount.sender).transfer(offerAccount.offeredETH);
        }

        if (
            offerAccount.offeredERC20.erc20Contract != address(0) &&
            offerAccount.offeredERC20.erc20Value > 0
        ) {
            IERC20(offerAccount.offeredERC20.erc20Contract).transfer(
                offerAccount.sender,
                offerAccount.offeredERC20.erc20Value
            );
        }

        offerAccount.status = OfferStatus.withdrawan;

        emit Status(offerAccount, OfferStatus.withdrawan);
    }

    function getOfferById(uint256 _offerId)
        public
        view
        returns (StructOffer memory)
    {
        return _mappingOffer[_offerId];
    }

    function userOffers(address _userAddress)
        external
        view
        returns (
            uint256[] memory offersCreated,
            uint256[] memory offersReceived
        )
    {
        StructAccount memory userAccount = _mappingAccounts[_userAddress];
        offersCreated = userAccount.offersCreated;
        offersReceived = userAccount.offersReceived;
    }

    function allOffersCount() external view returns (uint256 offersCount) {
        if (_offerIds > 0) {
            offersCount = _offerIds + 1;
        }
    }

    function _isBalanceExcludedFromFees(address _userAddress)
        private
        view
        returns (bool _isExcluded)
    {
        address[] memory excludedContractsList = _excludedFeesContracts;
        if (excludedContractsList.length > 0) {
            for (uint8 i; i < excludedContractsList.length; ++i) {
                if (
                    IERC721(excludedContractsList[i]).balanceOf(_userAddress) >
                    0
                ) {
                    _isExcluded = true;
                    break;
                }
            }
        }
    }

    function getFeesExcludedList() external view returns (address[] memory) {
        return _excludedFeesContracts;
    }

    function includeInFees(address _contractAddress) external onlyOwner {
        address[] memory excludedContractsList = _excludedFeesContracts;

        if (excludedContractsList.length > 0) {
            for (uint8 i; i < excludedContractsList.length; ++i) {
                if (_excludedFeesContracts[i] == _contractAddress) {
                    _excludedFeesContracts[i] ==
                        _excludedFeesContracts[
                            _excludedFeesContracts.length - 1
                        ];
                    _excludedFeesContracts.pop();

                    emit IncludedFromFees(_contractAddress);
                    break;
                }
            }
        }
    }

    function excludeFromExchangeFees(address _contractAddress)
        external
        onlyOwner
    {
        address[] memory excludedContractsList = _excludedFeesContracts;

        if (excludedContractsList.length > 0) {
            for (uint8 i; i < excludedContractsList.length; ++i) {
                if (_excludedFeesContracts[i] == _contractAddress) {
                    revert("Contract already in exempted list.");
                }
            }
        }

        _excludedFeesContracts.push(_contractAddress);
        emit ExecludedFromFees(_contractAddress);
    }

    function getFees() external view returns (uint256) {
        return _fees;
    }

    function setFees(uint256 _feesInWei) external onlyOwner {
        emit ExchangeFeesUpdated(_fees, _feesInWei);
        _fees = _feesInWei;
    }

    function getFeesCollected()
        external
        view
        returns (
            uint256 feesCollected,
            uint256 feesClaimed,
            uint256 feesPendingToClaim
        )
    {
        feesCollected = _feesCollected;
        feesClaimed = _feesClaimed;
        feesPendingToClaim = _feesCollected - _feesClaimed;
    }

    function claimFees() external noReentrancy onlyOwner {
        uint256 pendingFees = _feesCollected - _feesClaimed;
        require(pendingFees > 0, "No fees to claimed");
        _feesClaimed += pendingFees;

        payable(owner()).transfer(pendingFees);

        emit FeesClaimedByAdmin(pendingFees);
    }
}
