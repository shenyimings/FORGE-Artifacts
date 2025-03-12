// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.6;

interface IPriceFeed {
    /// @notice Returns the amount of swapped token 
    /// 
    /// @return The amount of swapped token
    function consult(
        address token,
        uint256 amount
    ) external view returns (uint256);
}
