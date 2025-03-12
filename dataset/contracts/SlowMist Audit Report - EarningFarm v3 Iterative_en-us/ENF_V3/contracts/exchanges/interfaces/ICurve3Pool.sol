// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICurve3Pool {
    function exchange(
        uint256 _amount,
        address[6] memory _route,
        uint256[8] memory _indices,
        uint256 _min_received,
        address _receiver
    ) external payable;

    function get_exchange_routing(
        address _initial,
        address _target,
        uint256 _amount
    )
        external
        view
        returns (
            address[6] memory,
            uint256[8] memory,
            uint256
        );
}
