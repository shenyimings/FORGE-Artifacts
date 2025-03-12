// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../tokens/ERC721/NftToken.sol";
import "../tokens/ERC721/NftTokenBox.sol";
import "../tokens/ERC721/NftTokenToyo.sol";
import "../factory/NftTokenStorage.sol";
import "./NftTokenSwapStorage.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NftTokenSwap is AccessControl, Ownable, Pausable, ReentrancyGuard {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using Strings for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    NftToken public token;
    NftTokenToyo public tokenToyo;
    NftTokenBox public tokenBox;
    NftTokenStorage public tokenStorage;
    NftTokenSwapStorage public tokenSwapStorage;

    /**
     * Event for token purchase logging
     * @param spender who paid for the tokens
     * @param beneficiary who got the tokens
     * @param typeId of the token sold
     * @param totalSupply of the token type included the purchase that trigger the event
     * @param tokenId of the token type sold
     * @param value in wei involved in the purchase
     */
    event TokenPurchased(
        address indexed spender,
        address indexed beneficiary,
        uint256 indexed typeId,
        uint256 totalSupply,
        uint256 tokenId,
        uint256 value
    );

    event TokenSwapped(address indexed sender, uint256 indexed fromTypeId, uint256 indexed toTypeId, uint256 fromTokenId, uint256 toTokenId);
    event TokenSwapChanged(uint256 fromTypeId, uint256 quantityToMint);
    event TokenSwapMappingChanged(
        uint256 fromTypeId,
        uint256 order,
        uint256 toTypeId
    );

    event TokenChanged(NftToken indexed toToken);
    event TokenToyoChanged(NftTokenToyo indexed toToken);
    event TokenBoxChanged(NftTokenBox indexed toToken);
    event TokenStorageChanged(NftTokenStorage indexed toToken);
    event TokenSwapStorageChanged(NftTokenSwapStorage indexed toToken);

    /**
     * @param _token Address of the token being sold from old collection
     * @param _tokenToyo Address of the token toyo being sold from new collection
     * @param _tokenBox Address of the token box being sold from bew collection
     * @param _tokenStorage Address of the eternal storage contract
     * @param _swapStorage Address of the swap eternal storage contract
     */
    constructor(
        NftToken _token,
        NftTokenToyo _tokenToyo,
        NftTokenBox _tokenBox,
        NftTokenStorage _tokenStorage,
        NftTokenSwapStorage _swapStorage
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);

        token = _token;
        tokenToyo = _tokenToyo;
        tokenBox = _tokenBox;
        tokenStorage = _tokenStorage;
        tokenSwapStorage = _swapStorage;
    }

    function swapToken(
        address _sender,
        uint256 _tokenId,
        uint256 _typeId
    )
        public
        payable
        nonReentrant
        isValidAddress(_sender)
        isValidTokenType(_typeId)
        whenNotPaused
    {
        if(tokenBox.exists(_tokenId))
        {
            require(tokenBox.ownerOf(_tokenId) == _sender, "You do not own this tokenId (new collection)");

            string memory tokenMetadata = tokenBox.tokenURI(_tokenId);

            validateTypeOwnership(_typeId, tokenMetadata);

            tokenBox.burn(_tokenId);
        }
        else
        {
            require(token.ownerOf(_tokenId) == _sender, "You do not own this tokenId (old collection)");

            string memory tokenMetadata = token.tokenURI(_tokenId);

            validateTypeOwnership(_typeId, tokenMetadata);

            token.transferFrom(msg.sender, address(this), _tokenId);
        }

        uint256 _total = getTokenSwapQuantity(_typeId);

        for (uint256 _order = 1; _order <= _total; _order++) {
            uint256 _toTypeId = getTokenSwapMapping(_typeId, _order);
            bool byToken = hasMetadataByToken(_typeId, _order);
            uint256 newTokenId = _deliverTokens(msg.sender, _toTypeId, byToken);

            emit TokenSwapped(msg.sender, _typeId, _toTypeId, _tokenId, newTokenId);
        }
    }

    function validateTypeOwnership(
         uint256 _typeId,
         string memory tokenMetadata
    )
    internal view
    {
        string memory typeMetadata = tokenStorage.getMetadata(_typeId);

        require(
            keccak256(abi.encodePacked(tokenMetadata)) ==
                keccak256(abi.encodePacked(typeMetadata)),
            "You do not own this typeId"
        );
    }

   function tokenURI(uint256 typeId, uint256 tokenId, bool byToken) public view returns (string memory) {
        string memory baseURI = tokenStorage.getMetadata(typeId);
        
        if(byToken) {
            return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
        }

        return baseURI;
    }

    function _deliverTokens(address _spender, uint256 _typeId, bool byToken) 
        internal
        returns (uint256 newTokenId) {
        
        uint256 _wei = msg.value;

        tokenStorage.incrementTokenId();

        uint256 newItemId = tokenStorage.getTotalMinted();
        string memory metadata = tokenURI(_typeId, newItemId, byToken);

        if(byToken){
            tokenToyo.mintWithRoyalties(
                _spender,
                metadata,
                newItemId,
                tokenStorage.royaltiesRecipientAddress(),
                tokenStorage.percentageBasisPoints());
        } else {
            tokenBox.mintWithRoyalties(
                _spender,
                metadata,
                newItemId,
                tokenStorage.royaltiesRecipientAddress(),
                tokenStorage.percentageBasisPoints());
        }

        tokenStorage.incrementTotalSupply(_typeId);

        tokenStorage.incrementBalance(_spender, _typeId);

        emit TokenPurchased(
                msg.sender,
                _spender,
                _typeId,
                tokenStorage.getTotalSupply(_typeId),
                newItemId,
                _wei
            );
            
        return newItemId;
    }

    function hasMetadataByToken(uint256 _fromTypeId, uint256 _order)
        public
        view
        returns (bool metadataByToken)
    {
        return tokenSwapStorage.hasMetadataByToken(_fromTypeId, _order);
    }

    function getTokenSwapQuantity(uint256 _fromTypeId)
        public
        view
        returns (uint256)
    {
        return tokenSwapStorage.getTokenSwapQuantity(_fromTypeId);
    }

    function getTokenSwapMapping(uint256 _fromTypeId, uint256 _order)
        public
        view
        returns (uint256 toTypeId)
    {
        return tokenSwapStorage.getTokenSwapMapping(_fromTypeId, _order);
    }

    // -----------------------------------------
    // Public only DEFAULT_ADMIN_ROLE
    // -----------------------------------------

    function setToken(NftToken _token)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        token = _token;

        emit TokenChanged(_token);
    }

    function setTokenStorage(NftTokenStorage _tokenStorage)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        tokenStorage = _tokenStorage;

        emit TokenStorageChanged(_tokenStorage);
    }

    function setTokenSwapStorage(NftTokenSwapStorage _tokenSwapStorage)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        tokenSwapStorage = _tokenSwapStorage;

        emit TokenSwapStorageChanged(_tokenSwapStorage);
    }

    function setTokenToyo(NftTokenToyo _tokenToyo)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        tokenToyo = _tokenToyo;

        emit TokenToyoChanged(_tokenToyo);
    }

    function setTokenBox(NftTokenBox _tokenBox)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        tokenBox = _tokenBox;

        emit TokenBoxChanged(_tokenBox);
    }

    function setTokenSwapMapping(
        uint256 _fromTypeId,
        uint256 _order,
        uint256 _toTypeId,
        bool _metadataByToken
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenSwapStorage.setTokenSwapMapping(_fromTypeId, _order, _toTypeId, _metadataByToken);

        emit TokenSwapMappingChanged(_fromTypeId, _order, _toTypeId);
    }

    function setTokenSwapQuantity(uint256 _fromTypeId, uint256 _quantityToMint)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        tokenSwapStorage.setTokenSwapQuantity(_fromTypeId, _quantityToMint);

        emit TokenSwapChanged(_fromTypeId, _quantityToMint);
    }

    // -----------------------------------------
    // Public onlyPauser
    // -----------------------------------------

    function pauseAll() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpauseAll() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // -----------------------------------------
    // Internal
    // -----------------------------------------

    modifier isValidAddress(address _address) {
        _isValidAddress(_address);
        _;
    }

    modifier isValidTokenType(uint256 _typeId) {
        _isValidTokenType(_typeId);
        _;
    }

    function _isValidAddress(address _address) internal pure {
        require(_address != address(0), "Invalid address");
    }

    function _isValidTokenType(uint256 _typeId) internal view {
        require(
            bytes(tokenStorage.getMetadata(_typeId)).length != 0,
            "Token type does not exist"
        );
    }
}
