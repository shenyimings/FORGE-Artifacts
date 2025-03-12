// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC165} from "@diamond/interfaces/IERC165.sol";

interface ILegacyMintableERC20 is IERC165 {
    /**
     * @notice returns the address of the paired ERC20 token on L1
     * @dev this is part of the ILegacyMintableERC20 interface
     */
    function l1Token() external returns (address);
    /**
     * @notice mints tokens on L2
     * @param account address to mint tokens to
     * @param amount amount of tokens to mint
     * @dev overriden so we can emit Mint, which is part of the IL2StandardERC20 interface
     */
    function mint(address account, uint256 amount) external;
    /**
     * @notice burns tokens on L2
     * @param account address to burn tokens from
     * @param amount amount of tokens to burn
     * @dev overriden so we can emit Burn, which is part of the IL2StandardERC20 interface
     */
    function burn(address account, uint256 amount) external;
}

interface IL2StandardERC20 is ILegacyMintableERC20 {
    /// @dev emitted when the L1 token address is updated
    event L1TokenUpdated(address indexed oldL1Token, address indexed newL1Token);
    /// @dev emitted when the L2 bridge address is updated
    event L2BridgeUpdated(address indexed oldL2Bridge, address indexed newL2Bridge);
    /// @dev emitted when tokens are minted
    event Mint(address indexed _account, uint256 _amount);
    /// @dev emitted when tokens are burned
    event Burn(address indexed _account, uint256 _amount);

    /**
     * @notice returns the address of the bridge contract on L2
     * @dev this is _not_ part of the ILegacyMintableERC20 interface, but is still required for compatibility
     */
    function l2Bridge() external returns (address);
}
