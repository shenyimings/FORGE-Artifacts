/*
 * Origin Protocol
 * https://originprotocol.com
 *
 * Released under the MIT license
 * SPDX-License-Identifier: MIT
 * https://github.com/OriginProtocol/nft-launchpad
 *
 * Copyright 2022 Origin Protocol, Inc
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Changelog
 * =========
 *
 * v3
 * --
 *
 *  - Adds EIP-2981 support
 *  - Adds modified PaymentSplitter to release to all payees in one call
 */

pragma solidity ^0.8.4;

import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import {ERC721A} from 'erc721a/contracts/ERC721A.sol';
import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import {IERC2981} from '@openzeppelin/contracts/interfaces/IERC2981.sol';

import {PaymentSplitter} from '../utils/PaymentSplitter.sol';

contract OriginERC721a_v3 is PaymentSplitter, AccessControl, IERC2981, ERC721A {
    bytes32 public constant MINTER_ROLE = keccak256('MINTER');
    address public owner;
    uint256 public royaltyBps;
    uint256 public maxSupply;
    string public baseURI;

    /**
     * @param name_ - Name of the collection
     * @param symbol_ - Symbol of the collection
     * @param baseURI_ - The base URI for token metadata
     * @param maxSupply_ - The maximum possible token
     * @param minter_ - EOA that can sign mint requests
     * @param payees_ - Array of accounts that receive proceeds
     * @param shares_ -  Array of amount of shares each payee receives respectively
     * @param royaltyBps_ - Secondary sale royalty (in basis points)
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint256 maxSupply_,
        address minter_,
        address[] memory payees_,
        uint256[] memory shares_,
        uint256 royaltyBps_
    ) ERC721A(name_, symbol_) PaymentSplitter(payees_, shares_) {
        require(maxSupply_ > 0, 'Max supply not set');
        baseURI = baseURI_;
        maxSupply = maxSupply_;
        royaltyBps = royaltyBps_;
        owner = _msgSender();

        _setupRole(DEFAULT_ADMIN_ROLE, owner);

        if (minter_ != address(0)) {
            _setupRole(MINTER_ROLE, minter_);
        } else {
            _setupRole(MINTER_ROLE, _msgSender());
        }
    }

    /**
     * @notice EIP-165 standard interface to check what interfaces this
     *      contract supports.
     * @return If the given interface is supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC721A, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @notice Return URI to contract off-chain metadata
     * @return URI to JSON file
     */
    function contractURI() public view returns (string memory) {
        string memory base = _baseURI();
        return
            bytes(base).length > 0
                ? string(abi.encodePacked(base, 'contract.json'))
                : '';
    }

    /**
     * @notice Return the expected royalty for a token
     * @param - unused but part of the standard
     * @param salePrice - the sale price of the token use to calculate the
     *      royalty for the token sale
     * @return address to receive the royalty
     * @return the royalty amount
     */
    function royaltyInfo(
        uint256, // tokenId
        uint256 salePrice
    ) external view override returns (address, uint256) {
        // This contract should receive the secondary sale royalty payments
        return (address(this), (salePrice * royaltyBps) / 10000);
    }

    /**
     * @notice Owner provided signature allows anyone to mint an NFT
     * @param to address that will own the NFT
     * @param count number of NFTs to mint
     * @param price total ETH that must be sent to the contract to mint NFTs
     * @param mintLimit max number of NFTs that can be minted to this owner
     * @param expires block timestamp after which this call is no longer valid
     */
    function mint(
        address to,
        uint256 count,
        uint256 price,
        uint256 mintLimit,
        uint256 expires,
        bytes memory sig
    ) external payable {
        require(_numberMinted(to) + count <= mintLimit, 'Max mint limit');
        require(totalSupply() + count <= maxSupply, 'Max supply exceeded');
        require(block.timestamp <= expires, 'Signature expired');
        require(msg.value >= price, 'Not enough ETH');

        bytes32 msgHash = keccak256(
            abi.encode(
                block.chainid,
                address(this),
                _msgSender(),
                to,
                count,
                price,
                mintLimit,
                expires
            )
        );

        address addr = ECDSA.recover(
            ECDSA.toEthSignedMessageHash(msgHash),
            sig
        );
        require(hasRole(MINTER_ROLE, addr), 'Invalid signer');

        _safeMint(to, count);
    }

    /**
     * @notice Set the base URI for off-chain metadata
     * @dev Only the owner can alter this value
     * @param _base - the URI to set
     */
    function setBaseURI(string calldata _base)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        baseURI = _base;
    }

    /**
     * @dev get the base URI
     * @return the stored base URI
     */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /**
     * @dev get the initial token ID (1-indexed).  THis is used by ERC721a
     * @return the initial token ID
     */
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }
}
