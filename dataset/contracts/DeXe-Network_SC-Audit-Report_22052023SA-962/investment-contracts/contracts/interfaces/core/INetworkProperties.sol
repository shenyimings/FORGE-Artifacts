// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface INetworkProperties {
    /// @notice Used to unwrap WEth out of SphereX-controlled beacon and return to the sender
    /// @param amount The amount to unwrap
    function unwrapWeth(uint256 amount) external;

    /// @notice Used in native coin governance mechanism
    /// @return The current full supply of native coin
    function getNativeSupply() external view returns (uint256);
}
