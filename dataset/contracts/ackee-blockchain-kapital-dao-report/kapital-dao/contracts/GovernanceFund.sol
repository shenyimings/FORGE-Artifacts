// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./interfaces/IGovernanceRegistry.sol";
import "./Transactor.sol";

/**
 * @title Kapital DAO Governance Fund
 * @author Playground Labs
 * @custom:security-contact security@playgroundlabs.io
 * @notice A storage mechanism for funds owned by the Kapital DAO. Arbitrary
 * actions can be performed with these funds via DAO vote.
 */
contract GovernanceFund is Transactor {
    IGovernanceRegistry public immutable governanceRegistry; // used to query the latest governance address

    constructor(address _governanceRegistry) {
        require(_governanceRegistry != address(0), "GovernanceFund: Zero address");
        governanceRegistry = IGovernanceRegistry(_governanceRegistry);
    }

    /**
     * @dev Can only be called by latest governance contract
     * @dev See {Transactor} for more details
     */
    function transact(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory data
    ) external payable {
        require(msg.sender == governanceRegistry.governance(), "GovernanceFund: Only governance");
        _transact(targets, values, data);
    }
}
