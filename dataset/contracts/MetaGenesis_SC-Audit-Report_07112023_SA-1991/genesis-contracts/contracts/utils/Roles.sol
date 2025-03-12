// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title Roles
 * @dev A smart contract for managing roles and permissions.
 */
contract Roles is AccessControl, Initializable {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    /// @notice  The current number of validators
    uint256 public currentValidatorId;

    /// @notice An array to maintain the list of validators
    mapping(uint256 => address) public validatorList;

    /**
     * @dev Initializes the Roles contract with the initial owner's address.
     * @param ownerAddress The address of the initial owner.
     */
    function initialize(address ownerAddress) external initializer {
        require(ownerAddress != address(0), "Roles: cannot set zero address");
        _grantRole(OWNER_ROLE, ownerAddress);
        _setRoleAdmin(MANAGER_ROLE, OWNER_ROLE);
        _setRoleAdmin(VALIDATOR_ROLE, OWNER_ROLE);
    }

    /**
     * @dev Returns the current validator based on the block number.
     * @return The address of the picked validator.
     */
    function pickValidator() external view returns (address) {
        uint256 queueNumber = block.number % currentValidatorId;
        address pickedValidator = validatorList[queueNumber];
        return pickedValidator;
    }

    /**
     * @dev Grants a role to an account, with additional handling for the VALIDATOR_ROLE.
     * @param role The role to grant.
     * @param account The address to which the role will be granted.
     */
    function grantRole(
        bytes32 role,
        address account
    ) public virtual override onlyRole(getRoleAdmin(role)) {
        if (role == VALIDATOR_ROLE) {
            validatorList[currentValidatorId] = account;

            currentValidatorId++;
        }

        super.grantRole(role, account);
    }
}
