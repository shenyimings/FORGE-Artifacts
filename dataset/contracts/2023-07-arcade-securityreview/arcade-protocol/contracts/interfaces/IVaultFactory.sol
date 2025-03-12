// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./INFTWithDescriptor.sol";

interface IVaultFactory is INFTWithDescriptor {
    // ============= Events ==============

    event VaultCreated(address vault, address to);
    event ClaimFees(address owner, uint256 amount);

    // ================ View Functions ================

    function isInstance(address instance) external view returns (bool validity);

    function instanceCount() external view returns (uint256);

    function instanceAt(uint256 tokenId) external view returns (address);

    function instanceAtIndex(uint256 index) external view returns (address);

    // ================ Factory Operations ================

    function initializeBundle(address to) external payable returns (uint256);
}
