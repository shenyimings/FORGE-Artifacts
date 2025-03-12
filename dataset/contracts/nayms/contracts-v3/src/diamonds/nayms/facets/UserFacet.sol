// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { AppStorage } from "../AppStorage.sol";
import { Modifiers } from "../Modifiers.sol";
import { LibHelpers } from "../libs/LibHelpers.sol";
import { LibMarket } from "../libs/LibMarket.sol";
import { LibObject } from "../libs/LibObject.sol";

/**
 * @title Users
 * @notice Manage user entity
 * @dev Use manage user entity
 */
contract UserFacet is Modifiers {
    /**
     * @notice Get the platform ID of `addr` account
     * @dev Convert address to platform ID
     * @param addr Account address
     * @return userId Unique platform ID
     */
    function getUserIdFromAddress(address addr) external pure returns (bytes32 userId) {
        return LibHelpers._getIdForAddress(addr);
    }

    /**
     * @notice Get the token address from ID of the external token
     * @dev Convert the bytes32 external token ID to its respective ERC20 contract address
     * @param _externalTokenId The ID assigned to an external token
     * @return tokenAddress Contract address
     */
    function getAddressFromExternalTokenId(bytes32 _externalTokenId) external pure returns (address tokenAddress) {
        tokenAddress = LibHelpers._getAddressFromId(_externalTokenId);
    }

    /**
     * @notice Set the entity for the user
     * @dev Assign the user an entity
     * @param _userId Unique platform ID of the user account
     * @param _entityId Unique platform ID of the entity
     */
    function setEntity(bytes32 _userId, bytes32 _entityId) external assertSysAdmin {
        LibObject._setParent(_userId, _entityId);
    }

    /**
     * @notice Get the entity for the user
     * @dev Gets the entity related to the user
     * @param _userId Unique platform ID of the user account
     * @return entityId Unique platform ID of the entity
     */
    function getEntity(bytes32 _userId) external view returns (bytes32 entityId) {
        entityId = LibObject._getParent(_userId);
    }

    /**
     * @notice Get the amount of tokens that an entity has for sale in the marketplace.
     * @param _entityId  Unique platform ID of the entity.
     * @param _tokenId The ID assigned to an external token.
     * @return amount of tokens that the entity has for sale in the marketplace.
     */
    function getBalanceOfTokensForSale(bytes32 _entityId, bytes32 _tokenId) external view returns (uint256 amount) {
        amount = LibMarket._getBalanceOfTokensForSale(_entityId, _tokenId);
    }
}
