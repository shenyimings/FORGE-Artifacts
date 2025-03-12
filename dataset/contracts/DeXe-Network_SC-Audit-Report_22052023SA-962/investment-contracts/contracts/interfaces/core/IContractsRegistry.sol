// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * This is the registry contract of DEXE platform that stores information about
 * the other contracts used by the protocol. Its purpose is to keep track of the propotol's
 * contracts, provide upgradeability mechanism and dependency injection mechanism.
 */
interface IContractsRegistry {
    /// @notice Used in dependency injection mechanism
    /// @return UserRegistry contract address
    function getUserRegistryContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return PoolFactory contract address
    function getPoolFactoryContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return PoolRegistry contract address
    function getPoolRegistryContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return DEXE token contract address
    function getDEXEContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return Wrapped native coin contract address
    function getWETHContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return Platform's native USD token contract address. This may be USDT/BUSD/USDC/DAI/FEI
    function getUSDContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return PriceFeed contract address
    function getPriceFeedContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return Treasury contract/wallet address
    function getTreasuryContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return CoreProperties contract address
    function getCorePropertiesContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return NetworkProperties contract address
    function getNetworkPropertiesContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return BABT contract address
    function getBABTContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return DexeExpertNft contract address
    function getDexeExpertNftContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return SphereX engine for DAOs
    function getPoolSphereXEngineContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return SphereX engine for global entities
    function getSphereXEngineContract() external view returns (address);
}
