// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import { IAmpleforthOracle } from "./IAmpleforthOracle.sol";

interface IAmpleforth {
    function cpiOracle() external view returns (IAmpleforthOracle);
}
