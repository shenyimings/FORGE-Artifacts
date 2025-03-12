// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IZeroTokenFactory
 * @dev Interface for the ZeroTokenFactory contract.
 */
interface IZeroTokenFactory {
    /**
     * @notice Deploys a new ZeroToken instance.
     * @param name The name of the ERC20 token.
     * @param symbol The symbol of the ERC20 token.
     * @param reserveToken The ERC20 token used as the reserve asset.
     * @param vaultEntryFeeBps The vault entry fee in basis points.
     * @param vaultExitFeeBps The vault exit fee in basis points.
     * @param protocolEntryFeeBps The protocol entry fee in basis points.
     * @param protocolExitFeeBps The protocol exit fee in basis points.
     * @param creatorEntryFeeBps The creator entry fee in basis points.
     * @param creatorExitFeeBps The creator exit fee in basis points.
     * @param protocolAddress The protocol fee recipient address.
     * @param adminAddress The default admin role address for the new ZeroToken.
     * @return zeroToken The address of the newly deployed ZeroToken contract.
     */
    function createZeroToken(
        string memory name,
        string memory symbol,
        IERC20 reserveToken,
        uint256 vaultEntryFeeBps,
        uint256 vaultExitFeeBps,
        uint256 protocolEntryFeeBps,
        uint256 protocolExitFeeBps,
        uint256 creatorEntryFeeBps,
        uint256 creatorExitFeeBps,
        address protocolAddress,
        address adminAddress
    ) external returns (address zeroToken);

    /**
     * @notice Returns the total number of ZeroTokens deployed by the factory.
     * @return count The number of ZeroToken instances.
     */
    function getZeroTokenCount() external view returns (uint256 count);

    /**
     * @notice Returns the address of a ZeroToken at a specific index.
     * @param index The index of the ZeroToken in the zeroTokens array.
     * @return zeroToken The address of the ZeroToken.
     */
    function getZeroToken(uint256 index) external view returns (address zeroToken);

    /**
     * @notice Returns all ZeroToken addresses deployed by a specific deployer.
     * @param deployer The address of the deployer.
     * @return zeroTokenList An array of ZeroToken addresses.
     */
    function getZeroTokensByDeployer(address deployer) external view returns (address[] memory zeroTokenList);

    /**
     * @notice Grants the FACTORY_ADMIN_ROLE to a new admin.
     * @param newAdmin The address to be granted the FACTORY_ADMIN_ROLE.
     */
    function addFactoryAdmin(address newAdmin) external;

    /**
     * @notice Revokes the FACTORY_ADMIN_ROLE from an admin.
     * @param admin The address to have the FACTORY_ADMIN_ROLE revoked.
     */
    function removeFactoryAdmin(address admin) external;
}
