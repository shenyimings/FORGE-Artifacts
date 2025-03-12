// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IAmpleforth } from "./IAmpleforth.sol";

interface IAMPL is IERC20Upgradeable {
    function monetaryPolicy() external view returns (IAmpleforth);
}
