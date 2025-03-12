// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract ArtisticJeweller is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdCounter;

    // issue A.4 solved
    uint128 public constant MAX_BPS = 10_000;

    address payable public PlatformAddress;
    uint128 public PlatformFee;
    struct NFTData {
        string jsonData;
        uint128 nftRoyalty;
        address royaltyAddress;
        address nftCreator;
    }

    event NFTsData(
        string jsonData,
        uint128 nftRoyalty,
        address royaltyAddress,
        address nftCreator
    );

    mapping(uint256 => NFTData) public storeData;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _platformReciverAddr,
        uint128 _platformCuts
    ) public initializer {
        __ERC721_init("ArtisticJeweller", "AJ");
        __Pausable_init();
        __Ownable_init();
        __ERC721Burnable_init();
        __UUPSUpgradeable_init();

        PlatformFee = _platformCuts;
        PlatformAddress = payable(_platformReciverAddr);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    // issue A.1 solved
    // function _beforeTokenTransfer(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) internal override whenNotPaused {
    //     super._beforeTokenTransfer(from, to, tokenId);
    // }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    modifier NFTOwner(uint256 tokenIdCounter) {
        require(
            ownerOf(tokenIdCounter) == msg.sender,
            "Caller is not the NFT Owner"
        );
        _;
    }

    modifier NFTCreator(uint256 tokenIdCounter) {
        require(
            storeData[tokenIdCounter].nftCreator == msg.sender,
            "Caller is not the NFT Creator"
        );
        _;
    }

    // ----------------- MyOwn Functions -------------------  //
    function mintNFT(
        address to,
        string memory _json,
        uint128 _nftRoyalty,
        address _royaltyAddress
    ) public {
        uint256 tokenIdCounter = uint256(_tokenIdCounter.current());
        storeData[tokenIdCounter].jsonData = _json;
        storeData[tokenIdCounter].nftRoyalty = _nftRoyalty;
        storeData[tokenIdCounter].royaltyAddress = _royaltyAddress;
        storeData[tokenIdCounter].nftCreator = msg.sender;

        // issue A.3 solved
        // require(msg.sender != address(0), "Zero address");

        // Mint NFT
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    // nft owner can burn nft via this address
    function burnNFT(uint256 tokenIdCounter) public NFTOwner(tokenIdCounter) {
        storeData[tokenIdCounter].jsonData = "";
        storeData[tokenIdCounter].nftRoyalty = 0;
        storeData[tokenIdCounter].royaltyAddress = address(0);
        storeData[tokenIdCounter].nftCreator = address(0);
        burn(tokenIdCounter);
    }

    // only owner can update NFTjson data etc using this function
    function updateNFTJsonData(
        uint256 tokenIdCounter,
        string memory _jsonData
    ) public NFTOwner(tokenIdCounter) {
        storeData[tokenIdCounter].jsonData = _jsonData;
    }

    // only Admin can update platform details
    function updatePlatformDetails(
        address _platformReciverAddr,
        uint128 _platformCuts
    ) public onlyOwner {
        PlatformFee = _platformCuts;
        PlatformAddress = payable(_platformReciverAddr);
    }

    // only NFT Creator can change NFT Royalty Detials
    function updateNFTRoyalty(
        uint256 tokenIdCounter,
        uint128 _royaltyFee,
        address _royaltyAddress
    ) public NFTCreator(tokenIdCounter) {
        storeData[tokenIdCounter].nftRoyalty = _royaltyFee;
        storeData[tokenIdCounter].royaltyAddress = _royaltyAddress;
    }

    // issue A.5 solved
    // return total nft count
    function getTotalNFTCount() external view returns (uint256) {
        return uint256(_tokenIdCounter.current());
    }

    // issue A.5 second one solved
    // get Royalty Details by NFT Id
    function getRoyaltyAndPlatformFeeDetails(
        uint256 _nftId
    ) external view returns (uint256, address, uint256, address) {
        return (
            storeData[_nftId].nftRoyalty,
            storeData[_nftId].royaltyAddress,
            PlatformFee,
            PlatformAddress
        );
    }
}
