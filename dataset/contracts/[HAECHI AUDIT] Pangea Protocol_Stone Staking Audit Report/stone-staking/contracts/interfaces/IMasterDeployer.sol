// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0;

/// @notice pool deployer interface.
interface IMasterDeployer {
    // ============ EVENTS ================
    event DeployPool(address indexed factory, address indexed pool, bytes deployData);
    event AddToWhitelistFactory(address indexed factory);
    event RemoveFromWhitelistFactory(address indexed factory);
    event ProtocolFeeToUpdated(address protocolFeeTo);

    /// @notice create pool through factory
    function deployPool(address factory, bytes calldata deployData) external returns (address);

    /// @notice Return the address receiving protocol fees from Pool
    function protocolFeeTo() external view returns (address);

    /// @notice Return whether the pool was deployed via a deployer
    function pools(address pool) external view returns (bool);

    /// @notice LP Airdrop Distributor address
    function airdropDistributor() external returns (address);

    /// @notice Return the number of pools deployed from masterDeployer
    function totalPoolsCount() external view returns (uint256 total);

    /// @notice Return the address of pool by index
    function getPoolAddress(uint256 idx) external view returns (address pool);

    /// @notice Return the address of Factory deployed pool
    function getFactoryAddress(address pool) external view returns (address factory);
}
