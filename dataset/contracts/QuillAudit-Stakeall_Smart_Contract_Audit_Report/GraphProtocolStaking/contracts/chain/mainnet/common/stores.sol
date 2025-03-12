// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import {MemoryInterface} from "./interfaces.sol";

abstract contract Stores {
    /**
     * @dev Return ethereum address
     */
    address internal constant ethAddr =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /**
     * @dev Return Wrapped ETH address
     */
    address internal constant wethAddr =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * @dev Return memory variable address
     */
    MemoryInterface internal constant stakeAllMemory =
        MemoryInterface(0x0A25F019be4C4aAa0B04C0d43dff519dc720D275);

    uint256 public constant PORTIONS_SUM = 1000000;

    /**
     * @dev Get Uint value from StakeAllMemory Contract.
     */
    function getUint(uint256 getId, uint256 val)
        internal
        returns (uint256 returnVal)
    {
        returnVal = getId == 0 ? val : stakeAllMemory.getUint(getId);
    }

    /**
     * @dev Set Uint value in StakeAllMemory Contract.
     */
    function setUint(uint256 setId, uint256 val) internal virtual {
        if (setId != 0) stakeAllMemory.setUint(setId, val);
    }
}
