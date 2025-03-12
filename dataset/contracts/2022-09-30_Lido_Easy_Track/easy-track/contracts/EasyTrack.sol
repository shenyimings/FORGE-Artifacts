// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "./MotionSettings.sol";
import "./EVMScriptFactoriesRegistry.sol";
import "./interfaces/IEVMScriptExecutor.sol";

import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/security/Pausable.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/access/AccessControl.sol";

interface IMiniMeToken {
    function balanceOfAt(address _owner, uint256 _blockNumber) external pure returns (uint256);

    function totalSupplyAt(uint256 _blockNumber) external view returns (uint256);
}

/// @author psirex
/// @notice Contains main logic of Easy Track
contract EasyTrack is Pausable, AccessControl, MotionSettings, EVMScriptFactoriesRegistry {
    struct Motion {
        uint256 id;
        address evmScriptFactory;
        address creator;
        uint256 duration;
        uint256 startDate;
        uint256 snapshotBlock;
        uint256 objectionsThreshold;
        uint256 objectionsAmount;
        bytes32 evmScriptHash;
    }

    // -------------
    // EVENTS
    // -------------
    event MotionCreated(
        uint256 indexed _motionId,
        address _creator,
        address indexed _evmScriptFactory,
        bytes _evmScriptCallData,
        bytes _evmScript
    );
    event MotionObjected(
        uint256 indexed _motionId,
        address indexed _objector,
        uint256 _weight,
        uint256 _newObjectionsAmount,
        uint256 _newObjectionsAmountPct
    );
    event MotionRejected(uint256 indexed _motionId);
    event MotionCanceled(uint256 indexed _motionId);
    event MotionEnacted(uint256 indexed _motionId);
    event EVMScriptExecutorChanged(address indexed _evmScriptExecutor);

    // -------------
    // ERRORS
    // -------------
    string private constant ERROR_ALREADY_OBJECTED = "ALREADY_OBJECTED";
    string private constant ERROR_NOT_ENOUGH_BALANCE = "NOT_ENOUGH_BALANCE";
    string private constant ERROR_NOT_CREATOR = "NOT_CREATOR";
    string private constant ERROR_MOTION_NOT_PASSED = "MOTION_NOT_PASSED";
    string private constant ERROR_UNEXPECTED_EVM_SCRIPT = "UNEXPECTED_EVM_SCRIPT";
    string private constant ERROR_MOTION_NOT_FOUND = "MOTION_NOT_FOUND";
    string private constant ERROR_MOTIONS_LIMIT_REACHED = "MOTIONS_LIMIT_REACHED";

    // -------------
    // ROLES
    // -------------
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    bytes32 public constant UNPAUSE_ROLE = keccak256("UNPAUSE_ROLE");
    bytes32 public constant CANCEL_ROLE = keccak256("CANCEL_ROLE");

    // -------------
    // CONSTANTS
    // -------------

    // Stores 100% in basis points
    uint256 internal constant HUNDRED_PERCENT = 10000;

    // ------------
    // STORAGE VARIABLES
    // ------------

    /// @notice List of active motions
    Motion[] public motions;

    // Id of the lastly created motion
    uint256 internal lastMotionId;

    /// @notice Address of governanceToken which implements IMiniMeToken interface
    IMiniMeToken public governanceToken;

    /// @notice Address of current EVMScriptExecutor
    IEVMScriptExecutor public evmScriptExecutor;

    // Position of the motion in the `motions` array, plus 1
    // because index 0 means a value is not in the set.
    mapping(uint256 => uint256) internal motionIndicesByMotionId;

    /// @notice Stores if motion with given id has been objected from given address.
    mapping(uint256 => mapping(address => bool)) public objections;

    // ------------
    // CONSTRUCTOR
    // ------------
    constructor(
        address _governanceToken,
        address _admin,
        uint256 _motionDuration,
        uint256 _motionsCountLimit,
        uint256 _objectionsThreshold
    )
        EVMScriptFactoriesRegistry(_admin)
        MotionSettings(_admin, _motionDuration, _motionsCountLimit, _objectionsThreshold)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(PAUSE_ROLE, _admin);
        _setupRole(UNPAUSE_ROLE, _admin);
        _setupRole(CANCEL_ROLE, _admin);

        governanceToken = IMiniMeToken(_governanceToken);
    }

    // ------------------
    // EXTERNAL METHODS
    // ------------------

    /// @notice Creates new motion
    /// @param _evmScriptFactory Address of EVMScript factory registered in Easy Track
    /// @param _evmScriptCallData Encoded call data of EVMScript factory
    /// @return _newMotionId Id of created motion
    function createMotion(address _evmScriptFactory, bytes memory _evmScriptCallData)
        external
        whenNotPaused
        returns (uint256 _newMotionId)
    {
        require(motions.length < motionsCountLimit, ERROR_MOTIONS_LIMIT_REACHED);

        Motion storage newMotion = motions.push();
        _newMotionId = ++lastMotionId;

        newMotion.id = _newMotionId;
        newMotion.creator = msg.sender;
        newMotion.startDate = block.timestamp;
        newMotion.snapshotBlock = block.number;
        newMotion.duration = motionDuration;
        newMotion.objectionsThreshold = objectionsThreshold;
        newMotion.evmScriptFactory = _evmScriptFactory;
        motionIndicesByMotionId[_newMotionId] = motions.length;

        bytes memory evmScript =
            _createEVMScript(_evmScriptFactory, msg.sender, _evmScriptCallData);
        newMotion.evmScriptHash = keccak256(evmScript);

        emit MotionCreated(
            _newMotionId,
            msg.sender,
            _evmScriptFactory,
            _evmScriptCallData,
            evmScript
        );
    }

    /// @notice Enacts motion with given id
    /// @param _motionId Id of motion to enact
    /// @param _evmScriptCallData Encoded call data of EVMScript factory. Same as passed on the creation
    /// of motion with the given motion id. Transaction reverts if EVMScript factory call data differs
    function enactMotion(uint256 _motionId, bytes memory _evmScriptCallData)
        external
        whenNotPaused
    {
        Motion storage motion = _getMotion(_motionId);
        require(motion.startDate + motion.duration <= block.timestamp, ERROR_MOTION_NOT_PASSED);

        address creator = motion.creator;
        bytes32 evmScriptHash = motion.evmScriptHash;
        address evmScriptFactory = motion.evmScriptFactory;

        _deleteMotion(_motionId);
        emit MotionEnacted(_motionId);

        bytes memory evmScript = _createEVMScript(evmScriptFactory, creator, _evmScriptCallData);
        require(evmScriptHash == keccak256(evmScript), ERROR_UNEXPECTED_EVM_SCRIPT);

        evmScriptExecutor.executeEVMScript(evmScript);
    }

    /// @notice Submits an objection from `governanceToken` holder.
    /// @param _motionId Id of motion to object
    function objectToMotion(uint256 _motionId) external {
        Motion storage motion = _getMotion(_motionId);
        require(!objections[_motionId][msg.sender], ERROR_ALREADY_OBJECTED);
        objections[_motionId][msg.sender] = true;

        uint256 snapshotBlock = motion.snapshotBlock;
        uint256 objectorBalance = governanceToken.balanceOfAt(msg.sender, snapshotBlock);
        require(objectorBalance > 0, ERROR_NOT_ENOUGH_BALANCE);

        uint256 totalSupply = governanceToken.totalSupplyAt(snapshotBlock);
        uint256 newObjectionsAmount = motion.objectionsAmount + objectorBalance;
        uint256 newObjectionsAmountPct = (HUNDRED_PERCENT * newObjectionsAmount) / totalSupply;

        emit MotionObjected(
            _motionId,
            msg.sender,
            objectorBalance,
            newObjectionsAmount,
            newObjectionsAmountPct
        );

        if (newObjectionsAmountPct < motion.objectionsThreshold) {
            motion.objectionsAmount = newObjectionsAmount;
        } else {
            _deleteMotion(_motionId);
            emit MotionRejected(_motionId);
        }
    }

    /// @notice Cancels motion with given id
    /// @param _motionId Id of motion to cancel
    /// @dev Method reverts if it is called with not existed _motionId
    function cancelMotion(uint256 _motionId) external {
        Motion storage motion = _getMotion(_motionId);
        require(motion.creator == msg.sender, ERROR_NOT_CREATOR);
        _deleteMotion(_motionId);
        emit MotionCanceled(_motionId);
    }

    /// @notice Cancels all motions with given ids
    /// @param _motionIds Ids of motions to cancel
    function cancelMotions(uint256[] memory _motionIds) external onlyRole(CANCEL_ROLE) {
        for (uint256 i = 0; i < _motionIds.length; ++i) {
            if (motionIndicesByMotionId[_motionIds[i]] > 0) {
                _deleteMotion(_motionIds[i]);
                emit MotionCanceled(_motionIds[i]);
            }
        }
    }

    /// @notice Cancels all active motions
    function cancelAllMotions() external onlyRole(CANCEL_ROLE) {
        uint256 motionsCount = motions.length;
        while (motionsCount > 0) {
            motionsCount -= 1;
            uint256 motionId = motions[motionsCount].id;
            _deleteMotion(motionId);
            emit MotionCanceled(motionId);
        }
    }

    /// @notice Sets new EVMScriptExecutor
    /// @param _evmScriptExecutor Address of new EVMScriptExecutor
    function setEVMScriptExecutor(address _evmScriptExecutor)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        evmScriptExecutor = IEVMScriptExecutor(_evmScriptExecutor);
        emit EVMScriptExecutorChanged(_evmScriptExecutor);
    }

    /// @notice Pauses Easy Track if it isn't paused.
    /// Paused Easy Track can't create and enact motions
    function pause() external whenNotPaused onlyRole(PAUSE_ROLE) {
        _pause();
    }

    /// @notice Unpauses Easy Track if it is paused
    function unpause() external whenPaused onlyRole(UNPAUSE_ROLE) {
        _unpause();
    }

    /// @notice Returns if an _objector can submit an objection to motion with id equals to _motionId or not
    /// @param _motionId Id of motion to check opportunity to object
    /// @param _objector Address of objector
    function canObjectToMotion(uint256 _motionId, address _objector) external view returns (bool) {
        Motion storage motion = _getMotion(_motionId);
        uint256 balance = governanceToken.balanceOfAt(_objector, motion.snapshotBlock);
        return balance > 0 && !objections[_motionId][_objector];
    }

    /// @notice Returns list of active motions
    function getMotions() external view returns (Motion[] memory) {
        return motions;
    }

    /// @notice Returns motion with the given id
    /// @param _motionId Id of motion to retrieve
    function getMotion(uint256 _motionId) external view returns (Motion memory) {
        return _getMotion(_motionId);
    }

    // -------
    // PRIVATE METHODS
    // -------

    // Removes motion from list of active moitons
    // To delete a motion from the moitons array in O(1), we swap the element to delete with the last one in
    // the array, and then remove the last element (sometimes called as 'swap and pop').
    function _deleteMotion(uint256 _motionId) private {
        uint256 index = motionIndicesByMotionId[_motionId] - 1;
        uint256 lastIndex = motions.length - 1;

        if (index != lastIndex) {
            Motion storage lastMotion = motions[lastIndex];
            motions[index] = lastMotion;
            motionIndicesByMotionId[lastMotion.id] = index + 1;
        }

        motions.pop();
        delete motionIndicesByMotionId[_motionId];
    }

    // Returns motion with given id if it exists
    function _getMotion(uint256 _motionId) private view returns (Motion storage) {
        uint256 _motionIndex = motionIndicesByMotionId[_motionId];
        require(_motionIndex > 0, ERROR_MOTION_NOT_FOUND);
        return motions[_motionIndex - 1];
    }
}
