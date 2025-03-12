// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/////////////////////////////////////////////////
//  ____                        _   _          //
// | __ )    ___    _ __     __| | | |  _   _  //
// |  _ \   / _ \  | '_ \   / _` | | | | | | | //
// | |_) | | (_) | | | | | | (_| | | | | |_| | //
// |____/   \___/  |_| |_|  \__,_| |_|  \__, | //
//                                      |___/  //
/////////////////////////////////////////////////

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract BondlyLaunchPad is Ownable {
    using SafeERC20 for IERC20;
    using MerkleProof for bytes32[];

    uint256 public _currentCardId = 0;
    address payable public _salesperson;
    bool public _saleStarted = false;

    struct Card {
        uint256 cardId;
        uint256 tokenId;
        uint256 totalAmount;
        uint256 currentAmount;
        uint256 basePrice;
        uint256 saleNumber;
        address contractAddress;
        address paymentToken;
        bool isFinished;
    }

    struct History {
        mapping(uint256 => mapping(address => uint256)) purchasedHistories; // cardId -> wallet -> amount
    }

    // Events
    event CreateCard(
        address indexed _from,
        uint256 _cardId,
        address indexed _contractAddress,
        uint256 _tokenId,
        uint256 _totalAmount,
        uint256 _basePrice,
        uint256 _saleNumber,
        address paymentToken
    );

    event PurchaseCard(address indexed _from, uint256 _cardId, uint256 _amount);
    event CardChanged(uint256 _cardId);

    mapping(uint256 => Card) public _cards;
    mapping(uint256 => mapping(uint256 => uint256)) public _cardLimitsPerWallet;
    mapping(uint256 => mapping(uint256 => uint256)) public _saleLimitsPerWallet;
    mapping(uint256 => mapping(uint256 => uint256)) public _saleTierTimes;
    mapping(uint256 => uint256) public _saleTierQuantity;
    mapping(address => bool) public _blacklist;
    mapping(uint256 => bytes32) public _whitelistRoot;
    mapping(uint256 => bool) public _salePublicCheck;

    History private _cardHistory;
    History private _saleHistory;

    constructor() {
        _salesperson = payable(msg.sender);
    }

    function setSalesPerson(address payable newSalesPerson) external onlyOwner {
        _salesperson = newSalesPerson;
    }

    function startSale() external onlyOwner {
        _saleStarted = true;
    }

    function stopSale() external onlyOwner {
        _saleStarted = false;
    }

    function createCard(
        address _contractAddress,
        uint256 _tokenId,
        uint256 _totalAmount,
        uint256 _saleNumber,
        address _paymentTokenAddress,
        uint256 _basePrice,
        uint256[] calldata _limitsPerWallet
    ) external onlyOwner {
        IERC1155 _contract = IERC1155(_contractAddress);
        require(
            _contract.balanceOf(_salesperson, _tokenId) >= _totalAmount,
            "Initial supply cannot be more than available supply"
        );
        require(
            _contract.isApprovedForAll(_salesperson, address(this)) == true,
            "Contract must be whitelisted by owner"
        );
        uint256 _id = _getNextCardID();
        _incrementCardId();
        Card memory _newCard;
        _newCard.cardId = _id;
        _newCard.contractAddress = _contractAddress;
        _newCard.tokenId = _tokenId;
        _newCard.totalAmount = _totalAmount;
        _newCard.currentAmount = _totalAmount;
        _newCard.basePrice = _basePrice;
        _newCard.paymentToken = _paymentTokenAddress;
        _newCard.saleNumber = _saleNumber;
        _newCard.isFinished = false;

        _cards[_id] = _newCard;

        _setCardLimitsPerWallet(_id, _limitsPerWallet);

        emit CreateCard(
            msg.sender,
            _id,
            _contractAddress,
            _tokenId,
            _totalAmount,
            _basePrice,
            _saleNumber,
            _paymentTokenAddress
        );
    }

    function isEligbleToBuy(
        uint256 _cardId,
        uint256 tier,
        bytes32[] calldata whitelistProof
    ) public view returns (uint256) {
        if (_blacklist[msg.sender] == true) return 0;

        if (_saleStarted == false) return 0;

        Card memory _currentCard = _cards[_cardId];

        if (_salePublicCheck[_currentCard.saleNumber]) {
            if (
                !verifyWhitelist(
                    msg.sender,
                    _currentCard.saleNumber,
                    tier,
                    whitelistProof
                )
            ) {
                return 0;
            }
        } else {
            if (
                tier != 0 &&
                !verifyWhitelist(
                    msg.sender,
                    _currentCard.saleNumber,
                    tier,
                    whitelistProof
                )
            ) {
                return 0;
            }
        }

        uint256 startTime = _saleTierTimes[_currentCard.saleNumber][tier];

        if (startTime != 0 && block.timestamp >= startTime) {
            uint256 _currentCardBoughtAmount = _cardHistory.purchasedHistories[
                _cardId
            ][msg.sender];
            uint256 _cardLimitPerWallet = _cardLimitsPerWallet[_cardId][tier];

            if (_currentCardBoughtAmount >= _cardLimitPerWallet) return 0;

            uint256 _currentSaleBoughtAmount = _saleHistory.purchasedHistories[
                _currentCard.saleNumber
            ][msg.sender];
            uint256 _saleLimitPerWallet = _saleLimitsPerWallet[
                _currentCard.saleNumber
            ][tier];
            if (_currentSaleBoughtAmount >= _saleLimitPerWallet) return 0;

            uint256 _cardAvailableForPurchase = _cardLimitPerWallet -
                _currentCardBoughtAmount;
            uint256 _saleAvailableForPurchase = _saleLimitPerWallet -
                _currentSaleBoughtAmount;

            uint256 _availableForPurchase = _cardAvailableForPurchase >
                _saleAvailableForPurchase
                ? _saleAvailableForPurchase
                : _cardAvailableForPurchase;

            if (_currentCard.currentAmount <= _availableForPurchase)
                return _currentCard.currentAmount;

            return _availableForPurchase;
        }

        return 0;
    }

    function purchaseNFT(
        uint256 _cardId,
        uint256 _amount,
        uint256 tier,
        bytes32[] calldata whitelistProof
    ) external payable {
        require(_blacklist[msg.sender] == false, "you are blocked");

        require(_saleStarted == true, "Sale stopped");

        Card memory _currentCard = _cards[_cardId];
        require(_currentCard.isFinished == false, "Card is finished");

        if (_salePublicCheck[_currentCard.saleNumber]) {
            require(
                verifyWhitelist(
                    msg.sender,
                    _currentCard.saleNumber,
                    tier,
                    whitelistProof
                ),
                "Invalid proof for whitelist"
            );
        } else {
            if (tier != 0) {
                require(
                    verifyWhitelist(
                        msg.sender,
                        _currentCard.saleNumber,
                        tier,
                        whitelistProof
                    ),
                    "Invalid proof for whitelist"
                );
            }
        }

        {
            uint256 startTime = _saleTierTimes[_currentCard.saleNumber][tier];
            require(
                startTime != 0 && startTime <= block.timestamp,
                "wait for sale start"
            );
        }
        require(
            _amount != 0 && _currentCard.currentAmount >= _amount,
            "Order exceeds the max number of available NFTs"
        );
        uint256 _availableForPurchase;
        {
            uint256 _currentCardBoughtAmount = _cardHistory.purchasedHistories[
                _cardId
            ][msg.sender];
            uint256 _cardLimitPerWallet = _cardLimitsPerWallet[_cardId][tier];

            uint256 _currentSaleBoughtAmount = _saleHistory.purchasedHistories[
                _currentCard.saleNumber
            ][msg.sender];
            uint256 _saleLimitPerWallet = _saleLimitsPerWallet[
                _currentCard.saleNumber
            ][tier];

            require(
                _currentCardBoughtAmount < _cardLimitPerWallet &&
                    _currentSaleBoughtAmount < _saleLimitPerWallet,
                "Order exceeds the max limit of NFTs per wallet"
            );

            uint256 _cardAvailableForPurchase = _cardLimitPerWallet -
                _currentCardBoughtAmount;
            uint256 _saleAvailableForPurchase = _saleLimitPerWallet -
                _currentSaleBoughtAmount;

            _availableForPurchase = _cardAvailableForPurchase >
                _saleAvailableForPurchase
                ? _saleAvailableForPurchase
                : _cardAvailableForPurchase;

            if (_availableForPurchase > _amount) {
                _availableForPurchase = _amount;
            }

            _cards[_cardId].currentAmount =
                _cards[_cardId].currentAmount -
                _availableForPurchase;

            _cardHistory.purchasedHistories[_cardId][msg.sender] =
                _currentCardBoughtAmount +
                _availableForPurchase;

            _saleHistory.purchasedHistories[_currentCard.saleNumber][
                msg.sender
            ] = _currentSaleBoughtAmount + _availableForPurchase;
        }
        uint256 _price = _currentCard.basePrice * _availableForPurchase;

        require(
            _currentCard.paymentToken == address(0) ||
                IERC20(_currentCard.paymentToken).allowance(
                    msg.sender,
                    address(this)
                ) >=
                _price,
            "Need to Approve payment"
        );

        if (_currentCard.paymentToken == address(0)) {
            require(msg.value >= _price, "Not enough funds to purchase");
            uint256 overPrice = msg.value - _price;
            _salesperson.transfer(_price);

            if (overPrice > 0) payable(msg.sender).transfer(overPrice);
        } else {
            IERC20(_currentCard.paymentToken).transferFrom(
                msg.sender,
                _salesperson,
                _price
            );
        }

        IERC1155(_currentCard.contractAddress).safeTransferFrom(
            _salesperson,
            msg.sender,
            _currentCard.tokenId,
            _availableForPurchase,
            ""
        );

        emit PurchaseCard(msg.sender, _cardId, _availableForPurchase);
    }

    function _getNextCardID() private view returns (uint256) {
        return _currentCardId + 1;
    }

    function _incrementCardId() private {
        _currentCardId++;
    }

    function cancelCard(uint256 _cardId) external onlyOwner {
        _cards[_cardId].isFinished = true;

        emit CardChanged(_cardId);
    }

    function setTier(
        uint256 _saleNumber,
        uint256 _tier,
        uint256 _startTime
    ) external onlyOwner {
        if (_tier + 1 > _saleTierQuantity[_saleNumber]) {
            _saleTierQuantity[_saleNumber] = _tier + 1;
        }
        _saleTierTimes[_saleNumber][_tier] = _startTime;
    }

    function setTiers(uint256 _saleNumber, uint256[] calldata _startTimes)
        external
        onlyOwner
    {
        if (_startTimes.length > _saleTierQuantity[_saleNumber]) {
            _saleTierQuantity[_saleNumber] = _startTimes.length;
        }
        for (uint256 i = 0; i < _startTimes.length; i++) {
            _saleTierTimes[_saleNumber][i] = _startTimes[i];
        }
    }

    function setSaleLimitPerWallet(
        uint256 _saleNumber,
        uint256 _tier,
        uint256 _limitPerWallet
    ) external onlyOwner {
        if (_tier + 1 > _saleTierQuantity[_saleNumber]) {
            _saleTierQuantity[_saleNumber] = _tier + 1;
        }
        _saleLimitsPerWallet[_saleNumber][_tier] = _limitPerWallet;
    }

    function setSaleLimitsPerWallet(
        uint256 _saleNumber,
        uint256[] calldata _limitsPerWallet
    ) external onlyOwner {
        if (_limitsPerWallet.length > _saleTierQuantity[_saleNumber]) {
            _saleTierQuantity[_saleNumber] = _limitsPerWallet.length;
        }
        for (uint256 i = 0; i < _limitsPerWallet.length; i++) {
            _saleLimitsPerWallet[_saleNumber][i] = _limitsPerWallet[i];
        }
    }

    function setCardLimitPerWallet(
        uint256 _cardNumber,
        uint256 _tier,
        uint256 _limitPerWallet
    ) external onlyOwner {
        uint256 saleNumber = _cards[_cardNumber].saleNumber;
        if (_tier + 1 > _saleTierQuantity[saleNumber]) {
            _saleTierQuantity[saleNumber] = _tier + 1;
        }
        _cardLimitsPerWallet[_cardNumber][_tier] = _limitPerWallet;
    }

    function _setCardLimitsPerWallet(
        uint256 _cardNumber,
        uint256[] calldata _limitsPerWallet
    ) private {
        uint256 saleNumber = _cards[_cardNumber].saleNumber;
        if (_limitsPerWallet.length > _saleTierQuantity[saleNumber]) {
            _saleTierQuantity[saleNumber] = _limitsPerWallet.length;
        }
        for (uint256 i = 0; i < _limitsPerWallet.length; i++) {
            _cardLimitsPerWallet[_cardNumber][i] = _limitsPerWallet[i];
        }
    }

    function setCardLimitsPerWallet(
        uint256 _cardNumber,
        uint256[] calldata _limitsPerWallet
    ) external onlyOwner {
        _setCardLimitsPerWallet(_cardNumber, _limitsPerWallet);
    }

    function setCardsLimitsPerWallet(
        uint256[] calldata _cardNumbers,
        uint256[][] calldata _limitsPerWallet
    ) external onlyOwner {
        require(
            _cardNumbers.length == _limitsPerWallet.length,
            "Array input size mismatch"
        );
        for (uint256 i = 0; i < _cardNumbers.length; i++) {
            _setCardLimitsPerWallet(_cardNumbers[i], _limitsPerWallet[i]);
        }
    }

    function resumeCard(uint256 _cardId) external onlyOwner {
        _cards[_cardId].isFinished = false;

        emit CardChanged(_cardId);
    }

    function setCardPrice(uint256 _cardId, uint256 _newPrice)
        external
        onlyOwner
    {
        _cards[_cardId].basePrice = _newPrice;

        emit CardChanged(_cardId);
    }

    function setCardPaymentToken(uint256 _cardId, address _newAddr)
        external
        onlyOwner
    {
        _cards[_cardId].paymentToken = _newAddr;

        emit CardChanged(_cardId);
    }

    function setCardSaleNumber(uint256 _cardId, uint256 _saleNumber)
        external
        onlyOwner
    {
        _cards[_cardId].saleNumber = _saleNumber;

        emit CardChanged(_cardId);
    }

    function addBlackListAddress(address addr) external onlyOwner {
        _blacklist[addr] = true;
    }

    function batchAddBlackListAddress(address[] calldata addr)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < addr.length; i++) {
            _blacklist[addr[i]] = true;
        }
    }

    function removeBlackListAddress(address addr) external onlyOwner {
        _blacklist[addr] = false;
    }

    function batchRemoveBlackListAddress(address[] calldata addr)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < addr.length; i++) {
            _blacklist[addr[i]] = false;
        }
    }

    function setWhitelistRoot(uint256 saleNumber, bytes32 merkleRoot)
        external
        onlyOwner
    {
        _whitelistRoot[saleNumber] = merkleRoot;
    }

    function setWhitelistRoots(
        uint256[] calldata saleNumbers,
        bytes32[] calldata merkleRoots
    ) external onlyOwner {
        require(
            saleNumbers.length == merkleRoots.length,
            "Array input size mismatch"
        );
        for (uint256 i = 0; i < saleNumbers.length; i++) {
            _whitelistRoot[saleNumbers[i]] = merkleRoots[i];
        }
    }

    function setPublicCheck(uint256 saleNumber, bool isCheck)
        external
        onlyOwner
    {
        _salePublicCheck[saleNumber] = isCheck;
    }

    function setPublicChecks(
        uint256[] calldata saleNumbers,
        bool[] calldata isCheck
    ) external onlyOwner {
        require(
            saleNumbers.length == isCheck.length,
            "Array input size mismatch"
        );
        for (uint256 i = 0; i < saleNumbers.length; i++) {
            _salePublicCheck[saleNumbers[i]] = isCheck[i];
        }
    }

    function isCardCompleted(uint256 _cardId) public view returns (bool) {
        return _cards[_cardId].isFinished;
    }

    function isCardFree(uint256 _cardId) public view returns (bool) {
        return _cards[_cardId].basePrice == 0;
    }

    function getCardContract(uint256 _cardId) public view returns (address) {
        return _cards[_cardId].contractAddress;
    }

    function getCardPaymentContract(uint256 _cardId)
        public
        view
        returns (address)
    {
        return _cards[_cardId].paymentToken;
    }

    function getCardTokenId(uint256 _cardId) public view returns (uint256) {
        return _cards[_cardId].tokenId;
    }

    function getTierTimes(uint256 saleNumber)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory times = new uint256[](_saleTierQuantity[saleNumber]);
        for (uint256 i = 0; i < times.length; i++) {
            times[i] = _saleTierTimes[saleNumber][i];
        }
        return times;
    }

    function getSaleLimitsPerWallet(uint256 saleNumber)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory limits = new uint256[](_saleTierQuantity[saleNumber]);
        for (uint256 i = 0; i < limits.length; i++) {
            limits[i] = _saleLimitsPerWallet[saleNumber][i];
        }
        return limits;
    }

    function getCardLimitsPerWallet(uint256 cardNumber)
        public
        view
        returns (uint256[] memory)
    {
        uint256 saleNumber = _cards[cardNumber].saleNumber;
        uint256[] memory limits = new uint256[](_saleTierQuantity[saleNumber]);
        for (uint256 i = 0; i < limits.length; i++) {
            limits[i] = _cardLimitsPerWallet[cardNumber][i];
        }
        return limits;
    }

    function getCardTotalAmount(uint256 _cardId) public view returns (uint256) {
        return _cards[_cardId].totalAmount;
    }

    function getCardCurrentAmount(uint256 _cardId)
        public
        view
        returns (uint256)
    {
        return _cards[_cardId].currentAmount;
    }

    function getAllCardsPerSale(uint256 saleNumber)
        public
        view
        returns (uint256[] memory)
    {
        uint256 count;
        for (uint256 i = 1; i <= _currentCardId; i++) {
            if (_cards[i].saleNumber == saleNumber) {
                count++;
            }
        }

        uint256[] memory cardIds = new uint256[](count);
        count = 0;
        for (uint256 i = 1; i <= _currentCardId; i++) {
            if (_cards[i].saleNumber == saleNumber) {
                cardIds[count] = i;
                count++;
            }
        }

        return cardIds;
    }

    function getAllCardsPerContract(address _contractAddr)
        public
        view
        returns (uint256[] memory, uint256[] memory)
    {
        uint256 count;
        for (uint256 i = 1; i <= _currentCardId; i++) {
            if (_cards[i].contractAddress == _contractAddr) {
                count++;
            }
        }

        uint256[] memory cardIds = new uint256[](count);
        uint256[] memory tokenIds = new uint256[](count);
        count = 0;

        for (uint256 i = 1; i <= _currentCardId; i++) {
            if (_cards[i].contractAddress == _contractAddr) {
                cardIds[count] = i;
                tokenIds[count] = _cards[i].tokenId;
                count++;
            }
        }

        return (cardIds, tokenIds);
    }

    function getActiveCardsPerContract(address _contractAddr)
        public
        view
        returns (uint256[] memory, uint256[] memory)
    {
        uint256 count;
        for (uint256 i = 1; i <= _currentCardId; i++) {
            if (
                _cards[i].contractAddress == _contractAddr &&
                _cards[i].isFinished == false
            ) {
                count++;
            }
        }

        uint256[] memory cardIds = new uint256[](count);
        uint256[] memory tokenIds = new uint256[](count);
        count = 0;

        for (uint256 i = 1; i <= _currentCardId; i++) {
            if (
                _cards[i].contractAddress == _contractAddr &&
                _cards[i].isFinished == false
            ) {
                cardIds[count] = i;
                tokenIds[count] = _cards[i].tokenId;
                count++;
            }
        }

        return (cardIds, tokenIds);
    }

    function getClosedCardsPerContract(address _contractAddr)
        public
        view
        returns (uint256[] memory, uint256[] memory)
    {
        uint256 count;
        for (uint256 i = 1; i <= _currentCardId; i++) {
            if (
                _cards[i].contractAddress == _contractAddr &&
                _cards[i].isFinished
            ) {
                count++;
            }
        }

        uint256[] memory cardIds = new uint256[](count);
        uint256[] memory tokenIds = new uint256[](count);
        count = 0;

        for (uint256 i = 1; i <= _currentCardId; i++) {
            if (
                _cards[i].contractAddress == _contractAddr &&
                _cards[i].isFinished
            ) {
                cardIds[count] = i;
                tokenIds[count] = _cards[i].tokenId;
                count++;
            }
        }

        return (cardIds, tokenIds);
    }

    function getCardBasePrice(uint256 _cardId) public view returns (uint256) {
        return _cards[_cardId].basePrice;
    }

    function getCardURL(uint256 _cardId) public view returns (string memory) {
        return
            IERC1155MetadataURI(_cards[_cardId].contractAddress).uri(
                _cards[_cardId].tokenId
            );
    }

    function collect(address _token) external onlyOwner {
        if (_token == address(0)) {
            payable(msg.sender).transfer(address(this).balance);
        } else {
            uint256 amount = IERC20(_token).balanceOf(address(this));
            IERC20(_token).transfer(msg.sender, amount);
        }
    }

    function verifyWhitelist(
        address user,
        uint256 saleNumber,
        uint256 tier,
        bytes32[] calldata whitelistProof
    ) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user, saleNumber, tier));
        return whitelistProof.verify(_whitelistRoot[saleNumber], leaf);
    }
}
