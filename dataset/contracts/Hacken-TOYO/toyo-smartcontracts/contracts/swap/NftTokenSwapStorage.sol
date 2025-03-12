// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NftTokenSwapStorage is AccessControl, Ownable {
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    struct tokenSwap {
        uint256 toTypeId;
        bool hasMetadataByToken;
    }

    mapping(uint256 => uint256) private _tokenSwapQuantity;
    mapping(uint256 => mapping(uint256 => tokenSwap)) private _tokenSwapMapping;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function getTokenSwapQuantity(uint256 _fromTypeId)
        public
        view
        returns (uint256)
    {
        return (_tokenSwapQuantity[_fromTypeId]);
    }

    function getTokenSwapMapping(uint256 _fromTypeId, uint256 _order)
        public
        view
        returns (uint256 toTypeId)
    {
        return (_tokenSwapMapping[_fromTypeId][_order].toTypeId);
    }

    function hasMetadataByToken(uint256 _fromTypeId, uint256 _order)
        public
        view
        returns (bool metadataByToken)
    {
        return (_tokenSwapMapping[_fromTypeId][_order].hasMetadataByToken);
    }

    function setTokenSwapQuantity(
        uint256 _fromTypeId, 
        uint256 _quantityToMint)
        public
        onlyRole(MINTER_ROLE)
    {
        _tokenSwapQuantity[_fromTypeId] = _quantityToMint;
    }

    function setTokenSwapMapping(
        uint256 _fromTypeId, 
        uint256 _order,
        uint256 _toTypeId,
        bool _metadataByToken)
        public
        onlyRole(MINTER_ROLE)
    {
        _tokenSwapMapping[_fromTypeId][_order].toTypeId = _toTypeId;
        _tokenSwapMapping[_fromTypeId][_order].hasMetadataByToken = _metadataByToken;
    }
}
