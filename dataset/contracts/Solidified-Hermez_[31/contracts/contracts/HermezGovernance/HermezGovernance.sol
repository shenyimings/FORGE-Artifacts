// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @dev Smart Contract in charge of managing Hermez's governance through access control by using roles
 */
contract HermezGovernance is AccessControl {
    event ExecOk(bytes returnData);
    event ExecFail(bytes returnData);

    mapping (bytes32 => bool) public forbidden;

    /**
     * @dev decentralizes a specific role. Once decentralized it cannot be called again
     * @param role The role to be decentralized
     */
    function decentralize(
        bytes32 role
    ) external {
        require(
            address(this) == msg.sender,
            "HermezGovernance::decentralize ONLY_GOVERNANCE"
        );
        forbidden[role] = true;
    }

    /**
     * @dev constructor function
     * @param communityCouncil Address in charge of handling all roles
     */
    constructor(address communityCouncil) public {
        _setupRole(DEFAULT_ADMIN_ROLE, communityCouncil);
    }

    /**
     * @dev Function to execute a call. The msg.sender should have the role to be able to execute it
     * @param destination address to which the call will be made
     * @param value call value
     * @param data data of the call to make
     */
    function execute(
        address destination,
        uint256 value,
        bytes memory data
    ) external {
        // Decode the signature
        bytes4 dataSignature = abi.decode(data, (bytes4));
        bytes32 role = keccak256(abi.encodePacked(destination, dataSignature));
        require(
            hasRole(role, msg.sender),
            "HermezGovernance::execute: ONLY_ALLOWED_ROLE"
        );

        require(
            !forbidden[role],
            "HermezGovernance::execute: FORBIDDEN_ROLE"
        );

        (bool succcess, bytes memory returnData) = destination.call{
            value: value
        }(data);
        if (succcess) {
            emit ExecOk(returnData);
        } else {
            emit ExecFail(returnData);
        }
    }
}
