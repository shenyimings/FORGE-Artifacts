// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./INFTUpgradeable.sol";

interface INFTPackage is INFTUpgradeable {
    struct NFTPackageConfig {
        string name;
        string desc;
        uint256 totalSupply;
        string cover;
    }

    function initialize(string memory name_, string memory symbol_, address owner_) external;
    function setPackage(NFTPackageConfig memory package_) external;
    function packageTokenCount(string memory pkg) external view returns (uint256);
    function tokenPackage(uint256 tokenId) external view returns (string memory);
    function mintTo(address to, string memory pkg, string memory uri) external;
}