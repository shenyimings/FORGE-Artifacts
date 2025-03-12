//SPDX-License-Identifier: None
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./ERC721AUpgradeable.sol";

contract DKeeperNFT is
    ERC721AUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    string public baseTokenURI;

    uint8 public maxPublicMintForEach;
    uint8 public MAX_OWNER_SUPPLY;

    uint256 public MAX_SUPPLY;

    uint256 public priceForEach;
    uint256 public maxPriceForEach;

    address payable public treasure;

    uint256 public publicMinted;
    uint256 public ownerMinted;

    uint96 public constant ROYALTY_PERCENT = 75;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    mapping(address => uint8) public publicMintSpotBought;
    mapping(uint256 => uint256) public mintedPrice;

    RoyaltyInfo private _defaultRoyaltyInfo;
    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "Only wallet can call function");
        _;
    }

    modifier notOverMaxSupply(uint256 _amount) {
        require(_amount + totalSupply() <= MAX_SUPPLY, "Max supply limit exceeded");
        _;
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        address treasure_
    ) public initializer {
        require(treasure_ != address(0), "Invalid treasure address");

        __ReentrancyGuard_init();
        __ERC721A_init(name_, symbol_);
        __Ownable_init();

        maxPublicMintForEach = 1;

        MAX_SUPPLY = maxSupply_;
        MAX_OWNER_SUPPLY = 50;

        treasure = payable(treasure_);
        priceForEach = 0.5 ether;
        maxPriceForEach = 2 ether;
    }

    // Mint for team
    function ownerMint(uint256 _amount) external onlyOwner notOverMaxSupply(_amount) {
        require(ownerMinted + _amount <= MAX_OWNER_SUPPLY, "Max owner supply limit exceeded");
        ownerMinted += _amount;

        for (uint256 i = _currentIndex; i <= _currentIndex + _amount; i++) {
            _setTokenRoyalty(i, msg.sender, ROYALTY_PERCENT);
            mintedPrice[i] = maxPriceForEach;
        }
        _mint(_msgSender(), _amount);
    }

    // Mint for Early Supporters
    function publicMint(uint8 _amount)
        external
        payable
        onlyEOA
        nonReentrant
        notOverMaxSupply(_amount)
    {
        require(
            publicMinted + _amount <= MAX_SUPPLY - MAX_OWNER_SUPPLY,
            "Max public mint supply limited"
        );
        require(
            _amount + publicMintSpotBought[_msgSender()] <= maxPublicMintForEach,
            "Max Public Mint Spot Bought"
        );
        require(
            msg.value >= priceForEach * _amount && msg.value <= maxPriceForEach * _amount,
            "Pay Exact Amount"
        );

        publicMintSpotBought[_msgSender()] += _amount;
        publicMinted += _amount;

        for (uint256 i = _currentIndex; i <= _currentIndex + _amount; i++) {
            _setTokenRoyalty(i, msg.sender, ROYALTY_PERCENT);
            mintedPrice[i] = msg.value / _amount;
        }

        _mint(_msgSender(), _amount);
    }

    ///@dev withdraw funds from contract to treasure
    function withdraw() external onlyOwner {
        require(treasure != address(0), "Treasure address not set");
        treasure.transfer(address(this).balance);
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        require(bytes(baseURI_).length > 0, "Invalid base URI");
        baseTokenURI = baseURI_;
    }

    function setTreasure(address _treasure) external onlyOwner {
        require(_treasure != address(0), "Invalid address for signer");
        treasure = payable(_treasure);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == _INTERFACE_ID_ERC2981 || super.supportsInterface(interfaceId);
    }

    /////////////////
    /// Set Price ///
    /////////////////

    function setPublicMintPriceForEach(uint256 _price) external onlyOwner {
        priceForEach = _price;
    }

    ///////////////
    /// Set Max ///
    ///////////////

    function setMaxPublicMintForEach(uint8 _amount) external onlyOwner {
        maxPublicMintForEach = _amount;
    }

    function setMaxSupply(uint256 amount) external onlyOwner {
        require(MAX_SUPPLY >= totalSupply(), "Invalid max supply number");
        MAX_SUPPLY = amount;
    }

    ///@dev Toggle contract pause
    function togglePause() external onlyOwner {
        if (paused()) {
            _unpause();
        } else {
            _pause();
        }
    }

    ///@dev Override Function
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    ///////////////
    /// Royalty ///
    ///////////////

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        public
        view
        returns (address, uint256)
    {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[_tokenId];

        if (royalty.receiver == address(0)) {
            royalty = _defaultRoyaltyInfo;
        }

        uint256 royaltyAmount = (_salePrice * royalty.royaltyFraction) / _feeDenominator();

        return (royalty.receiver, royaltyAmount);
    }

    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    function _setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: Invalid parameters");

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override whenNotPaused {
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }
}
