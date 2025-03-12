/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./tokens/ERC721/WeAllSurvivedDeath.sol";

contract WASDMinting is Ownable, Pausable {
    using ECDSA for bytes32;

    struct MintingRole {
        uint256 roleId;
        string roleName;
        uint256 mintLimit; // the maximum number of times each participant of this role can mint
    }

    struct PhaseInfo {
        string metadata; // the general information of this phase
        uint256 duration; // the duration of this phase in seconds
        uint256 mintLimit; // the maximum number of times each participant can mint at this phase
    }

    struct ParticipantInfo {
        uint256 roleId;
        uint256 mintCount;
    }

    WeAllSurvivedDeath public WASD;
    uint256 public wasdLimit;
    uint256 public totalMintCount;
    uint256 public startingTime;
    uint256 private _deployedTime;
    PhaseInfo[] private _phaseInfos;
    MintingRole[] private _mintingRoles;
    mapping(uint256 => mapping(uint256 => bool)) private _rolePermission; // (phase ID + role ID) => permission
    mapping(address => ParticipantInfo) private _participantInfos;
    mapping(uint256 => uint256[]) private _allowedInPhases; // role ID => [phase IDs]
    mapping(uint256 => uint256) private _availableSlotsForRole; // the maximum number of participants who can have this role
    mapping(address => bool) private _operators;

    event MintingRoleCreated(
        uint256 roleId,
        string roleName,
        uint256 mintLimit
    );

    constructor(
        address wasdNFT,
        uint256 wasdLimit_,
        uint256 startingTime_,
        string[] memory metadatas,
        uint256[] memory durations,
        uint256[] memory mintLimits
    ) Ownable() {
        _operators[msg.sender] = true;
        WASD = WeAllSurvivedDeath(wasdNFT);
        wasdLimit = wasdLimit_;
        startingTime = startingTime_;
        _deployedTime = block.timestamp;
        _availableSlotsForRole[0] = type(uint256).max;
        _mintingRoles.push(MintingRole(0, "Community", 1));
        require(
            metadatas.length == durations.length,
            "WASDMinting: lengths mismatch"
        );
        require(
            metadatas.length == mintLimits.length,
            "WASDMinting: lengths mismatch"
        );
        _phaseInfos.push(PhaseInfo("", startingTime_ - block.timestamp, 0));
        for (uint256 i = 0; i < metadatas.length; i++) {
            require(durations[i] >= 5 minutes, "WASDMinting: phase too short");
            require(
                mintLimits[i] > 0,
                "WASDMinting: mint limit must be greater than zero"
            );
            _phaseInfos.push(
                PhaseInfo(metadatas[i], durations[i], mintLimits[i])
            );
        }
    }

    modifier onlyOperators() {
        require(_operators[msg.sender], "WASDMinting: caller is not operator");
        _;
    }

    function getPhaseInfo() external view returns (PhaseInfo[] memory) {
        uint256 numPhases = _phaseInfos.length - 1;
        PhaseInfo[] memory phases = new PhaseInfo[](numPhases);
        for (uint256 i = 0; i < numPhases; i++) phases[i] = _phaseInfos[i + 1];
        return phases;
    }

    function getCurrentPhase() public view returns (uint256) {
        uint256 elapsedTime = block.timestamp - _deployedTime;
        for (uint256 phase = 0; phase < _phaseInfos.length; phase++)
            if (elapsedTime >= _phaseInfos[phase].duration)
                elapsedTime -= _phaseInfos[phase].duration;
            else return phase;
        return _phaseInfos.length;
    }

    function getRoles() external view returns (MintingRole[] memory) {
        return _mintingRoles;
    }

    function getParticipantInfo(address participant)
        public
        view
        returns (
            uint256 roleId,
            string memory roleName,
            uint256 mintLimit,
            uint256 mintCount,
            uint256 availableMintCount,
            uint256[] memory allowedInPhases
        )
    {
        require(
            getCurrentPhase() < _phaseInfos.length,
            "WASDMinting: minting time is over"
        );
        roleId = _participantInfos[participant].roleId;
        roleName = _mintingRoles[roleId].roleName;
        mintLimit = _mintingRoles[roleId].mintLimit;
        mintCount = _participantInfos[participant].mintCount;
        allowedInPhases = _allowedInPhases[roleId];
        if (!_rolePermission[getCurrentPhase()][roleId]) availableMintCount = 0;
        else {
            require(
                _participantInfos[participant].mintCount <=
                    _mintingRoles[roleId].mintLimit,
                "WASDMinting: mint count exceeds limit"
            );
            availableMintCount =
                _mintingRoles[roleId].mintLimit -
                _participantInfos[participant].mintCount;
            if (availableMintCount > _phaseInfos[getCurrentPhase()].mintLimit)
                availableMintCount = _phaseInfos[getCurrentPhase()].mintLimit;
        }
    }

    function setOperators(address[] memory operators, bool[] memory isOperators)
        external
        onlyOwner
    {
        require(
            operators.length == isOperators.length,
            "WASDMinting: lengths mismatch"
        );
        for (uint256 i = 0; i < operators.length; i++)
            _operators[operators[i]] = isOperators[i];
    }

    function createMintingRoles(
        string[] memory roleNames,
        uint256[] memory mintLimits,
        uint256[] memory roleLimits
    ) external onlyOperators {
        require(
            roleNames.length == mintLimits.length,
            "WASDMinting: lengths mismatch"
        );
        require(
            roleNames.length == roleLimits.length,
            "WASDMinting: lengths mismatch"
        );
        for (uint256 i = 0; i < roleNames.length; i++) {
            require(
                mintLimits[i] > 0,
                "WASDMinting: mint limit must be greater than zero"
            );
            require(
                roleLimits[i] > 0,
                "WASDMinting: role limit must be greater than zero"
            );
            uint256 roleId = _mintingRoles.length;
            _availableSlotsForRole[roleId] = roleLimits[i];
            _mintingRoles.push(
                MintingRole(roleId, roleNames[i], mintLimits[i])
            );
            emit MintingRoleCreated(roleId, roleNames[i], mintLimits[i]);
        }
    }

    function addRolesToPhases(
        uint256[] memory phaseIds,
        uint256[][] memory roleIds
    ) external onlyOperators {
        require(
            phaseIds.length == roleIds.length,
            "WASDMinting: lengths mismatch"
        );
        for (uint256 i = 0; i < phaseIds.length; i++) {
            require(
                phaseIds[i] < _phaseInfos.length,
                "WASDMinting: invalid phase ID"
            );
            for (uint256 j = 0; j < roleIds[i].length; j++) {
                require(
                    roleIds[i][j] < _mintingRoles.length,
                    "WASDMinting: invalid role ID"
                );
                _rolePermission[phaseIds[i]][roleIds[i][j]] = true;
                _allowedInPhases[roleIds[i][j]].push(phaseIds[i]);
            }
        }
    }

    function mintWASD(
        uint256 roleId,
        bytes calldata signature,
        uint256 quantity
    ) external whenNotPaused {
        // Validate basic information
        require(
            getCurrentPhase() < _phaseInfos.length,
            "WASDMinting: minting time is over"
        );
        require(
            _participantInfos[msg.sender].roleId == 0,
            "WASDMinting: participant already granted minting role"
        );
        require(
            _participantInfos[msg.sender].mintCount == 0,
            "WASDMinting: not the first mint"
        );
        require(roleId < _mintingRoles.length, "WASDMinting: invalid role ID");
        require(
            _availableSlotsForRole[roleId] > 0,
            "WASDMinting: role limit reached"
        );

        // Validate operator's signature
        bytes32 hash = keccak256(abi.encodePacked(msg.sender, roleId));
        bytes32 messageHash = hash.toEthSignedMessageHash();
        address signer = messageHash.recover(signature);
        require(_operators[signer], "WASDMinting: invalid signer");

        // Validate mint count
        require(
            totalMintCount + quantity <= wasdLimit,
            "WASDMinting: total mint limit reached"
        );
        uint256 availableMintCount = 0;
        if (_rolePermission[getCurrentPhase()][roleId]) {
            availableMintCount = _mintingRoles[roleId].mintLimit;
            if (availableMintCount > _phaseInfos[getCurrentPhase()].mintLimit)
                availableMintCount = _phaseInfos[getCurrentPhase()].mintLimit;
        }
        require(
            quantity <= availableMintCount,
            "WASDMinting: personal mint limit at this phase reached"
        );

        // Grant role and mint WASDs
        _availableSlotsForRole[roleId]--;
        _participantInfos[msg.sender].roleId = roleId;
        _participantInfos[msg.sender].mintCount = quantity;
        totalMintCount += quantity;
        for (uint256 i = 0; i < quantity; i++) WASD.mintTo(msg.sender);
    }

    function mintWASD(uint256 quantity) external whenNotPaused {
        require(
            _participantInfos[msg.sender].mintCount > 0,
            "WASDMinting: first mint - undetected role"
        );
        (, , , , uint256 availableMintCount, ) = getParticipantInfo(msg.sender);
        require(
            quantity <= availableMintCount,
            "WASDMinting: personal mint limit at this phase reached"
        );
        require(
            totalMintCount + quantity <= wasdLimit,
            "WASDMinting: total mint limit reached"
        );
        _participantInfos[msg.sender].mintCount += quantity;
        totalMintCount += quantity;
        for (uint256 i = 0; i < quantity; i++) WASD.mintTo(msg.sender);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
