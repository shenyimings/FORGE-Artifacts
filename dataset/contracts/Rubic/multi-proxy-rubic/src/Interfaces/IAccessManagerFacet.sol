// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IAccessManagerFacet {
    event ExecutionAllowed(address indexed account, bytes4 indexed method);
    event ExecutionDenied(address indexed account, bytes4 indexed method);

    /// @notice Sets whether a specific address can call a method
    /// @param _selector The method selector to set access for
    /// @param _executor The address to set method access for
    /// @param _canExecute Whether or not the address can execute the specified method
    function setCanExecute(
        bytes4 _selector,
        address _executor,
        bool _canExecute
    ) external;

    /// @notice Check if a method can be executed by a specific address
    /// @param _selector The method selector to check
    /// @param _executor The address to check
    function addressCanExecuteMethod(
        bytes4 _selector,
        address _executor
    ) external view returns (bool);
}
