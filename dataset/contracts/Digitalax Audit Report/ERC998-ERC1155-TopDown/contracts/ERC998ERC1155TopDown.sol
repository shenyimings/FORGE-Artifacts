// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.0;

/*
// for remix
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/IERC1155Receiver.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155Receiver.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/EnumerableSet.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/EnumerableMap.sol";
*/

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/EnumerableMap.sol";

import "./IERC998ERC1155TopDown.sol";

contract ERC998ERC1155TopDown is ERC721, ERC1155Receiver, IERC998ERC1155TopDown {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) private _balances;
    mapping(address => mapping(uint256 => EnumerableSet.UintSet)) private _holdersOf;

    mapping(uint256 => EnumerableSet.AddressSet) private _childContract;
    mapping(uint256 => mapping(address => EnumerableSet.UintSet)) private _childsForChildContract;

    constructor(string memory name, string memory symbol, string memory baseURI) ERC721(name, symbol) public {
        _setBaseURI(baseURI);
    }

    function childBalance(uint256 tokrnId, address childContract, uint256 childTokenId) external view override returns(uint256) {
        return _balances[tokrnId][childContract][childTokenId];
    }

    function childContractsFor(uint256 tokenId) override external view returns (address[] memory) {
        address[] memory childContracts = new address[](_childContract[tokenId].length());

        for(uint256 i = 0; i < _childContract[tokenId].length(); i++) {
            childContracts[i] = _childContract[tokenId].at(i);
        }

        return childContracts;
    }

    function childIdsForOn(uint256 tokenId, address childContract) override external view returns (uint256[] memory) {
        uint256[] memory childTokenIds = new uint256[](_childsForChildContract[tokenId][childContract].length());

        for(uint256 i = 0; i < _childsForChildContract[tokenId][childContract].length(); i++) {
            childTokenIds[i] = _childsForChildContract[tokenId][childContract].at(i);
        }

        return childTokenIds;
    }

    function safeTransferChildFrom(uint256 fromTokenId, address to, address childContract, uint256 childTokenId, uint256 amount, bytes memory data) public override {
        require(to != address(0), "ERC998: transfer to the zero address");

        address operator = _msgSender();
        require(
            ownerOf(fromTokenId) == operator ||
            isApprovedForAll(ownerOf(fromTokenId), operator),
            "ERC998: caller is not owner nor approved"
        );

        // TODO: sender is owner || operator for sender ||  approved Address for sender
        /* require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        */
        _beforeChildTransfer(operator, fromTokenId, to, childContract, _asSingletonArray(childTokenId), _asSingletonArray(amount), data);

        _removeChild(fromTokenId, childContract, childTokenId, amount);

        // TODO: maybe check if to == this
        ERC1155(childContract).safeTransferFrom(address(this), to, childTokenId, amount, data);
        TransferSingleChild(fromTokenId, to, childContract, childTokenId, amount);
    }

    function safeBatchTransferChildFrom(uint256 fromTokenId, address to, address childContract, uint256[] memory childTokenIds, uint256[] memory amounts, bytes memory data) public override {
        require(childTokenIds.length == amounts.length, "ERC998: ids and amounts length mismatch");
        require(to != address(0), "ERC998: transfer to the zero address");

        address operator = _msgSender();
        require(
            ownerOf(fromTokenId) == operator ||
            isApprovedForAll(ownerOf(fromTokenId), operator),
            "ERC998: caller is not owner nor approved"
        );

        _beforeChildTransfer(operator, fromTokenId, to, childContract, childTokenIds, amounts, data);

        for (uint256 i = 0; i < childTokenIds.length; ++i) {
            uint256 childTokenId = childTokenIds[i];
            uint256 amount = amounts[i];

            _removeChild(fromTokenId, childContract, childTokenId, amount);
        }
        ERC1155(childContract).safeBatchTransferFrom(address(this), to, childTokenIds, amounts, data);
        TransferBatchChild(fromTokenId, to, childContract, childTokenIds, amounts);
    }

    function onERC1155Received(address operator, address from, uint256 id, uint256 amount, bytes memory data) virtual public override returns(bytes4) {
        require(data.length == 32, "ERC998: data must contain the unique uint256 tokenId to transfer the child token to");
        _beforeChildTransfer(operator, 0, address(this), from, _asSingletonArray(id), _asSingletonArray(amount), data);

        uint256 _receiverTokenId;
        uint256 _index = msg.data.length - 32;
        assembly {_receiverTokenId := calldataload(_index)}

        _receiveChild(_receiverTokenId, msg.sender, id, amount);
        ReceivedChild(from, _receiverTokenId, msg.sender, id, amount);

        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address operator, address from, uint256[] memory ids, uint256[] memory values, bytes memory data) virtual public override returns(bytes4) {
        require(data.length == 32, "ERC998: data must contain the unique uint256 tokenId to transfer the child token to");
        require(ids.length == values.length, "ERC1155: ids and values length mismatch");
        _beforeChildTransfer(operator, 0, address(this), from, ids, values, data);

        uint256 _receiverTokenId;
        uint256 _index = msg.data.length - 32;
        assembly {_receiverTokenId := calldataload(_index)}
        for(uint256 i = 0; i < ids.length; i++) {
            _receiveChild(_receiverTokenId, msg.sender, ids[i], values[i]);
            ReceivedChild(from, _receiverTokenId, msg.sender, ids[i], values[i]);
        }
        return this.onERC1155BatchReceived.selector;
    }

    function _receiveChild(uint256 tokenId, address childContract, uint256 childTokenId, uint256 amount) private {
        if(!_childContract[tokenId].contains(childContract)) {
            _childContract[tokenId].add(childContract);
        }
        if(_balances[tokenId][childContract][childTokenId] == 0) {
            _childsForChildContract[tokenId][childContract].add(childTokenId);
        }
        _balances[tokenId][childContract][childTokenId] += amount;
    }

    function _removeChild(uint256 tokenId, address childContract, uint256 childTokenId, uint256 amount) private {
        require(amount != 0 || _balances[tokenId][childContract][childTokenId] >= amount, "ERC998: insufficient child balance for transfer");
        _balances[tokenId][childContract][childTokenId] -= amount;
        if(_balances[tokenId][childContract][childTokenId] == 0) {
            _holdersOf[childContract][childTokenId].remove(tokenId);
            _childsForChildContract[tokenId][childContract].remove(childTokenId);
            if(_childsForChildContract[tokenId][childContract].length() == 0) {
                _childContract[tokenId].remove(childContract);
            }
        }
    }

    function _beforeChildTransfer(
        address operator,
        uint256 fromTokenId,
        address to,
        address childContract,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal virtual
    { }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}
