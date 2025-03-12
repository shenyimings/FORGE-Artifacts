// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (port from token/ERC20/extensions/draft-ERC20Permit.sol)

pragma solidity ^0.8.0;

interface IScriptEngine {
    /**
     * this func create a bucket from msg.sender, voted to candidate
     * will revert if any error happens
     */
    function bucketOpen(address candidate, uint256 amount)
        external
        returns (bytes32 bktID);

    /**
     * this func adds more value to the designated bucket owned by msg.sender
     * will revert if any error happens
     */
    function bucketDeposit(bytes32 bucketID, uint256 amount) external;

    /**
     * this func withdraw value from the designated bucket owned by msg.sender, createsa sub bucket to `recipient`
     * `recipient` will receive funds after bucket mature time
     * will revert if any error happens
     */
    function bucketWithdraw(
        bytes32 bucketID,
        uint256 amount,
        address recipient
    ) external returns (bytes32 newBktID);

    /**
     * this func withdraw all value from the designated bucket owned by msg.sender, and completely close this bucket
     * `owner` will receive funds after bucket mature time
     * will revert if any error happens
     */
    function bucketClose(bytes32 bucketID) external;

    function bucketUpdateCandidate(bytes32 bucketID, address newCandidateAddr)
        external;

    function boundedMTRG() external view returns (uint256);
}
