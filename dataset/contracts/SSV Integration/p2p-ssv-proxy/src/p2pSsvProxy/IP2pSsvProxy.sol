// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../structs/P2pStructs.sol";
import "../access/IOwnableWithOperator.sol";
import "../interfaces/ssv/ISSVNetwork.sol";

/// @dev External interface of P2pSsvProxy declared to support ERC165 detection.
interface IP2pSsvProxy is IOwnableWithOperator, IERC165 {

    /// @notice Emits when P2pSsvProxy instance is initialized
    /// @param _feeDistributor FeeDistributor instance that determines the identity of this P2pSsvProxy instance
    event P2pSsvProxy__Initialized(
        address indexed _feeDistributor
    );

    /// @notice Emits when the function was called successfully on SSVNetwork via fallback
    /// @param _caller caller of P2pSsvProxy
    /// @param _selector selector of the function from SSVNetwork
    event P2pSsvProxy__SuccessfullyCalledViaFallback(
        address indexed _caller,
        bytes4 indexed _selector
    );

    /// @notice Emits when an error occurred during the call of SSVNetwork via fallback
    /// @param _caller caller of P2pSsvProxy
    /// @param _selector selector of the function from SSVNetwork
    event P2pSsvProxy__CallingViaFallbackFailed(
        address indexed _caller,
        bytes4 indexed _selector
    );

    /// @notice Initialize the P2pSsvProxy instance
    /// @dev Should only be called by P2pSsvProxyFactory
    /// @param _feeDistributor FeeDistributor instance that determines the identity of this P2pSsvProxy instance
    function initialize(
        address _feeDistributor
    ) external;

    /// @notice Register a batch of validators with SSV
    /// @dev Should be called by P2pSsvProxyFactory only
    /// @param _ssvPayload struct with the SSV data required for registration
    /// @param _feeDistributorInstance instance of FeeDistributor to be used as EL fee recipient in SSV
    function registerValidators(
        SsvPayload calldata _ssvPayload,
        address _feeDistributorInstance
    ) external;

    /// @notice Remove a batch of validators from SSV
    /// @dev Can be called either by P2P or by the client
    /// @param _pubkeys validator pubkeys
    /// @param _operatorIds SSV operator IDs
    /// @param _clusters SSV clusters, each of which should correspond to pubkey and operator IDs
    function removeValidators(
        bytes[] calldata _pubkeys,
        uint64[] calldata _operatorIds,
        ISSVNetwork.Cluster[] calldata _clusters
    ) external;

    /// @notice Liquidate SSV clusters
    /// @dev Should be called by P2P only.
    /// This function is just batching calls for convenience. It's always possible to call the same function on SSVNetwork via fallback
    /// @param _operatorIds SSV operator IDs
    /// @param _clusters SSV clusters
    function liquidate(
        uint64[] calldata _operatorIds,
        ISSVNetwork.Cluster[] calldata _clusters
    ) external;

    /// @notice Reactivate SSV clusters
    /// @dev Should be called by P2P only
    /// This function is just batching calls for convenience. It's always possible to call the same function on SSVNetwork via fallback
    /// @param _tokenAmount SSV token amount to be deposited for reactivation
    /// @param _operatorIds SSV operator IDs
    /// @param _clusters SSV clusters
    function reactivate(
        uint256 _tokenAmount,
        uint64[] calldata _operatorIds,
        ISSVNetwork.Cluster[] calldata _clusters
    ) external;

    /// @notice Deposit SSV tokens to SSV clusters
    /// @dev Can be called by anyone
    /// This function is just batching calls for convenience. It's possible to call the same function on SSVNetwork directly
    /// @param _tokenAmount SSV token amount to be deposited
    /// @param _operatorIds SSV operator IDs
    /// @param _clusters SSV clusters
    function depositToSSV(
        uint256 _tokenAmount,
        uint64[] calldata _operatorIds,
        ISSVNetwork.Cluster[] calldata _clusters
    ) external;

    /// @notice Withdraw SSV tokens from SSV clusters to this contract
    /// @dev Should be called by P2P only
    /// This function is just batching calls for convenience. It's always possible to call the same function on SSVNetwork via fallback
    /// @param _tokenAmount SSV token amount to be withdrawn
    /// @param _operatorIds SSV operator IDs
    /// @param _clusters SSV clusters
    function withdrawFromSSV(
        uint256 _tokenAmount,
        uint64[] calldata _operatorIds,
        ISSVNetwork.Cluster[] calldata _clusters
    ) external;

    /// @notice Withdraw SSV tokens from this contract to the given address
    /// @dev Should be called by P2P only
    /// @param _to destination address
    /// @param _amount SSV token amount to be withdrawn
    function withdrawSSVTokens(
        address _to,
        uint256 _amount
    ) external;

    /// @notice Set a new fee recipient address for this contract (cluster owner)
    /// @dev Should be called by P2P only.
    /// Another FeeDistributor instance can become the fee recipient (e.g. if service percentages change).
    /// Client address itself can become the fee recipient (e.g. if service percentage becomes zero due to some promo).
    /// It's fine for P2P to determine the fee recipient since P2P is paying SSV tokens and EL rewards are a way to compansate for them.
    /// Other operators are compansated via SSV tokens paid by P2P.
    /// @param _feeRecipientAddress fee recipient address to set
    function setFeeRecipientAddress(
        address _feeRecipientAddress
    ) external;

    /// @notice Returns the client address
    /// @return address client address
    function getClient() external view returns (address);

    /// @notice Returns the factory address
    /// @return address factory address
    function getFactory() external view returns (address);

    /// @notice Returns the address of FeeDistributor instance accociated with this contract
    /// @return FeeDistributor instance address
    function getFeeDistributor() external view returns (address);
}
