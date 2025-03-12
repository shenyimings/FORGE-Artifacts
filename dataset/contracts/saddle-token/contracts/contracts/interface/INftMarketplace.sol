// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

// interface for NftMarketplace
interface INftMarketplace {
    function whitelistERC20(address) external view returns (bool);
}
