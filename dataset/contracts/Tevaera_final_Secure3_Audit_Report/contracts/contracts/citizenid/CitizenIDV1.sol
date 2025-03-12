// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

/// @title A Citizen ID contract
/// @author Tevaera Labs
/// @notice Users need to mint the Citizen ID to become a Tevan
/// @dev It extends ERC721 standard
contract CitizenIDV1 is
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable for uint256;

    //// @dev the claim contract address
    address public claimContract;
    //// @dev true, if the owner permits claiming of KPs for the time being
    bool public canClaim = false;
    /// @dev the token price in ETH
    uint256 public tokenPrice;

    CountersUpgradeable.Counter private tokenIdCounter;

    /// @dev the rep admin address
    address private repAdminAddress;

    /// @dev the safe address
    address payable private safeAddress;

    /// @dev the list of blacklisted wallet addresses
    mapping(address => bool) public blacklisted;

    /// @dev the list of token id -> rep score
    mapping(address => uint256) public tevanRep;

    /// @dev the token image uri
    string private tokenImageUri;

    /// @dev check if the caller is the claim contract
    modifier onlyClaim() {
        require(msg.sender == claimContract, "not accessible");
        _;
    }

    /// @dev check if the caller is the rep admin
    modifier onlyRepAdmin() {
        require(msg.sender == repAdminAddress, "not accessible");
        _;
    }

    event RepScoreUpdated(uint256 indexed tokenId, uint256 repScore);

    /// @dev Initializes the upgradable contract
    /// @param _tokenImageUri the token base uri
    /// @param _tokenPrice the token base price
    function initialize(
        string memory _tokenImageUri,
        uint256 _tokenPrice
    ) external initializer nonReentrant {
        __ERC721_init("CitizenID", "TEVAN");
        __ERC721Enumerable_init();
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        tokenImageUri = _tokenImageUri;
        tokenPrice = _tokenPrice;

        // increament the counter
        tokenIdCounter.increment();
    }

    /// @dev Allows owner to blacklist any wallet address across Tevaera platform
    /// @param addresses the list of wallet addresses that need to be blocked
    function blacklistAddresses(address[] memory addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            if (!blacklisted[addresses[i]]) {
                blacklisted[addresses[i]] = true;
            }
        }
    }

    /// @dev Allows owner to remove any wallet address from the blacklist
    /// @param addresses the list of wallet addresses that need to be unblocked
    function removeFromBlacklist(
        address[] memory addresses
    ) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            if (blacklisted[addresses[i]]) {
                blacklisted[addresses[i]] = false;
            }
        }
    }

    /// @dev Mints the Citizen ID
    function mintToken(address tevan) internal whenNotPaused nonReentrant {
        // make sure caller has not already minted the citizen id
        require(balanceOf(tevan) == 0, "Already a Tevan!");
        // make sure caller not blacklisted
        require(!blacklisted[tevan], "Tevan Blacklisted!");
        // price validation
        require(msg.value == tokenPrice, "Invalid amount");

        // mint
        mint(tevan);
    }

    /// @dev Mints the Citizen ID
    function mintCitizenId() external payable whenNotPaused {
        mintToken(msg.sender);
    }

    /// @dev Mints the Citizen ID
    function claim(address tevan) external payable onlyClaim whenNotPaused {
        mintToken(tevan);
    }

    /// @dev Allows owner to pause sale if active
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /// @dev Allows owner to acticvate sale
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    /// @dev An internal function to perfom actual mint
    /// @param to a wallet address against which minting is being performed
    function mint(address to) internal {
        // update the counter
        uint256 tokenId = tokenIdCounter.current();
        tokenIdCounter.increment();
        // mint
        _mint(to, tokenId);
        // update token uri
        _setTokenURI(tokenId, getTokenURI(tokenId, 0));
    }

    /// @dev Gets the tier based on the REP score
    /// @param rep the rep score
    function getTier(uint256 rep) internal pure returns (string memory) {
        if (rep > 100000) return "GUARDIAN";
        if (rep > 50000 && rep <= 100000) return "OG";
        if (rep > 20000 && rep <= 50000) return "DIAMOND";
        if (rep > 10000 && rep <= 20000) return "PLATINUM";
        if (rep > 5000 && rep <= 10000) return "GOLD";
        if (rep > 2000 && rep <= 5000) return "SILVER";
        return "BRONZE";
    }

    function getTokenURI(
        uint256 tokenId,
        uint256 repScore
    ) internal view returns (string memory) {
        bytes memory dataURI = abi.encodePacked(
            "{",
            '"name": "Tevan #',
            tokenId.toString(),
            '",',
            '"description": "Citizen ID gives you access to all Tevaera products, including free-to-play games. Each citizen can only have one permanent residency.",',
            '"external_url": "https://tevaera.com",',
            '"image": "',
            tokenImageUri,
            '",',
            '"attributes": [{"trait_type":"Tier", "value": "',
            getTier(repScore),
            '"}, {"display_type":"number", "trait_type":"Reputation Score", "value": "',
            repScore.toString(),
            '"}]',
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

    /// @dev Sets the token base uri
    /// @param _tokenImageUri the token base uri
    function setTokenImageUri(
        string memory _tokenImageUri
    ) external onlyOwner whenNotPaused {
        tokenImageUri = _tokenImageUri;
    }

    /// @dev Sets the token price
    /// @param _tokenPrice the token price in ETH
    function setTokenPrice(
        uint256 _tokenPrice
    ) external onlyOwner whenNotPaused {
        tokenPrice = _tokenPrice;
    }

    /// @dev Allows owner to update claim capability
    /// @param _claimContract the claim contract address
    /// @param _canClaim a flag to indicate whether to enable or disable the capability
    function updateClaimCapability(
        address _claimContract,
        bool _canClaim
    ) external onlyOwner {
        claimContract = _claimContract;
        canClaim = _canClaim;
    }

    /// @dev Allows owner to update the rep score of the user
    /// @param _tokenIds a list of citizen/token ids
    /// @param _reps a list of rep scores
    function updateRep(
        uint256[] memory _tokenIds,
        uint256[] memory _reps
    ) external onlyRepAdmin {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            uint256 rep = _reps[i];

            // update token uri (metadata)
            _setTokenURI(tokenId, getTokenURI(tokenId, rep));

            tevanRep[ownerOf(tokenId)] = rep;

            emit RepScoreUpdated(tokenId, rep);
        }
    }

    /// @dev Allows owner to update the rep admin wallet address
    /// @param _repAdminAddress the rep admin wallet address
    function updateRepAdminAddress(
        address _repAdminAddress
    ) external onlyOwner {
        require(_repAdminAddress != address(0), "Invalid address!");
        repAdminAddress = _repAdminAddress;
    }

    /// @dev Allows owner to update the safe wallet address
    /// @param _safeAddress the safe wallet address
    function updateSafeAddress(
        address payable _safeAddress
    ) external onlyOwner {
        require(_safeAddress != address(0), "Invalid address!");
        safeAddress = _safeAddress;
    }

    /// @dev Withdraws funds from this contract to safe address
    function withdrawFunds() external onlyOwner {
        require(safeAddress != address(0), "Missing safe address!");
        require(safeAddress.send(address(this).balance));
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
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
        require(from == address(0), "Token not transferable");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
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
