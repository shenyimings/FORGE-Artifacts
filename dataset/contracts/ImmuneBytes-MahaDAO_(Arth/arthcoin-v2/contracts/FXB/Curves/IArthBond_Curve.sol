// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IArthBond_Curve {
    function get_total_points(uint8 curve_choice)
        external
        view
        returns (uint32);

    function get_curve_point(uint8 curve_choice, uint8 index)
        external
        view
        returns (uint32);
}
