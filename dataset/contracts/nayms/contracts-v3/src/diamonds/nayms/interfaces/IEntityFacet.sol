// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { SimplePolicy, Entity, Stakeholders } from "./FreeStructs.sol";

/**
 * @title Entities
 * @notice Used to handle policies and token sales
 * @dev Mainly used for token sale and policies
 */
interface IEntityFacet {
    /**
     * @notice Enable/Disable Simple Policy creation for Entity ID: `_entityId`
     * @dev Update simple policy creation allow flag
     * @param _entityId ID of the entity to update
     * @param _allow Allow or not simple policy creation
     */
    function updateAllowSimplePolicy(bytes32 _entityId, bool _allow) external;

    /**
     * @notice Create a Simple Policy
     * @param _policyId id of the policy
     * @param _entityId id of the entity
     * @param _stakeholders Struct of roles, entity IDs and signatures for the policy
     * @param _simplePolicy policy to create
     * @param _dataHash hash of the offchain data
     */
    function createSimplePolicy(
        bytes32 _policyId,
        bytes32 _entityId,
        Stakeholders calldata _stakeholders,
        SimplePolicy calldata _simplePolicy,
        bytes32 _dataHash
    ) external;

    /**
     * @notice Enable an entity to be tokenized
     * @param _entityId ID of the entity
     * @param _symbol The symbol assigned to the entity token
     */
    function enableEntityTokenization(bytes32 _entityId, string memory _symbol) external;

    /**
     * @notice Start token sale of `_amount` tokens for total price of `_totalPrice`
     * @dev Entity tokens are minted when the sale is started
     * @param _entityId ID of the entity
     * @param _amount amount of entity tokens to put on sale
     * @param _totalPrice total price of the tokens
     */
    function startTokenSale(
        bytes32 _entityId,
        uint256 _amount,
        uint256 _totalPrice
    ) external;

    /**
     * @notice Update entity metadata
     * @param _entityId ID of the entity
     * @param _entity metadata of the entity
     */
    function updateEntity(bytes32 _entityId, Entity calldata _entity) external;

    /**
     * @notice Get the the data for entity with ID: `_entityId`
     * @dev Get the Entity data for a given entityId
     * @param _entityId ID of the entity
     * @return Entity struct with metadata of the entity
     */
    function getEntityInfo(bytes32 _entityId) external view returns (Entity memory);
}
