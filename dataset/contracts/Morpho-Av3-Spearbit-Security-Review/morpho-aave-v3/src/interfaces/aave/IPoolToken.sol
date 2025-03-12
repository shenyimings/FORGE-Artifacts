// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IPoolToken {
    /**
     * @notice Returns the address of the underlying asset of this aToken (E.g. WETH for aWETH)
     * @return The address of the underlying asset
     */
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}
