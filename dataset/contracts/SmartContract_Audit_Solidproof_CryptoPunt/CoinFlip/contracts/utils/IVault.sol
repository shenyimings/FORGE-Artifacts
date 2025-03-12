// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IVault {
    // call player token
    //function tokenInboundTransfer(address _from, uint128 _amount) external;

    function addGameBalance(address _player, uint128 _amount) external;

    function subGameBalance(
        address _player,
        uint128 _balance,
        uint128 _fee
    ) external;

    function addReserveOperating(uint128 _amount) external;

    function subReserveOperating(uint128 _amount) external;

    // function getGameIndex(address _addr) external view returns (uint8);

    // send token to player
    // function tokenOutboundTransfer(
    //     address _to,
    //     uint128 _amount,
    //     uint128 _fee
    // ) external;

    // token interfaces
    // function checkApproval(address _userAddress)
    //     external
    //     view
    //     returns (uint256);

    // function balanceOf(address _userAddress) external view returns (uint256);

    // player ledger
}
