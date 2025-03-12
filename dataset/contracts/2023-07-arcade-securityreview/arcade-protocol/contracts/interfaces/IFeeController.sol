// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IFeeController {
    // ================ Events =================

    event SetFee(bytes32 indexed id, uint256 fee);

    // ================ Getter/Setter =================

    function get(bytes32 id) external view returns (uint256);

    function set(bytes32 id, uint256 fee) external;

    function getMaxFee(bytes32 id) external view returns (uint256);
}