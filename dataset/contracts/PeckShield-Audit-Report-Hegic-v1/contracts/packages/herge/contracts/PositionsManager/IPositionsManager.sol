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

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@hegic/utils/contracts/IERC721WithURIBuilder.sol";

/**
 * @notice The interface for the contract
 *   that tokenizes options as ERC721.
 **/
interface IPositionsManager is IERC721WithURIBuilder {
    /**
     * @param holder The option buyer address
     **/
    function createOptionFor(address holder) external returns (uint256);

    /**
     * @param tokenId The ERC721 token ID linked to the option
     **/
    function tokenPool(uint256 tokenId) external returns (address pool);
}
