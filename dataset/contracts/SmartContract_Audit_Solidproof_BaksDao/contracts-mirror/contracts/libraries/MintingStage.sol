// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library MintingStage {
    function split(uint256 mintingStage) internal pure returns (uint256 totalValueLocked, uint256 amount) {
        amount = mintingStage & type(uint128).max;
        totalValueLocked = mintingStage >> 128;
    }
}
