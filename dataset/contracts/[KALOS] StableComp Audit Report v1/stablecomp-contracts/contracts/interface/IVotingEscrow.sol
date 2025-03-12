// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IVotingEscrow {
    function transfer_ownership(address) external;
    function commit_smart_wallet_checker(address) external;
    function get_last_user_slope(address) external view returns (int128);
    function user_point_history__ts(address, uint256) external view returns (uint256);
    function locked__end(address) external view returns (uint256);
    function checkpoint() external;
    function deposit_for(address, uint256) external;
    function create_lock(uint256, uint256) external ;
    function increase_amount(uint256) external;
    function increase_unlock_time(uint256) external;
    function withdraw() external;
    function balanceOf(address) external view returns (uint256);
    function balanceOfAt(address, uint256) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalSupplyAt(uint256) external view returns (uint256);
    function locked(address) external view returns(int128, uint256);
}
