pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";
import "./LEventsEvents.sol";
import "./LEventsStorage.sol";
import "./zeppelin/LECRecovery.sol";
import "./LValidators.sol";

library LEventsRoles {

  bytes32 constant primaryHash = keccak256(abi.encodePacked("Primary"));
  bytes32 constant secondaryHash = keccak256(abi.encodePacked("Secondary"));

  modifier onlyEventOwnerOrValidator(IAventusStorage _storage, uint _eventId) {
    bool isEventOwner = LEventsEvents.isEventOwner(_storage, _eventId, msg.sender);
    bool isValidator = LValidators.isRegistered(_storage, msg.sender);
    require(isEventOwner || isValidator, "Sender must be owner or validator");
    _;
  }

  modifier onlyIfRegistrable(IAventusStorage _storage, string memory _role) {
    bytes32 roleHash = keccak256(abi.encodePacked(_role));
    bool validRole = roleHash == primaryHash || roleHash == secondaryHash;
    require(validRole, string(abi.encodePacked("Role is not registrable: ", _role)));
    _;
  }

  modifier onlyIfNotAlreadyRegistered(IAventusStorage _storage, uint _eventId, address _roleAddress, string memory _role) {
    require(!LEventsStorage.isRoleOnEvent(_storage, _eventId, _roleAddress, _role), "Role is already registered on event");
    _;
  }

  function registerRoleOnEvent(IAventusStorage _storage, uint _eventId, address _roleAddress, string calldata _role,
      bytes calldata _registerRoleEventOwnerProof)
    external
    onlyEventOwnerOrValidator(_storage, _eventId)
  {
    doRegisterRoleOnEvent(_storage, _eventId, _roleAddress, _role);
    bytes32 registerRoleHash = keccak256(abi.encodePacked(_eventId, _roleAddress, _role));
    address signer = LECRecovery.recover(registerRoleHash, _registerRoleEventOwnerProof);
    bool signerIsEventOwner = LEventsEvents.isEventOwner(_storage, _eventId, signer);
    require(signerIsEventOwner, "Registration proof must be valid and signed by event owner");

    if (msg.sender != signer)
      LValidators.ensureValidatorIsRegistered(_storage);
  }

  function isEventOwnerOrRole(IAventusStorage _storage, uint _eventId, address _address, string memory _role)
    public
    view
    returns (bool isOwnerOrRole_)
  {
    bool isRole = LEventsStorage.isRoleOnEvent(_storage, _eventId, _address, _role);
    bool isEventOwner = LEventsEvents.isEventOwner(_storage, _eventId, _address);
    isOwnerOrRole_ = isRole || isEventOwner;
  }

  // Separate method due to stack too deep.
  function doRegisterRoleOnEvent(IAventusStorage _storage, uint _eventId, address _roleAddress, string memory _role)
    private
    onlyIfRegistrable(_storage, _role)
    onlyIfNotAlreadyRegistered(_storage, _eventId, _roleAddress, _role)
  {
    LEventsStorage.setRoleOnEvent(_storage, _eventId, _roleAddress, _role);
  }
}