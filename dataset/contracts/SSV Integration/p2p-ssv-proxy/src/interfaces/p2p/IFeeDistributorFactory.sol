// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../../@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../../access/IOwnable.sol";
import "./IFeeDistributor.sol";
import "../../structs/P2pStructs.sol";

/// @dev External interface of FeeDistributorFactory
interface IFeeDistributorFactory is IOwnable, IERC165 {

    /// @notice Creates a FeeDistributor instance for a client
    /// @dev _referrerConfig can be zero if there is no referrer.
    ///
    /// @param _referenceFeeDistributor The address of the reference implementation of FeeDistributor used as the basis for clones
    /// @param _clientConfig address and basis points (percent * 100) of the client
    /// @param _referrerConfig address and basis points (percent * 100) of the referrer.
    /// @return newFeeDistributorAddress user FeeDistributor instance that has just been deployed
    function createFeeDistributor(
        address _referenceFeeDistributor,
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) external returns (address newFeeDistributorAddress);

    /// @notice Computes the address of a FeeDistributor created by `createFeeDistributor` function
    /// @dev FeeDistributor instances are guaranteed to have the same address if all of
    /// 1) referenceFeeDistributor 2) clientConfig 3) referrerConfig
    /// are the same
    /// @param _referenceFeeDistributor The address of the reference implementation of FeeDistributor used as the basis for clones
    /// @param _clientConfig address and basis points (percent * 100) of the client
    /// @param _referrerConfig address and basis points (percent * 100) of the referrer.
    /// @return address user FeeDistributor instance that will be or has been deployed
    function predictFeeDistributorAddress(
        address _referenceFeeDistributor,
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) external view returns (address);

    /// @notice Returns an array of client FeeDistributors
    /// @param _client client address
    /// @return address[] array of client FeeDistributors
    function allClientFeeDistributors(
        address _client
    ) external view returns (address[] memory);

    /// @notice Returns an array of all FeeDistributors for all clients
    /// @return address[] array of all FeeDistributors
    function allFeeDistributors() external view returns (address[] memory);

    /// @notice The address of P2pEth2Depositor
    /// @return address of P2pEth2Depositor
    function p2pEth2Depositor() external view returns (address);

    /// @notice Returns default client basis points
    /// @return default client basis points
    function defaultClientBasisPoints() external view returns (uint96);

    /// @notice Returns the current operator
    /// @return address of the current operator
    function operator() external view returns (address);

    /// @notice Reverts if the passed address is neither operator nor owner
    /// @param _address passed address
    function checkOperatorOrOwner(address _address) external view;

    /// @notice Reverts if the passed address is not P2pEth2Depositor
    /// @param _address passed address
    function checkP2pEth2Depositor(address _address) external view;

    /// @notice Reverts if the passed address is neither of: 1) operator 2) owner 3) P2pEth2Depositor
    /// @param _address passed address
    function check_Operator_Owner_P2pEth2Depositor(address _address) external view;
}
