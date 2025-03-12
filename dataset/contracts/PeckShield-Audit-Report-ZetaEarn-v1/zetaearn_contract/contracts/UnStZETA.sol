// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";

import "./interfaces/IUnStZETA.sol";
import "./interfaces/IStZETA.sol";

contract UnStZETA is 
    IUnStZETA,
    OwnableUpgradeable,
    ERC721Upgradeable,
    ERC721PausableUpgradeable
{
    /// @notice stZETA address.
    address public stZETA;

    /// @notice tokenId index.
    uint256 public tokenIdIndex;

    /// @notice Version.
    string public version;

    /// @notice Map addresses to owned token arrays.
    mapping(address => uint256[]) public owner2Tokens;

    /// @notice token to index.
    mapping(uint256 => uint256) public token2Index;

    /// @notice Map addresses to approved token arrays.
    mapping(address => uint256[]) public address2Approved;

    /// @notice TokenId to approved index.
    mapping(uint256 => uint256) public tokenId2ApprovedIndex;

    /// @notice Modifier that can only be called by the stZETA contract.
    modifier isStZETA() {
        require(msg.sender == stZETA, "not stZETA");
        _;
    }

    /// @notice Initialization function.
    function initialize(string memory name_, string memory symbol_, address _stZETA) external initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __Ownable_init_unchained();
        __ERC721_init(name_, symbol_);
        __ERC721Pausable_init();

        // Set stZETA contract address.
        stZETA = _stZETA;
        // Set version.
        version = "1.0.5";
    }

    /// @notice mint a new NFT.
    /// @param _to - to address.
    /// @return Index of the minted token.
    function mint(address _to) external override isStZETA returns (uint256) {
        _mint(_to, ++tokenIdIndex);
        return tokenIdIndex;
    }

    /// @notice Burn NFT.
    /// @param _tokenId - ID of the token to be burned.
    function burn(uint256 _tokenId) external override isStZETA {
        _burn(_tokenId);
    }

    /// @notice Override the approve function.
    /// @param _to - Address to approve the token to.
    /// @param _tokenId - ID of the token to be approved.
    function approve(address _to, uint256 _tokenId)
        public
        override(ERC721Upgradeable, IERC721Upgradeable) {
        // If this token was approved before, remove it from the mapping of approvals.
        address approvedAddress = getApproved(_tokenId);
        if (approvedAddress != address(0)) {
            _removeApproval(_tokenId, approvedAddress);
        }
        // Call the approve function of the parent class.
        super.approve(_to, _tokenId);
        // Get the approved token array.
        uint256[] storage approvedTokens = address2Approved[_to];

        // Add the new approved token to the mapping.
        approvedTokens.push(_tokenId);
        tokenId2ApprovedIndex[_tokenId] = approvedTokens.length - 1;
    }

    /// @notice Override _beforeTokenTransfer.
    /// @param from - from address.
    /// @param to - to address.
    /// @param tokenId - ID of the token.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    )
        internal
        virtual
        override(ERC721Upgradeable, ERC721PausableUpgradeable)
        whenNotPaused {
        // Check if from and to are different.
        require(from != to, "Invalid operation");
        // Call the _beforeTokenTransfer function of the parent class.
        super._beforeTokenTransfer(from, to, tokenId, batchSize);

        // Minting
        if (from == address(0)) {
            // Get the owner's token.
            uint256[] storage ownerTokens = owner2Tokens[to];
            // Add the token to the owner's token.
            ownerTokens.push(tokenId);
            token2Index[tokenId] = ownerTokens.length - 1;
        }
        // Burning
        else if (to == address(0)) {
            // Get the owner's token.
            uint256[] storage ownerTokens = owner2Tokens[from];
            // Get the length of the owner's token.
            uint256 ownerTokensLength = ownerTokens.length;
            // Get the index of the token in the owner's token.
            uint256 burnedTokenIndexInOwnerTokens = token2Index[tokenId];
            // Get the index of the last token in the owner's token.
            uint256 lastOwnerTokensIndex = ownerTokensLength - 1;
            // If the token to be burned is not the last token in the owner's token.
            if (
                burnedTokenIndexInOwnerTokens != lastOwnerTokensIndex &&
                ownerTokensLength != 1
            ) {
                uint256 lastOwnerTokenId = ownerTokens[lastOwnerTokensIndex];
                // update token to index.
                token2Index[lastOwnerTokenId] = burnedTokenIndexInOwnerTokens;
                // update owner token.
                ownerTokens[burnedTokenIndexInOwnerTokens] = lastOwnerTokenId;
            }
            ownerTokens.pop();
            delete token2Index[tokenId];

            address approvedAddress = getApproved(tokenId);
            if (approvedAddress != address(0)) {
                _removeApproval(tokenId, approvedAddress);
            }
        }
        // Transferring
        else if (from != to) {
            address approvedAddress = getApproved(tokenId);
            if (approvedAddress != address(0)) {
                _removeApproval(tokenId, approvedAddress);
            }

            uint256[] storage senderTokens = owner2Tokens[from];
            uint256[] storage receiverTokens = owner2Tokens[to];

            uint256 tokenIndex = token2Index[tokenId];

            uint256 ownerTokensLength = senderTokens.length;
            uint256 removeTokenIndexInOwnerTokens = tokenIndex;
            uint256 lastOwnerTokensIndex = ownerTokensLength - 1;

            if (
                removeTokenIndexInOwnerTokens != lastOwnerTokensIndex &&
                ownerTokensLength != 1
            ) {
                uint256 lastOwnerTokenId = senderTokens[lastOwnerTokensIndex];
                // update token to index.
                token2Index[lastOwnerTokenId] = removeTokenIndexInOwnerTokens;
                // update sender token.
                senderTokens[removeTokenIndexInOwnerTokens] = lastOwnerTokenId;
            }
            senderTokens.pop();

            receiverTokens.push(tokenId);
            token2Index[tokenId] = receiverTokens.length - 1;
        }
    }

    /// @notice Check if the spender is the owner or if the tokenId has been approved to them.
    /// @param _spender - Address to be checked.
    /// @param _tokenId - Token ID to be checked with _spender.
    function isApprovedOrOwner(address _spender, uint256 _tokenId)
        external
        view
        override
        returns (bool) {
        return _isApprovedOrOwner(_spender, _tokenId);
    }

    /// @notice set stZETA address.
    /// @param _newStZETA new stZETA address.
    function setStZETA(address _newStZETA) external override onlyOwner {
        address oldStZETA = stZETA;
        stZETA = _newStZETA;
        emit SetStZETA(oldStZETA, _newStZETA);
    }

    /// @notice set new version
    /// @param _newVersion new version
    function setVersion(string memory _newVersion) external override onlyOwner {
        string memory oldVersion = version;
        version = _newVersion;
        emit SetVersion(oldVersion, _newVersion);
    }

    /// @notice Retrieve the owned token array.
    /// @param _address - Address to retrieve tokens from.
    /// @return - Owned token array.
    function getOwnedTokens(address _address)
        external
        view
        override
        returns (uint256[] memory) {
        return owner2Tokens[_address];
    }

    /// @notice Retrieve the approved token array.
    /// @param _address - Address to retrieve tokens from.
    /// @return - Approved token array.
    function getApprovedTokens(address _address)
        external
        view
        returns (uint256[] memory) {
        return address2Approved[_address];
    }

    /// @notice Remove approved.
    /// @param _tokenId - ID of the token to be removed.
    /// @param _approvedAddress - Address to be removed.
    function _removeApproval(uint256 _tokenId, address _approvedAddress) internal {
        uint256[] storage approvedTokens = address2Approved[_approvedAddress];
        uint256 removeApprovedTokenIndexInOwnerTokens = tokenId2ApprovedIndex[
            _tokenId
        ];
        uint256 approvedTokensLength = approvedTokens.length;
        uint256 lastApprovedTokensIndex = approvedTokensLength - 1;

        if (
            removeApprovedTokenIndexInOwnerTokens != lastApprovedTokensIndex &&
            approvedTokensLength != 1
        ) {
            uint256 lastApprovedTokenId = approvedTokens[
                lastApprovedTokensIndex
            ];
            // Update the approved token index.
            tokenId2ApprovedIndex[
                lastApprovedTokenId
            ] = removeApprovedTokenIndexInOwnerTokens;
            // Update the approved token.
            approvedTokens[
                removeApprovedTokenIndexInOwnerTokens
            ] = lastApprovedTokenId;
        }

        approvedTokens.pop();
        delete tokenId2ApprovedIndex[_tokenId];
    }

    /// @notice Toggle the pause status.
    function togglePause() external override onlyOwner {
        paused() ? _unpause() : _pause();
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal pure override returns (string memory) {
        return "https://zeta-server.zetaearn.com/tokens/";
    }

    /// @notice Get the version for each update.
    /// @return version - Version.
    function getUpdateVersion() external pure override returns(string memory) {
        return "1.0.5";
    }

    /// @notice check tokenid exists
    /// @param tokenId token id.
    /// @return result return result
    function exists(uint256 tokenId) public view override returns (bool) {
        return _exists(tokenId);
    }
}