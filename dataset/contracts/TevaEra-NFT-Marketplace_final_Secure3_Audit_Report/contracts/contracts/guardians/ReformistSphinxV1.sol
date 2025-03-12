// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import "../citizenid/CitizenIDV1.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

/// @title ReformistSphinx NFT contract
/// @author Tevaera Labs
/// @notice Allows users to mint the guardian NFT of ReformistSphinx
/// @dev It extends ERC721 and ERC2981 standards
contract ReformistSphinxV1 is
    ERC721RoyaltyUpgradeable,
    ERC721URIStorageUpgradeable,
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable for uint256;

    CitizenIDV1 private citizenIdContract;
    CountersUpgradeable.Counter private tokenIdCounter;

    modifier isNotBlacklisted() {
        require(
            !citizenIdContract.blacklisted(msg.sender),
            "Tevan Blacklisted!"
        );
        _;
    }

    modifier isTevan() {
        require(citizenIdContract.balanceOf(msg.sender) > 0, "Not a Tevan");
        _;
    }

    string public tokenImageUri;

    mapping(address => bool) private addressToHasMintedMap;

    /// @dev Initializes the upgradable contract
    /// @param _citizenIdContract the citizen id contract address
    /// @param _tokenImageUri the token image uri
    function initialize(
        CitizenIDV1 _citizenIdContract,
        string calldata _tokenImageUri
    ) external initializer {
        __ERC721_init("ReformistSphinx", "SPHINX");
        __ERC721Enumerable_init();
        __ERC721Royalty_init();
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        citizenIdContract = _citizenIdContract;
        tokenImageUri = _tokenImageUri;

        // increament the counter
        tokenIdCounter.increment();

        // set default royalty to 5%
        _setDefaultRoyalty(msg.sender, 500);
    }

    /// @dev Mints Guardian NFT
    function mint()
        external
        isTevan
        isNotBlacklisted
        whenNotPaused
        nonReentrant
    {
        // make sure caller has not already minted
        require(addressToHasMintedMap[msg.sender] == false, "already minted");

        // get the token id & update the counter
        uint256 tokenId = tokenIdCounter.current();
        tokenIdCounter.increment();

        // mint the guardian nft
        _mint(msg.sender, tokenId);

        // mark address as minted
        addressToHasMintedMap[msg.sender] = true;

        // set the token uri
        _setTokenURI(tokenId, getTokenURI(tokenId));
    }

    /// @dev Sets the token base uri
    /// @param _tokenImageUri the token base uri
    function setTokenImageUri(
        string calldata _tokenImageUri
    ) external onlyOwner whenNotPaused {
        tokenImageUri = _tokenImageUri;
    }

    // ----- system default functions -----

    /// @dev Allows owner to pause sale if active
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /// @dev Allows owner to acticvate sale
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    function _burn(
        uint256 tokenId
    )
        internal
        override(
            ERC721Upgradeable,
            ERC721RoyaltyUpgradeable,
            ERC721URIStorageUpgradeable
        )
    {
        super._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function getTokenURI(
        uint256 tokenId
    ) internal view returns (string memory) {
        bytes memory dataURI = abi.encodePacked(
            "{",
            '"name": "Reformist Sphinx #',
            tokenId.toString(),
            '",',
            '"description": "The Reformist Guardian, who is seen as a symbol of change & wisdom. Sphinxes keep a track of all past events and help people escape to a new gamified world to experience their imaginations.",',
            '"external_url": "https://tevaera.com",',
            '"image": "',
            tokenImageUri,
            '",',
            '"attributes": [{"trait_type":"Guardian", "value": "Sphinx"}, {"trait_type":"Skin", "value": "Brown"}]',
            "}"
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64Upgradeable.encode(dataURI)
                )
            );
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(
            ERC721Upgradeable,
            ERC721RoyaltyUpgradeable,
            ERC721EnumerableUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}
