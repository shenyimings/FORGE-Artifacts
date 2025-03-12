// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/access/AccessControl.sol";

/// @author psirex
/// @title Registry of allowed reward programs
/// @notice Stores list of addresses with reward programs
contract RewardProgramsRegistry is AccessControl {
    // -------------
    // EVENTS
    // -------------
    event RewardProgramAdded(address indexed _rewardProgram, string _title);
    event RewardProgramRemoved(address indexed _rewardProgram);

    // -------------
    // ROLES
    // -------------
    bytes32 public constant ADD_REWARD_PROGRAM_ROLE = keccak256("ADD_REWARD_PROGRAM_ROLE");
    bytes32 public constant REMOVE_REWARD_PROGRAM_ROLE = keccak256("REMOVE_REWARD_PROGRAM_ROLE");

    // -------------
    // ERRORS
    // -------------
    string private constant ERROR_REWARD_PROGRAM_ALREADY_ADDED = "REWARD_PROGRAM_ALREADY_ADDED";
    string private constant ERROR_REWARD_PROGRAM_NOT_FOUND = "REWARD_PROGRAM_NOT_FOUND";

    // -------------
    // VARIABLES
    // -------------

    /// @dev List of allowed reward program addresses
    address[] public rewardPrograms;

    // Position of the reward program in the `rewardPrograms` array,
    // plus 1 because index 0 means a value is not in the set.
    mapping(address => uint256) private rewardProgramIndices;

    // -------------
    // CONSTRUCTOR
    // -------------

    /// @param _admin Address which will be granted with role DEFAULT_ADMIN_ROLE
    /// @param _addRewardProgramRoleHolders List of addresses which will be
    ///     granted with role ADD_REWARD_PROGRAM_ROLE
    /// @param _removeRewardProgramRoleHolders List of addresses which will
    ///     be granted with role REMOVE_REWARD_PROGRAM_ROLE
    constructor(
        address _admin,
        address[] memory _addRewardProgramRoleHolders,
        address[] memory _removeRewardProgramRoleHolders
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        for (uint256 i = 0; i < _addRewardProgramRoleHolders.length; i++) {
            _setupRole(ADD_REWARD_PROGRAM_ROLE, _addRewardProgramRoleHolders[i]);
        }
        for (uint256 i = 0; i < _removeRewardProgramRoleHolders.length; i++) {
            _setupRole(REMOVE_REWARD_PROGRAM_ROLE, _removeRewardProgramRoleHolders[i]);
        }
    }

    // -------------
    // EXTERNAL METHODS
    // -------------

    /// @notice Adds address to list of allowed reward programs
    function addRewardProgram(address _rewardProgram, string memory _title)
        external
        onlyRole(ADD_REWARD_PROGRAM_ROLE)
    {
        require(rewardProgramIndices[_rewardProgram] == 0, ERROR_REWARD_PROGRAM_ALREADY_ADDED);

        rewardPrograms.push(_rewardProgram);
        rewardProgramIndices[_rewardProgram] = rewardPrograms.length;
        emit RewardProgramAdded(_rewardProgram, _title);
    }

    /// @notice Removes address from list of allowed reward programs
    /// @dev To delete a reward program from the rewardPrograms array in O(1), we swap the element to delete with the last one in
    /// the array, and then remove the last element (sometimes called as 'swap and pop').
    function removeRewardProgram(address _rewardProgram)
        external
        onlyRole(REMOVE_REWARD_PROGRAM_ROLE)
    {
        uint256 index = _getRewardProgramIndex(_rewardProgram);
        uint256 lastIndex = rewardPrograms.length - 1;

        if (index != lastIndex) {
            address lastRewardProgram = rewardPrograms[lastIndex];
            rewardPrograms[index] = lastRewardProgram;
            rewardProgramIndices[lastRewardProgram] = index + 1;
        }

        rewardPrograms.pop();
        delete rewardProgramIndices[_rewardProgram];
        emit RewardProgramRemoved(_rewardProgram);
    }

    /// @notice Returns if passed address are listed as reward program in the registry
    function isRewardProgram(address _maybeRewardProgram) external view returns (bool) {
        return rewardProgramIndices[_maybeRewardProgram] > 0;
    }

    /// @notice Returns current list of reward programs
    function getRewardPrograms() external view returns (address[] memory) {
        return rewardPrograms;
    }

    // ------------------
    // PRIVATE METHODS
    // ------------------

    function _getRewardProgramIndex(address _evmScriptFactory)
        private
        view
        returns (uint256 _index)
    {
        _index = rewardProgramIndices[_evmScriptFactory];
        require(_index > 0, ERROR_REWARD_PROGRAM_NOT_FOUND);
        _index -= 1;
    }
}
