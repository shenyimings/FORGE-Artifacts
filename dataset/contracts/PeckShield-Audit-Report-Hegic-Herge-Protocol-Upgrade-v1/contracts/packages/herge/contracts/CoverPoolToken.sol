pragma solidity ^0.8.3;

/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Hegic
 * Copyright (C) 2021 Hegic Protocol
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract CoverPoolToken is ERC721, AccessControl {
    IERC721Metadata public uriBuilder;

    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

    /**
     * @dev See :sol:interface:`ICoverPool`
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl)
        returns (bool)
    {
        return
            ERC721.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory uri)
    {
        if (address(uriBuilder) == address(0)) return ERC721.tokenURI(tokenId);
        return uriBuilder.tokenURI(tokenId);
    }

    function setURIBuilder(IERC721Metadata _uriBuilder)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uriBuilder = _uriBuilder;
    }

    function isApprovedOrOwner(address spender, uint256 tokenId)
        external
        view
        returns (bool)
    {
        return _isApprovedOrOwner(spender, tokenId);
    }
}
