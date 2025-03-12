// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BEP20Interface.sol";

interface VBep20Interface is BEP20Interface {
    /**
     * @notice Underlying asset for this VToken
     */
    function underlying() external view returns (address);
}
