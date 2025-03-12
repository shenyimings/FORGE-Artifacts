// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IGovernorProposalQuorum {
    /**
     * @dev Returns the quorum numerator for a specific proposalId.
     */
    function quorumNumerator(uint256 proposalId) external view returns (uint128);

    /**
     * @dev Returns the quorum denominator for a specific proposalId.
     */
    function quorumDenominator(uint256 proposalId) external view returns (uint128);

    /**
     * @dev Returns the quorum for a specific proposal's counting token, in terms of number of votes: `supply * numerator / denominator`.
     */
    function quorum(uint256 proposalId) external view returns (uint256);
}
