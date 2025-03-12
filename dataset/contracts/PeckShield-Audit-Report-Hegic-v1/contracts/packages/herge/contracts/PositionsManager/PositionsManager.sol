pragma solidity ^0.8.3;

/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Hegic
 * Copyright (C) 2022 Hegic Protocol
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

import "./IPositionsManager.sol";
import "@hegic/utils/contracts/ERC721WithURIBuilder.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @author 0mllwntrmt3
 * @title Hegic Protocol V8888 Positions Manager Contract
 * @notice The contract that buys the options contracts for the options holders
 * as well as checks whether the contract that is used for buying/exercising
 * options has been been granted with the permission to do it on the user's behalf.
 **/

contract PositionsManager is
    AccessControl,
    ERC721WithURIBuilder("Hegic Herge Options & Strategies", "HEGOPS"),
    IPositionsManager
{
    bytes32 public constant HEGIC_POOL_ROLE = keccak256("HEGIC_POOL_ROLE");
    uint256 public nextTokenId = 0;
    mapping(uint256 => address) public override tokenPool;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function createOptionFor(address holder)
        public
        override
        onlyRole(HEGIC_POOL_ROLE)
        returns (uint256 id)
    {
        id = nextTokenId++;
        tokenPool[id] = msg.sender;
        _safeMint(holder, id);
    }

    /**
     * @dev See EIP-165: ERC-165 Standard Interface Detection
     * https://eips.ethereum.org/EIPS/eip-165
     **/
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721WithURIBuilder, AccessControl, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IPositionsManager).interfaceId ||
            AccessControl.supportsInterface(interfaceId) ||
            ERC721.supportsInterface(interfaceId);
    }
}
