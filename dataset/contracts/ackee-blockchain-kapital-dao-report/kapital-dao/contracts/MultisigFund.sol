// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./Transactor.sol";

/**
 * @title Kapital DAO Multisig Fund
 * @author Playground Labs
 * @custom:security-contact security@playgroundlabs.io
 * @notice A storage mechanism for funds owned by a multisig, usually a
 * multisig owned by the Kapital DAO core team. Arbitrary actions can be
 * performed with these funds via a multisig action.
 */
contract MultisigFund is Transactor {
    address public immutable multisig;

    constructor(address _multisig) {
        require(_multisig != address(0), "Zero address");
        
        multisig = _multisig;
    }

    /**
     * @dev Can only be called by {multisig}
     * @dev See {Transactor} for more details
     */
    function transact(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory data
    ) external payable {
        require(msg.sender == multisig, "Only multisig");
        _transact(targets, values, data);
    }
}
