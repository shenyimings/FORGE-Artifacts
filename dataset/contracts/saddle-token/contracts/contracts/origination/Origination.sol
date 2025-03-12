// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "./modERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// contract for minting custom NFTs
contract Origination is
    Initializable,
    ERC1155Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    string public templateURI;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURI;

    // Mapping for whether a token URI is set permanently
    mapping(uint256 => bool) private _isPermanentURI;
    mapping(uint256 => address) internal _creatorOverride;

    event PermanentURI(string _value, uint256 indexed _id);
    event CreatorChanged(uint256 indexed _id, address indexed _creator);

    modifier onlyTokenAmountOwned(
        address _from,
        uint256 _id,
        uint256 _quantity
    ) {
        require(
            _ownsTokenAmount(_from, _id, _quantity),
            "Origination#onlyTokenAmountOwned: ONLY_TOKEN_AMOUNT_OWNED_ALLOWED"
        );
        _;
    }

    /**
     * @dev Require the URI to be impermanent
     */
    modifier onlyImpermanentURI(uint256 _id) {
        require(!isPermanentURI(_id), "Origination#onlyImpermanentURI: URI_CANNOT_BE_CHANGED");
        _;
    }

    /**
     * @dev Require msg.sender to be the creator of the token _id
     */
    modifier creatorOnly(uint256 _id) {
        require(creator(_id) == _msgSender(), "Origination#creatorOnly: ONLY_CREATOR_ALLOWED");
        _;
    }

    /**
     * @dev Require the caller to own the full supply of the token
     */
    modifier onlyFullTokenOwner(uint256 _id) {
        require(
            _ownsTokenAmount(_msgSender(), _id, tokenMaxSupply(_id)),
            "Origination#onlyFullTokenOwner: ONLY_FULL_TOKEN_OWNER_ALLOWED"
        );
        _;
    }

    function initialize() public initializer {
        // boilerplate base URI
        __Ownable_init();
        __ReentrancyGuard_init();
        __ERC1155_init("");
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function nftComVersion() public pure returns (string memory) {
        return "1.0.0";
    }

    /**
     * @dev Change the creator address for given token
     * @param _to   Address of the new creator
     * @param _id  Token IDs to change creator of
     */
    function setCreator(uint256 _id, address _to) public creatorOnly(_id) {
        require(_to != address(0), "Origination#setCreator: INVALID_ADDRESS.");
        _creatorOverride[_id] = _to;
        emit CreatorChanged(_id, _to);
    }

    /**
     * @dev Get the creator for a token
     * @param _id   The token _id to look up
     */
    function creator(uint256 _id) public view returns (address) {
        if (_creatorOverride[_id] != address(0)) {
            return _creatorOverride[_id];
        } else {
            return origin(_id);
        }
    }

    /**
     * @dev Require _from to own a specified quantity of the token
     */
    function _ownsTokenAmount(
        address _from,
        uint256 _id,
        uint256 _quantity
    ) internal view returns (bool) {
        return balanceOf(_from, _id) >= _quantity;
    }

    /**
     * Compat for factory interfaces on OpenSea
     * Indicates that this contract can return balances for
     * tokens that haven't been minted yet
     */
    function supportsFactoryInterface() public pure returns (bool) {
        return true;
    }

    function setTemplateURI(string memory _uri) public onlyOwner {
        templateURI = _uri;
    }

    function setURI(uint256 _id, string memory _uri)
        public
        creatorOnly(_id)
        onlyImpermanentURI(_id)
        onlyFullTokenOwner(_id)
    {
        _setURI(_id, _uri);
    }

    function setPermanentURI(uint256 _id, string memory _uri)
        public
        creatorOnly(_id)
        onlyImpermanentURI(_id)
        onlyFullTokenOwner(_id)
    {
        _setPermanentURI(_id, _uri);
    }

    function isPermanentURI(uint256 _id) public view returns (bool) {
        return _isPermanentURI[_id];
    }

    function uri(uint256 _id) public view override returns (string memory) {
        string memory tokenUri = _tokenURI[_id];
        if (bytes(tokenUri).length != 0) {
            return tokenUri;
        }
        return templateURI;
    }

    function balanceOf(address _owner, uint256 _id) public view virtual override returns (uint256) {
        uint256 balance = super.balanceOf(_owner, _id);

        // if you are owner of token, get full balance
        return creator(_id) == _owner ? balance + _remainingSupply(_id) : balance;
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) public override {
        uint256 mintedBalance = super.balanceOf(_from, _id);
        if (mintedBalance < _amount) {
            // Only mint what _from doesn't already have
            mint(_to, _id, _amount - mintedBalance, _data);
            if (mintedBalance > 0) {
                super.safeTransferFrom(_from, _to, _id, mintedBalance, _data);
            }
        } else {
            super.safeTransferFrom(_from, _to, _id, _amount, _data);
        }
    }

    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) public override {
        require(_ids.length == _amounts.length, "Origination#safeBatchTransferFrom: INVALID_ARRAYS_LENGTH");
        for (uint256 i = 0; i < _ids.length; i++) {
            safeTransferFrom(_from, _to, _ids[i], _amounts[i], _data);
        }
    }

    function burn(
        address _from,
        uint256 _id,
        uint256 _quantity
    ) public onlyTokenAmountOwned(_from, _id, _quantity) {
        _burn(_from, _id, _quantity);
    }

    function batchBurn(
        address _from,
        uint256[] memory _ids,
        uint256[] memory _quantities
    ) public {
        for (uint256 i = 0; i < _ids.length; i++) {
            require(
                _ownsTokenAmount(_from, _ids[i], _quantities[i]),
                "Origination#batchBurn: ONLY_TOKEN_AMOUNT_OWNED_ALLOWED"
            );
        }
        _burnBatch(_from, _ids, _quantities);
    }

    // overrides virtual function in modERC1155Upgradeable
    function _beforeMint(uint256 _id, uint256 _quantity) internal view override {
        require(_quantity <= _remainingSupply(_id), "Origination#_beforeMint: QUANTITY_EXCEEDS_TOKEN_SUPPLY_CAP");
    }

    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) public nonReentrant creatorOnly(_id) {
        super._mint(_to, _id, _quantity, _data);
        if (_data.length > 1) {
            _setURI(_id, string(_data));
        }
    }

    function _remainingSupply(uint256 _id) internal view returns (uint256) {
        return tokenMaxSupply(_id) - totalSupply(_id);
    }

    function batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) public nonReentrant {
        for (uint256 i = 0; i < _ids.length; i++) {
            require(creator(_ids[i]) == _msgSender(), "Origination#batchMint: ONLY_CREATOR_ALLOWED");
        }
        _batchMint(_to, _ids, _quantities, _data);
    }

    function _batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) internal virtual {
        _mintBatch(_to, _ids, _quantities, _data);
        if (_data.length > 1) {
            for (uint256 i = 0; i < _ids.length; i++) {
                _setURI(_ids[i], string(_data));
            }
        }
    }

    function _setURI(uint256 _id, string memory _uri) internal {
        _tokenURI[_id] = _uri;
        emit URI(_uri, _id);
    }

    function _setPermanentURI(uint256 _id, string memory _uri) internal virtual {
        require(bytes(_uri).length > 0, "Origination#setPermanentURI: ONLY_VALID_URI");
        _isPermanentURI[_id] = true;
        _setURI(_id, _uri);
        emit PermanentURI(_uri, _id);
    }
}
