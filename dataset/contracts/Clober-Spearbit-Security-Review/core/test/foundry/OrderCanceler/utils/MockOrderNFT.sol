// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

contract MockOrderNFT {
    function cancel(
        address from,
        uint256[] calldata tokenIds,
        address canceledAssetReceiver
    ) external pure {
        from;
        tokenIds;
        canceledAssetReceiver;
    }
}
