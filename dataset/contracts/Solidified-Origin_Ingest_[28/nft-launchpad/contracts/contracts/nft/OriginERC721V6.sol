// SPDX-License-Identifier: MIT
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
 */

pragma solidity ^0.8.4;

import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import '@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/finance/PaymentSplitterUpgradeable.sol';

contract OriginERC721V6 is
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable,
    PaymentSplitterUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');
    mapping(address => uint256) private _mintCount;
    string public baseURI;
    uint256 public maxSupply;
    address public owner;

    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdTracker;

    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _base,
        uint256 _maxSupply,
        address _minter,
        address[] memory _payees,
        uint256[] memory _shares
    ) public initializer {
        require(_maxSupply > 0);
        __AccessControl_init();
        // __ERC721Enumerable_init() does not set token name and symbol, but
        // otherwise is the same.
        __ERC721_init(_name, _symbol);
        __PaymentSplitter_init(_payees, _shares);
        baseURI = _base;
        maxSupply = _maxSupply;
        owner = _owner;

        _setupRole(DEFAULT_ADMIN_ROLE, _owner);

        if (_minter != address(0)) {
            _setupRole(MINTER_ROLE, _minter);
        } else {
            _setupRole(MINTER_ROLE, _msgSender());
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Return URI to contract metadata JSON file
     * @return URI to JSON file
     */
    function contractURI() public view returns (string memory) {
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, 'contract.json'))
                : '';
    }

    /**
     * @notice Change the base url for all NFTs
     */
    function setBaseURI(string calldata _base)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        baseURI = _base;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
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
        require(_mintCount[to] + count <= mintLimit, 'Max mint limit');
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

        _mintCount[to] += count;

        uint256 maxId = _tokenIdTracker.current() + count;
        for (uint256 i = 0; i < count; i++) {
            _tokenIdTracker.increment();
            uint256 id = _tokenIdTracker.current();
            require(id <= maxId, 'Invalid sequence');
            _safeMint(to, id);
        }
    }
}
