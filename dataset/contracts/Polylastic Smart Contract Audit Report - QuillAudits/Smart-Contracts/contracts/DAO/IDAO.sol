// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IDAO {
    /**
     * @dev add a new selector.
     */
    function addSelector(bytes4 selector) external;

    /**
     * @dev remove a selector.
     */
    function removeSelector(bytes4 selector) external;

    /**
     * @dev replenishment of the user's balance
     */
    function deposit(uint256 amount) external;

    /**
     * @dev withdrawal of the user's balance
     */
    function withdraw() external;

    /**
     * @dev adding a new proposal
     * @param recipient the address of the contract on which the signature will be called
     * @param callData signature function
     * @param startTime voting start time
     */
    function addProposal(
        address recipient,
        bytes calldata callData,
        uint256 startTime
    ) external;

    /**
     * @dev voting for the proposal
     * @param proposalId id of voting
     * @param supportAgainst vote for (true) or against (false)
     */
    function vote(uint256 proposalId, bool supportAgainst) external;

    /**
     * @dev end the vote
     * @param proposalId id of voting
     */
    function finishVote(uint256 proposalId) external;

    function isValidSignature(bytes4 selector) external view returns (bool);
}
