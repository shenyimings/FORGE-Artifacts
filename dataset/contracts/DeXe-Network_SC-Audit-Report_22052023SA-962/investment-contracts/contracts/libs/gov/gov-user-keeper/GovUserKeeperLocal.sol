// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library GovUserKeeperLocal {
    function exec(
        function(address, address, uint256) external tokenFunc,
        address user,
        uint256 amount
    ) internal {
        if (amount == 0) {
            return;
        }

        tokenFunc(msg.sender, user, amount);
    }

    function exec(
        function(address, uint256) external tokenFunc,
        address user,
        uint256 amount
    ) internal {
        if (amount == 0) {
            return;
        }

        tokenFunc(user, amount);
    }

    function exec(
        function(address, address, uint256[] memory) external nftFunc,
        address user,
        uint256[] calldata nftIds
    ) internal {
        if (nftIds.length == 0) {
            return;
        }

        nftFunc(msg.sender, user, nftIds);
    }

    function exec(
        function(address, uint256[] memory) external nftFunc,
        address user,
        uint256[] calldata nftIds
    ) internal {
        if (nftIds.length == 0) {
            return;
        }

        nftFunc(user, nftIds);
    }
}
