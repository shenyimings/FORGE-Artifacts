// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {CumulativeMerkleClaim} from "./../../payment/CumulativeMerkleClaim.sol";

contract CumulativeMerkleClaimMock is CumulativeMerkleClaim {
    event Distributed(address recipient, uint256 amount);

    function _distributePayout(address recipient, bytes calldata claimData) internal virtual override {
        uint256 amount = abi.decode(claimData, (uint256));
        emit Distributed(recipient, amount);
    }
}
