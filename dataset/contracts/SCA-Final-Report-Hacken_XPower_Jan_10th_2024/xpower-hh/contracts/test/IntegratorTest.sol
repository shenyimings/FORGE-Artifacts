// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Integrator} from "../libs/Integrator.sol";

contract IntegratorTest {
    Integrator.Item[] public items;

    function headOf() public view returns (Integrator.Item memory) {
        return Integrator.headOf(items);
    }

    function lastOf() public view returns (Integrator.Item memory) {
        return Integrator.lastOf(items);
    }

    function meanOf(uint256 stamp, uint256 value) public view returns (uint256) {
        return Integrator.meanOf(items, stamp, value);
    }

    function areaOf(uint256 stamp, uint256 value) public view returns (uint256) {
        return Integrator.areaOf(items, stamp, value);
    }

    function append(uint256 stamp, uint256 value) public {
        Integrator.append(items, stamp, value);
    }
}
