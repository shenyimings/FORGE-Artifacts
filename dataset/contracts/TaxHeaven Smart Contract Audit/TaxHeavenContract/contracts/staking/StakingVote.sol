// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.1;

import "../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

contract StakingVote {
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */

    address internal _governanceAddress;
    mapping(address => uint256) internal _voteNum;

    /* ========== EVENTS ========== */

    event LogUpdateGovernanceAddress(address newAddress);

    /* ========== CONSTRUCTOR ========== */

    constructor(address governanceAddress) {
        _governanceAddress = governanceAddress;
    }

    /* ========== MODIFIERS ========== */

    modifier isGovernance(address account) {
        require(account == _governanceAddress, "sender must be governance address");
        _;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice `_governanceAddress` can be updated by the current governance address.
     * @dev Executed only once when initially set the governance address
     * as the governance contract does not have the function to call this function.
     */
    function updateGovernanceAddress(address newGovernanceAddress)
        external
        isGovernance(msg.sender)
    {
        _governanceAddress = newGovernanceAddress;

        emit LogUpdateGovernanceAddress(newGovernanceAddress);
    }

    function voteDeposit(address account, uint256 amount) external isGovernance(msg.sender) {
        _updVoteSub(account, amount);
    }

    function voteWithdraw(address account, uint256 amount) external isGovernance(msg.sender) {
        _updVoteAdd(account, amount);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _updVoteAdd(address account, uint256 amount) internal {
        require(_voteNum[account] + amount >= amount, "overflow the amount of votes");
        _voteNum[account] += amount;
    }

    function _updVoteSub(address account, uint256 amount) internal {
        require(_voteNum[account] >= amount, "underflow the amount of votes");
        _voteNum[account] -= amount;
    }

    /* ========== CALL FUNCTIONS ========== */

    function getGovernanceAddress() external view returns (address) {
        return _governanceAddress;
    }

    function getVoteNum(address account) external view returns (uint256) {
        return _voteNum[account];
    }
}
