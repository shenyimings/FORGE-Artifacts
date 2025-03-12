//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./SBTEnumerable.sol";

contract Badge is SBTEnumerable, AccessControl {
    using Counters for Counters.Counter;

    // Badge SBT ids are composed of two parts:
    // 1. tokenType: the type of the badge
    // 2. tokenId: the id of the badge
    // The tokenType is a uint16, and the tokenId is a uint64
    struct BadgeInfo {
        uint16 tokenType;
        uint64 tokenId;
    }

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    string private __baseURI;

    // Record the number of badges of each type
    mapping(uint16 => Counters.Counter) _tokenIds;

    // badge-type => badge-id => owner
    mapping(uint16 => mapping(uint64 => address)) badge2address;

    // owner => badge-type => badge-id
    mapping(address => mapping(uint16 => uint64)) address2badge;

    // badge-type => badge-id => issued-time
    mapping(address => mapping(uint16 => uint256)) issuedTimestamp;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI,
        address _admin
    ) SBTEnumerable(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _admin);
        __baseURI = baseURI;
    }

    /********** Query Functions **********/
    /**
     * Get Badge SBTs owned by an address
     * @param x The address to query
     */
    function getBadgesOf(address x)
        public
        view
        returns (BadgeInfo[] memory badges)
    {
        uint256 balance = balanceOf(x);
        badges = new BadgeInfo[](balance);
        for (uint256 index = 0; index < balance; index++) {
            uint256 tokenId = tokenOfOwnerByIndex(x, index);
            badges[index] = _decomposeTokenId(tokenId);
        }
    }

    /**
     * Get the Badge SBT of a specific type owned by an address
     * @param x The address to query
     * @param tokenType The type of the Badge SBT
     */
    function getBadgeOf(address x, uint16 tokenType)
        public
        view
        returns (uint64)
    {
        return address2badge[x][tokenType];
    }

    /**
     * Get the owner of a Badge SBT
     * @param tokenType The type of the Badge SBT
     * @param tokenId The ID of the Badge SBT
     */
    function getOwnerOf(uint16 tokenType, uint64 tokenId)
        public
        view
        returns (address)
    {
        return badge2address[tokenType][tokenId];
    }

    /**
     * Get the issued time of a Badge SBT
     * @param x The address to query
     * @param tokenType The type of the Badge SBT
     */
    function getIssuedTime(address x, uint16 tokenType)
        public
        view
        returns (uint256)
    {
        return issuedTimestamp[x][tokenType];
    }

    /********** Operator-only Functions **********/
    /// @dev Sets the base token URI prefix.
    function setBaseURI(string memory newURI) public onlyRole(OPERATOR_ROLE) {
        __baseURI = newURI;
    }

    /**
     * Issue a badge to an address
     * @param recipient The address to receive the badge
     * @param tokenType The type of the badge
     */
    function issueBadge(address recipient, uint16 tokenType)
        external
        onlyRole(OPERATOR_ROLE)
    {
        _issueBadge(recipient, tokenType);
    }

    /**
     * Revoke a badge from an address 
     * @param owner The address to revoke the badge from
     * @param tokenType The type of the badge
     * @param tokenId The ID of the badge
     */
    function revokeBadge(
        address owner,
        uint16 tokenType,
        uint64 tokenId
    ) external onlyRole(OPERATOR_ROLE) {
        require(
            badge2address[tokenType][tokenId] == owner &&
                address2badge[owner][tokenType] == tokenId,
            "Badge: cannot revoke badge"
        );
        badge2address[tokenType][tokenId] = address(0);
        address2badge[owner][tokenType] = uint64(0);

        _burn(_composeTokenId(tokenType, tokenId));
    }

    /********** Delegated Functions **********/
    /**
     * Claim a badge by providing a signature
     * @param recipient The address to receive the badge
     * @param tokenType The type of the badge
     * @param signature The signature to be verified
     */
    function claimBadge(
        address recipient,
        uint16 tokenType,
        bytes calldata signature,
        uint256 expire
    ) external {
        // 1. Check not expired
        require(expire > block.timestamp, "Badge: signature expired");
        
        // 2. Check the validity of the signature
        bytes32 inputHash = _getInputHash(recipient, tokenType, expire);
        address signer = _recoverSigner(inputHash, signature);
        require(
            hasRole(OPERATOR_ROLE, signer),
            "Badge: signer does not have operator role"
        );

        // 3. mint the badge
        _issueBadge(recipient, tokenType);
    }

    /********** Internal Functions **********/
    function _baseURI() internal view override returns (string memory) {
        return __baseURI;
    }

    function _issueBadge(address recipient, uint16 tokenType) internal {
        uint64 newTokenId = _newTokenId(tokenType);

        require(
            badge2address[tokenType][newTokenId] == address(0) &&
                address2badge[recipient][tokenType] == uint64(0),
            "Badge: cannot issue badge"
        );
        badge2address[tokenType][newTokenId] = recipient;
        address2badge[recipient][tokenType] = newTokenId;

        _safeMint(recipient, _composeTokenId(tokenType, newTokenId));

        issuedTimestamp[recipient][tokenType] = block.timestamp;
    }

    // Utility functions for token ID
    function _composeTokenId(uint16 tokenType, uint64 tokenId)
        internal
        pure
        returns (uint256)
    {
        return (uint256(tokenType) << 64) | uint256(tokenId);
    }

    function _decomposeTokenId(uint256 tokenId)
        internal
        pure
        returns (BadgeInfo memory info)
    {
        info.tokenType = uint16(tokenId >> 64);
        info.tokenId = uint64(tokenId);
    }

    // Helper functions for signature verification
    function _getInputHash(address recipient, uint16 tokenType, uint256 expire)
        internal
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    expire,
                    recipient,
                    tokenType,
                    block.chainid,
                    address(this)
                )
            );
    }

    function _recoverSigner(bytes32 hash, bytes memory sig)
        internal
        pure
        returns (address)
    {
        return ECDSA.recover(_getEthSignedMessageHash(hash), sig);
    }

    function _getEthSignedMessageHash(bytes32 criteriaMessageHash)
        internal
        pure
        returns (bytes32)
    {
        return ECDSA.toEthSignedMessageHash(criteriaMessageHash);
    }

    /**
     * Get the next token ID of a badge type
     * @param tokenType The type of the badge to get the next token ID
     */
    function _newTokenId(uint16 tokenType)
        internal
        returns (uint64 newTokenId)
    {
        Counters.Counter storage tokenId = _tokenIds[tokenType];
        tokenId.increment();
        newTokenId = uint64(tokenId.current());
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(SBTEnumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
