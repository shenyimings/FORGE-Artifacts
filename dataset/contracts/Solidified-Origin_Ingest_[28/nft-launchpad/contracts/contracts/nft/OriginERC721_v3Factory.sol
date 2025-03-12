/*
 * Origin Protocol
 * https://originprotocol.com
 *
 * Released under the MIT license
 * SPDX-License-Identifier: MIT
 * https://github.com/OriginProtocol/nft-launchpad
 *
 * Copyright 2021 Origin Protocol, Inc
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

pragma solidity ^0.8.0;

import "./OriginERC721_v3.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract OriginERC721_v3Factory {
    address immutable tokenImplementation;
    event CreateToken(address indexed addr, address indexed deployer);

    constructor() {
        tokenImplementation = address(new OriginERC721_v3());
    }

    function _createToken(
        address owner,
        address minter,
        string calldata name,
        string calldata symbol,
        string calldata baseURI
    ) internal returns (address) {
        address clone = Clones.clone(tokenImplementation);

        OriginERC721_v3(clone).initialize(
            owner,
            minter,
            name,
            symbol,
            baseURI
        );

        emit CreateToken(clone, msg.sender);
        return clone;
    }

    /**
     * Deploy an ERC721 contract
     *
     * @param name ERC721 metadata name of the collection
     * @param symbol ERC721 symbol
     * @param baseURI base URL that combines with token ID for metadata
     *      location
     * @return address of the newly created contract
     */
    function createToken(
        string calldata name,
        string calldata symbol,
        string calldata baseURI
    ) external returns (address) {
        return _createToken(msg.sender, address(0), name, symbol, baseURI);
    }

    /**
     * Deploy an ERC721 contract with an account set as minter
     *
     * @param minter address is an account (other than the owner) with
     *      permissions to mint tokens
     * @param name ERC721 metadata name of the collection
     * @param symbol ERC721 symbol
     * @param baseURI base URL that combines with token ID for metadata
     *      location
     * @return address of the newly created contract
     */
    function createTokenWithMinter(
        address minter,
        string calldata name,
        string calldata symbol,
        string calldata baseURI
    ) external returns (address) {
        return _createToken(msg.sender, minter, name, symbol, baseURI);
    }
}
