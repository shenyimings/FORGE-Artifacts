// SPDX-License-Identifier: GPL-3.0-only

// ┏━━━┓━━━━━┏┓━━━━━━━━━┏━━━┓━━━━━━━━━━━━━━━━━━━━━━━
// ┃┏━┓┃━━━━┏┛┗┓━━━━━━━━┃┏━━┛━━━━━━━━━━━━━━━━━━━━━━━
// ┃┗━┛┃┏━┓━┗┓┏┛┏━━┓━━━━┃┗━━┓┏┓┏━┓━┏━━┓━┏━┓━┏━━┓┏━━┓
// ┃┏━┓┃┃┏┓┓━┃┃━┃┏┓┃━━━━┃┏━━┛┣┫┃┏┓┓┗━┓┃━┃┏┓┓┃┏━┛┃┏┓┃
// ┃┃ ┃┃┃┃┃┃━┃┗┓┃┃━┫━┏┓━┃┃━━━┃┃┃┃┃┃┃┗┛┗┓┃┃┃┃┃┗━┓┃┃━┫
// ┗┛ ┗┛┗┛┗┛━┗━┛┗━━┛━┗┛━┗┛━━━┗┛┗┛┗┛┗━━━┛┗┛┗┛┗━━┛┗━━┛
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

pragma solidity ^0.7.0;

/// @title The interface for the Ante V0.5 Ante Pool Factory
/// @notice The Ante V0.5 Ante Pool Factory programmatically generates an AntePool for a given AnteTest
interface IAntePoolFactory {
    /// @notice Emitted when an AntePool is created from an AnteTest
    /// @param testAddr The address of the AnteTest used to create the AntePool
    /// @param testPool The address of the AntePool created by the factory
    event AntePoolCreated(address indexed testAddr, address testPool);

    /// @notice Creates an AntePool for an AnteTest and returns the AntePool address
    /// @param testAddr The address of the AnteTest to create an AntePool for
    /// @return testPool - The address of the generated AntePool
    function createPool(address testAddr) external returns (address testPool);

    /// @notice Returns a single address in the allPools array
    /// @param i The array index of the address to return
    /// @return The address of the i-th AntePool created by this factory
    function allPools(uint256 i) external view returns (address);

    /// @notice Returns the address of the AntePool corresponding to a given AnteTest
    /// @param testAddr address of the AnteTest to look up
    /// @return The address of the corresponding AntePool
    function poolMap(address testAddr) external view returns (address);
}
