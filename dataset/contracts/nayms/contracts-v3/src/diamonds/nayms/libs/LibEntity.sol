// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { LibAppStorage, AppStorage } from "../AppStorage.sol";
import { Entity, SimplePolicy, Stakeholders } from "../AppStorage.sol";
import { LibConstants } from "./LibConstants.sol";
import { LibAdmin } from "./LibAdmin.sol";
import { LibHelpers } from "./LibHelpers.sol";
import { LibObject } from "./LibObject.sol";
import { LibACL } from "./LibACL.sol";
import { LibTokenizedVault } from "./LibTokenizedVault.sol";
import { LibMarket } from "./LibMarket.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

library LibEntity {
    using ECDSA for bytes32;
    /**
     * @notice New entity has been created
     * @dev Thrown when entity is created
     * @param entityId Unique ID for the entity
     * @param entityAdmin Unique ID of the entity administrator
     */
    event EntityCreated(bytes32 entityId, bytes32 entityAdmin);
    event EntityUpdated(bytes32 entityId);
    event SimplePolicyCreated(bytes32 indexed id, bytes32 entityId);
    event TokenSaleStarted(bytes32 indexed entityId, uint256 offerId);

    /**
     * @dev If an entity passes their checks to create a policy, ensure that the entity's capacity is appropriately decreased by the amount of capital that will be tied to the new policy being created.
     */
    function _validateSimplePolicyCreation(bytes32 _entityId, SimplePolicy calldata simplePolicy) internal view returns (uint256 updatedUtilizedCapacity) {
        // The policy's limit cannot be 0. If a policy's limit is zero, this essentially means the policy doesn't require any capital, which doesn't make business sense.
        require(simplePolicy.limit > 0, "limit not > 0");

        bool isEntityAdmin = LibACL._isInGroup(LibHelpers._getSenderId(), _entityId, LibHelpers._stringToBytes32(LibConstants.GROUP_ENTITY_ADMINS));
        require(isEntityAdmin, "must be entity admin");

        AppStorage storage s = LibAppStorage.diamondStorage();
        Entity memory entity = s.entities[_entityId];

        // todo: ensure that the capital raised is >= max capacity. Probably want to do this check when the trade is made.

        // note: An entity cannot be created / updated to have a 0 collateral ratio, 0 max capacity, so no need to check this here.
        // require(entity.collateralRatio > 0 && entity.maxCapacity > 0, "currency disabled");

        // Calculate the entity's utilized capacity after it writes this policy.
        updatedUtilizedCapacity = entity.utilizedCapacity + simplePolicy.limit;

        // The entity must have enough capacity available to write this policy.
        // An entity is not able to write an additional policy that will utilize its capacity beyond its assigned max capacity.
        require(entity.maxCapacity >= updatedUtilizedCapacity, "not enough available capacity");

        // Calculate the entity's required capital for its capacity utilization based on its collateral requirements.
        uint256 capitalRequirementForUpdatedUtilizedCapacity = (updatedUtilizedCapacity * entity.collateralRatio) / LibConstants.BP_FACTOR;

        require(LibAdmin._isSupportedExternalToken(simplePolicy.asset), "external token is not supported");

        // The entity's balance must be >= to the updated capacity requirement
        // todo: business only wants to count the entity's balance that was raised from the participation token sale and not its total balance
        require(LibTokenizedVault._internalBalanceOf(_entityId, simplePolicy.asset) >= capitalRequirementForUpdatedUtilizedCapacity, "not enough capital");

        require(simplePolicy.startDate >= block.timestamp, "start date < block.timestamp");
        require(simplePolicy.maturationDate > simplePolicy.startDate, "start date > maturation date");

        uint256 commissionReceiversArrayLength = simplePolicy.commissionReceivers.length;
        require(commissionReceiversArrayLength > 0, "must have commission receivers");

        uint256 commissionBasisPointsArrayLength = simplePolicy.commissionBasisPoints.length;
        require(commissionBasisPointsArrayLength > 0, "must have commission basis points");
        require(commissionReceiversArrayLength == commissionBasisPointsArrayLength, "commissions lengths !=");

        uint256 totalBP;
        for (uint256 i; i < commissionBasisPointsArrayLength; ++i) {
            totalBP += simplePolicy.commissionBasisPoints[i];
        }
        require(totalBP <= LibConstants.BP_FACTOR, "bp cannot be > 10000");
    }

    function _createSimplePolicy(
        bytes32 _policyId,
        bytes32 _entityId,
        Stakeholders calldata _stakeholders,
        SimplePolicy calldata _simplePolicy,
        bytes32 _dataHash
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        require(_stakeholders.entityIds.length == _stakeholders.signatures.length, "incorrect number of signatures");

        // note: An entity's updated utilized capacity <= max capitalization check is done in _validateSimplePolicyCreation().
        // Update state with the entity's updated utilized capacity.
        s.entities[_entityId].utilizedCapacity = _validateSimplePolicyCreation(_entityId, _simplePolicy);

        LibObject._createObject(_policyId, _entityId, _dataHash);
        s.simplePolicies[_policyId] = _simplePolicy;
        s.simplePolicies[_policyId].fundsLocked = true;

        uint256 rolesCount = _stakeholders.roles.length;

        for (uint256 i = 0; i < rolesCount; i++) {
            address signer = ECDSA.recover(ECDSA.toEthSignedMessageHash(_policyId), _stakeholders.signatures[i]);
            bytes32 signerId = LibHelpers._getIdForAddress(signer);

            require(LibACL._isInGroup(signerId, _stakeholders.entityIds[i], LibHelpers._stringToBytes32(LibConstants.GROUP_ENTITY_ADMINS)), "invalid stakeholder");
            LibACL._assignRole(_stakeholders.entityIds[i], _policyId, _stakeholders.roles[i]);
        }

        emit SimplePolicyCreated(_policyId, _entityId);
    }

    function _updateAllowSimplePolicy(bytes32 _entityId, bool _allow) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.entities[_entityId].simplePolicyEnabled = _allow;
    }

    /// @param _amount the amount of entity token that is minted and put on sale
    /// @param _totalPrice the buy amount
    function _startTokenSale(
        bytes32 _entityId,
        uint256 _amount,
        uint256 _totalPrice
    ) internal {
        require(_amount > 0, "mint amount must be > 0");
        require(_totalPrice > 0, "total price must be > 0");

        AppStorage storage s = LibAppStorage.diamondStorage();
        Entity memory entity = s.entities[_entityId];

        LibTokenizedVault._internalMint(_entityId, _entityId, _amount);

        (uint256 offerId, , ) = LibMarket._executeLimitOffer(_entityId, _entityId, _amount, entity.assetId, _totalPrice, LibConstants.FEE_SCHEDULE_STANDARD);

        emit TokenSaleStarted(_entityId, offerId);
    }

    function _createEntity(
        bytes32 _entityId,
        bytes32 _entityAdmin,
        Entity memory _entity,
        bytes32 _dataHash
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        validateEntity(_entity);

        LibObject._createObject(_entityId, _dataHash);
        LibObject._setParent(_entityAdmin, _entityId);
        s.existingEntities[_entityId] = true;

        LibACL._assignRole(_entityAdmin, _entityId, LibHelpers._stringToBytes32(LibConstants.ROLE_ENTITY_ADMIN));

        // An entity starts without any capacity being utilized
        delete _entity.utilizedCapacity;

        s.entities[_entityId] = _entity;

        emit EntityCreated(_entityId, _entityAdmin);
    }

    function _updateEntity(bytes32 _entityId, Entity memory _entity) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        validateEntity(_entity);

        s.entities[_entityId] = _entity;

        emit EntityUpdated(_entityId);
    }

    function validateEntity(Entity memory _entity) internal view {
        if (_entity.assetId != 0) {
            // entity has an underlying asset, which means it's a cell

            // External token must be whitelisted by the platform
            require(LibAdmin._isSupportedExternalToken(_entity.assetId), "external token is not supported");

            // Collateral ratio must be in acceptable range of 1 to 10000 basis points (0.01% to 100% collateralized).
            // Cannot ever be completely uncollateralized (0 basis points), if entity is a cell.
            require(1 <= _entity.collateralRatio && _entity.collateralRatio <= LibConstants.BP_FACTOR, "collateral ratio should be 1 to 10000");

            // Max capacity is the capital amount that an entity can write across all of their policies.
            // note: We do not directly use the value maxCapacity to determine if the entity can or cannot write a policy.
            //       First, we use the bool simplePolicyEnabled to control and dictate whether an entity can or cannot write a policy.
            //       If an entity has this set to true, then we check if an entity has enough capacity to write the policy.
            require(!_entity.simplePolicyEnabled || (_entity.maxCapacity > 0), "max capacity should be greater than 0 for policy creation");
        } else {
            // non-cell entity
            require(_entity.collateralRatio == 0, "only cell has collateral ratio");
            require(!_entity.simplePolicyEnabled, "only cell can issue policies");
            require(_entity.maxCapacity == 0, "only calls have max capacity");
        }
    }

    function _getEntityInfo(bytes32 _entityId) internal view returns (Entity memory entity) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        entity = s.entities[_entityId];
    }

    function _isEntity(bytes32 _entityId) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.existingEntities[_entityId];
    }
}
