// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @title Interface for voting escrow.
 */
interface IVotingEscrow {

    function balanceOf(address _account) external view returns (uint256);

    function deposit_for(address _account, uint256 _amount) external;

    function user_point_epoch(address _account) external view returns (uint256);

    function user_point_history__ts(address _account, uint256 _epoch) external view returns (uint256);
    
}