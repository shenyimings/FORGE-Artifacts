// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ZeroToken.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ZeroTokenFactory
 * @dev Factory contract for deploying instances of ZeroToken.
 * Provides functionality to create ZeroTokens and keeps track of all deployed instances.
 */
contract ZeroTokenFactory is AccessControl {
    /// @notice Role definitions
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN_ROLE");

    /// @notice Array of all deployed ZeroToken addresses
    address[] private zeroTokens;

    /// @notice Mapping from deployer address to their deployed ZeroTokens
    mapping(address => address[]) private deployerZeroTokens;

    /// @notice Emitted when a new ZeroToken is deployed.
    /// @param zeroTokenAddress The address of the deployed ZeroToken.
    /// @param deployer The address that initiated the deployment.
    event ZeroTokenCreated(address indexed zeroTokenAddress, address indexed deployer);

    /**
     * @dev Initializes the contract by setting up the admin role.
     * @param adminAddress The address to be granted the DEFAULT_ADMIN_ROLE and FACTORY_ADMIN_ROLE.
     */
    constructor(address adminAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(FACTORY_ADMIN_ROLE, adminAddress);
    }

    /**
     * @notice Deploys a new ZeroToken instance.
     * @dev Only accounts with FACTORY_ADMIN_ROLE can call this function.
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
    ) external onlyRole(FACTORY_ADMIN_ROLE) returns (address zeroToken) {
        // Deploy new ZeroToken
        ZeroToken token = new ZeroToken(
            name,
            symbol,
            reserveToken,
            vaultEntryFeeBps,
            vaultExitFeeBps,
            protocolEntryFeeBps,
            protocolExitFeeBps,
            creatorEntryFeeBps,
            creatorExitFeeBps,
            protocolAddress,
            adminAddress
        );

        // Transfer the CREATOR_ROLE to the msg.sender (deployer)
        token.grantRole(CREATOR_ROLE, msg.sender);
        token.renounceRole(CREATOR_ROLE, address(this));

        // Store the new ZeroToken address
        zeroTokens.push(address(token));
        deployerZeroTokens[msg.sender].push(address(token));

        emit ZeroTokenCreated(address(token), msg.sender);

        return address(token);
    }

    /**
     * @notice Returns the total number of ZeroTokens deployed by the factory.
     * @return count The number of ZeroToken instances.
     */
    function getZeroTokenCount() external view returns (uint256 count) {
        return zeroTokens.length;
    }

    /**
     * @notice Returns the address of a ZeroToken at a specific index.
     * @param index The index of the ZeroToken in the zeroTokens array.
     * @return zeroToken The address of the ZeroToken.
     */
    function getZeroToken(uint256 index) external view returns (address zeroToken) {
        require(index < zeroTokens.length, "Index out of bounds");
        return zeroTokens[index];
    }

    /**
     * @notice Returns all ZeroToken addresses deployed by a specific deployer.
     * @param deployer The address of the deployer.
     * @return zeroTokenList An array of ZeroToken addresses.
     */
    function getZeroTokensByDeployer(address deployer) external view returns (address[] memory zeroTokenList) {
        return deployerZeroTokens[deployer];
    }

    /**
     * @notice Grants the FACTORY_ADMIN_ROLE to a new admin.
     * @dev Only accounts with DEFAULT_ADMIN_ROLE can call this function.
     * @param newAdmin The address to be granted the FACTORY_ADMIN_ROLE.
     */
    function addFactoryAdmin(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(FACTORY_ADMIN_ROLE, newAdmin);
    }

    /**
     * @notice Revokes the FACTORY_ADMIN_ROLE from an admin.
     * @dev Only accounts with DEFAULT_ADMIN_ROLE can call this function.
     * @param admin The address to have the FACTORY_ADMIN_ROLE revoked.
     */
    function removeFactoryAdmin(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(FACTORY_ADMIN_ROLE, admin);
    }

    /**
     * @dev Override supportsInterface to include AccessControl.
     * @param interfaceId The interface identifier, as specified in ERC-165.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
