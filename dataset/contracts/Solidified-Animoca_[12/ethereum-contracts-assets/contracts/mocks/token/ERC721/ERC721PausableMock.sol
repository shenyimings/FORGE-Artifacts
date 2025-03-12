// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {ERC721BurnableMock} from "./ERC721BurnableMock.sol";
import {Pausable} from "@animoca/ethereum-contracts-core-1.1.1/contracts/lifecycle/Pausable.sol";

contract ERC721PausableMock is Pausable, ERC721BurnableMock {
    constructor() Pausable(false) {}

    //================================== Pausable =======================================/

    function pause() external virtual {
        _requireOwnership(_msgSender());
        _pause();
    }

    function unpause() external virtual {
        _requireOwnership(_msgSender());
        _unpause();
    }

    //================================== ERC721 =======================================/

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        _requireNotPaused();
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        _requireNotPaused();
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        _requireNotPaused();
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function batchTransferFrom(
        address from,
        address to,
        uint256[] memory tokenIds
    ) public virtual override {
        _requireNotPaused();
        super.batchTransferFrom(from, to, tokenIds);
        require(to != address(0), "ERC721: transfer to zero");
    }

    function burnFrom(address from, uint256 tokenId) public virtual override {
        _requireNotPaused();
        super.burnFrom(from, tokenId);
    }

    /**
     * Burns a batch of token.
     * @dev See {IERC721Burnable-batchBurnFrom(address,uint256[])}.
     */
    function batchBurnFrom(address from, uint256[] memory tokenIds) public virtual override {
        _requireNotPaused();
        super.batchBurnFrom(from, tokenIds);
    }
}
