// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "./interfaces/IEVMScriptExecutor.sol";

import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.2.0/contracts/access/AccessControlUpgradeable.sol";
import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.2.0/contracts/security/PausableUpgradeable.sol";

interface IMiniMeToken {
    function balanceOfAt(address _owner, uint256 _blockNumber) external pure returns (uint256);

    function totalSupplyAt(uint256 _blockNumber) external view returns (uint256);
}

struct Motion {
    uint256 id;
    address evmScriptFactory;
    address creator;
    uint256 duration;
    uint256 startDate;
    uint256 snapshotBlock;
    uint256 objectionsThreshold;
    uint256 objectionsAmount;
    uint256 objectionsAmountPct;
    bytes32 evmScriptHash;
}

/// @author psirex
/// @notice Keeps all variables of the EasyTrack
/// @dev All variables stored in this contract to simplify
/// future upgrades of Easy Track and and minimize the risk of storage collisions.
/// New variables can be added ONLY after already declared variables.
/// Existed variables CAN'T be deleted or reordered
contract EasyTrackStorage is Initializable, PausableUpgradeable, AccessControlUpgradeable {
    // -------------
    // EVENTS
    // -------------
    event MotionDurationChanged(uint256 _motionDuration);
    event MotionsCountLimitChanged(uint256 _newMotionsCountLimit);
    event ObjectionsThresholdChanged(uint256 _newThreshold);

    // -------------
    // ROLES
    // -------------
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    bytes32 public constant UNPAUSE_ROLE = keccak256("UNPAUSE_ROLE");
    bytes32 public constant CANCEL_ROLE = keccak256("CANCEL_ROLE");

    // ------------
    // CONSTANTS
    // ------------

    /// @notice Upper bound for motionsCountLimit variable.
    uint256 public constant MAX_MOTIONS_LIMIT = 24;

    /// @notice Upper bound for objectionsThreshold variable.
    /// @dev Stored in basis points (1% = 100)
    uint256 public constant MAX_OBJECTIONS_THRESHOLD = 500;

    /// @notice Lower bound for motionDuration variable
    uint256 public constant MIN_MOTION_DURATION = 48 hours;

    // ------------
    // MOTION SETTING VARIABLES
    // ------------

    /// @notice Percent from total supply of governance tokens required to reject motion.
    /// @dev Value stored in basis points: 1% == 100.
    uint256 public objectionsThreshold;

    /// @notice Max count of active motions
    uint256 public motionsCountLimit;

    /// @notice Minimal time required to pass before enacting of motion
    uint256 public motionDuration;

    // ------------
    // EVM SCRIPT FACTORIES VARIABLES
    // ------------

    /// @notice List of allowed EVMScript factories
    address[] public evmScriptFactories;

    // Position of the EVMScript factory in the `evmScriptFactories` array,
    // plus 1 because index 0 means a value is not in the set.
    mapping(address => uint256) internal evmScriptFactoryIndices;

    /// @notice Permissions of current list of allowed EVMScript factories.
    mapping(address => bytes) public evmScriptFactoryPermissions;

    // ------------
    // EASY TRACK VARIABLES
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

    /// @notice Initializes EasyTrackStorage variables with default values and calls initialize methods on base contracts.
    /// @dev This method can be called only once
    function __EasyTrackStorage_init(address _governanceToken, address _admin) public initializer {
        __Pausable_init();
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(PAUSE_ROLE, _admin);
        _setupRole(UNPAUSE_ROLE, _admin);
        _setupRole(CANCEL_ROLE, _admin);

        objectionsThreshold = 50;
        motionsCountLimit = MAX_MOTIONS_LIMIT;
        motionDuration = MIN_MOTION_DURATION;
        governanceToken = IMiniMeToken(_governanceToken);

        emit ObjectionsThresholdChanged(50);
        emit MotionsCountLimitChanged(MAX_MOTIONS_LIMIT);
        emit MotionDurationChanged(MIN_MOTION_DURATION);
    }
}
