//SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract RecoroadContract is ERC1155, ERC2981, Ownable, Pausable {
    string public name; // Contract name
    string public symbol; // Contract symbol
    uint256 public tokenCount; // Number of tokens

    string private _contract; // Contract metadata
    mapping(uint256 => string) private _uris; // Mapping from token ID to metadata uri
    mapping(uint256 => uint256) private _curSupply; // Mapping from token ID to current supply
    mapping(uint256 => uint256) private _maxSupply; // Mapping from token ID to maximum supply

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        address _address,
        uint96 _royalty
    ) ERC1155(_uri) {
        console.log("Deploying a RecoroadContract with name:", _name);
        name = _name;
        symbol = _symbol;
        _contract = _uri;
        _setDefaultRoyalty(_address, _royalty); // Define contract royalty
        tokenCount = 0;
    }

    // Fix supported interfaces
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /* @dev Implement metadata URI (contract-level / token-level) */

    function contractURI() public view returns (string memory) {
        return _contract;
    }

    function uri(uint256 _id) public view override returns (string memory) {
        return _uris[_id];
    }

    function _setMetadataURI(uint256 _id, string memory _uri) internal onlyOwner {
        require(bytes(_uris[_id]).length == 0, "REC: metadata uri already exists");
        _uris[_id] = _uri;
    }

    /* @dev Implement emergency stop mechanism */

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /* @dev Implement token supply */

    function _setCurSupply(uint256 _id, uint256 _supply) internal onlyOwner {
        _curSupply[_id] = _curSupply[_id] + _supply;
    }

    function maxSupply(uint256 _id) public view returns (uint256) {
        return _maxSupply[_id];
    }

    function _setMaxSupply(uint256 _id, uint256 _supply) internal onlyOwner {
        require(_maxSupply[_id] == 0, "REC: max supply already exists");
        _maxSupply[_id] = _supply;
    }

    function createToken(
        address _creator,
        uint256 _supply,
        string memory _uri,
        uint256 _amount,
        bytes memory _data,
        address _address,
        uint96 _royalty
    ) public onlyOwner {
        require(_supply == 0 || _amount <= _supply, "REC: supply overflow");
        uint256 tokenId = tokenCount + 1;
        _mint(_creator, tokenId, _amount, _data);
        _setMetadataURI(tokenId, _uri);
        _setCurSupply(tokenId, _amount);
        _setMaxSupply(tokenId, _supply);
        if (_address != address(0)) _setTokenRoyalty(tokenId, _address, _royalty); // Define token royalty
        tokenCount = tokenId;
    }

    function createBatchToken(
        address _creator,
        uint256[] memory _supply,
        string[] memory _uri,
        uint256[] memory _amount,
        bytes memory _data,
        address[] memory _address,
        uint96[] memory _royalty
    ) public onlyOwner {
        require(
            _supply.length == _uri.length &&
                _uri.length == _amount.length &&
                _amount.length == _address.length &&
                _address.length == _royalty.length,
            "REC: param length mismatch"
        );

        for (uint256 i = 0; i < _uri.length; i++) {
            require(_supply[i] == 0 || _amount[i] <= _supply[i], "REC: supply overflow");
        }

        uint256[] memory _id = new uint256[](_uri.length);
        for (uint256 i = 0; i < _uri.length; i++) {
            _id[i] = tokenCount + 1 + i;
        }

        _mintBatch(_creator, _id, _amount, _data);

        for (uint256 i = 0; i < _uri.length; i++) {
            _setMetadataURI(_id[i], _uri[i]);
            _setCurSupply(_id[i], _amount[i]);
            _setMaxSupply(_id[i], _supply[i]);
            if (_address[i] != address(0)) _setTokenRoyalty(_id[i], _address[i], _royalty[i]); // Define token royalty
        }

        tokenCount = _id[_uri.length - 1];
    }

    function addSupply(
        address _creator,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) public onlyOwner {
        require(0 < _id && _id <= tokenCount, "REC: token not found");
        require(_maxSupply[_id] == 0 || _curSupply[_id] + _amount <= _maxSupply[_id], "REC: supply overflow");
        _mint(_creator, _id, _amount, _data);
        _setCurSupply(_id, _amount);
    }
}
