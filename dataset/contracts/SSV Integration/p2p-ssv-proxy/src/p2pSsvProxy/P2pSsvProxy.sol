// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "../constants/P2pConstants.sol";
import "../interfaces/ssv/ISSVNetwork.sol";
import "../interfaces/IDepositContract.sol";
import "../interfaces/p2p/IFeeDistributorFactory.sol";
import "../access/OwnableWithOperator.sol";
import "../assetRecovering/OwnableAssetRecoverer.sol";
import "../structs/P2pStructs.sol";
import "../p2pSsvProxyFactory/IP2pSsvProxyFactory.sol";
import "./IP2pSsvProxy.sol";


/// @notice _referenceFeeDistributor should implement IFeeDistributor interface
/// @param _passedAddress passed address for _referenceFeeDistributor
error P2pSsvProxy__NotFeeDistributor(address _passedAddress);

/// @notice Should be a P2pSsvProxyFactory contract
/// @param _passedAddress passed address that does not support IP2pSsvProxyFactory interface
error P2pSsvProxy__NotP2pSsvProxyFactory(address _passedAddress);

/// @notice Throws if called by any account other than the client.
/// @param _caller address of the caller
/// @param _client address of the client
error P2pSsvProxy__CallerNotClient(address _caller, address _client);

/// @notice The caller was neither operator nor owner
/// @param _caller address of the caller
/// @param _operator address of the operator
/// @param _owner address of the owner
error P2pSsvProxy__CallerNeitherOperatorNorOwner(address _caller, address _operator, address _owner);

/// @notice The caller was neither operator nor owner nor client
/// @param _caller address of the caller
error P2pSsvProxy__CallerNeitherOperatorNorOwnerNorClient(address _caller);

/// @notice Only factory can call `initialize`.
/// @param _msgSender sender address.
/// @param _actualFactory the actual factory address that can call `initialize`.
error P2pSsvProxy__NotP2pSsvProxyFactoryCalled(address _msgSender, IP2pSsvProxyFactory _actualFactory);

/// @notice _pubkeys and _operatorIds arrays should have the same lengths
error P2pSsvProxy__AmountOfParametersError();

/// @notice Selector is not allowed for the caller.
/// @param _caller caller address
/// @param _selector function selector to be called on SSVNetwork
error P2pSsvProxy__SelectorNotAllowed(address _caller, bytes4 _selector);

/// @title Proxy for SSVNetwork calls.
/// @dev Each instance of P2pSsvProxy corresponds to 1 FeeDistributor instance.
/// Thus, client to P2pSsvProxy instances is a 1-to-many relation.
/// SSV tokens are managed by P2P.
/// Clients cover the costs of SSV tokens by EL rewards via FeeDistributor instance.
contract P2pSsvProxy is OwnableAssetRecoverer, ERC165, IP2pSsvProxy {

    /// @notice P2pSsvProxyFactory address
    IP2pSsvProxyFactory private immutable i_p2pSsvProxyFactory;

    /// @notice SSVNetwork address
    ISSVNetwork private immutable i_ssvNetwork;

    /// @notice SSV token (ERC-20) address
    IERC20 private immutable i_ssvToken;

    /// @notice FeeDistributor instance address
    IFeeDistributor private s_feeDistributor;

    /// @notice If caller is not client, revert
    modifier onlyClient() {
        address clientAddress = getClient();

        if (clientAddress != msg.sender) {
            revert P2pSsvProxy__CallerNotClient(msg.sender, clientAddress);
        }
        _;
    }

    /// @notice If caller is neither operator nor owner, revert
    modifier onlyOperatorOrOwner() {
        address currentOwner = owner();
        address currentOperator = operator();

        if (currentOperator != msg.sender && currentOwner != msg.sender) {
            revert P2pSsvProxy__CallerNeitherOperatorNorOwner(msg.sender, currentOperator, currentOwner);
        }

        _;
    }

    /// @notice If caller is neither operator nor owner nor client, revert
    modifier onlyOperatorOrOwnerOrClient() {
        address operator_ = operator();
        address owner_ = owner();
        address client_ = getClient();

        if (operator_ != msg.sender && owner_ != msg.sender && client_ != msg.sender) {
            revert P2pSsvProxy__CallerNeitherOperatorNorOwnerNorClient(msg.sender);
        }
        _;
    }

    /// @notice If caller is not factory, revert
    modifier onlyP2pSsvProxyFactory() {
        if (msg.sender != address(i_p2pSsvProxyFactory)) {
            revert P2pSsvProxy__NotP2pSsvProxyFactoryCalled(msg.sender, i_p2pSsvProxyFactory);
        }
        _;
    }

    /// @dev Set values that are constant, common for all clients, known at the initial deploy time.
    /// @param _p2pSsvProxyFactory address of P2pSsvProxyFactory
    constructor(
        address _p2pSsvProxyFactory
    ) {
        if (!ERC165Checker.supportsInterface(_p2pSsvProxyFactory, type(IP2pSsvProxyFactory).interfaceId)) {
            revert P2pSsvProxy__NotP2pSsvProxyFactory(_p2pSsvProxyFactory);
        }
        i_p2pSsvProxyFactory = IP2pSsvProxyFactory(_p2pSsvProxyFactory);

        i_ssvNetwork = (block.chainid == 1)
            ? ISSVNetwork(0xDD9BC35aE942eF0cFa76930954a156B3fF30a4E1)
            : ISSVNetwork(0xC3CD9A0aE89Fff83b71b58b6512D43F8a41f363D);

        i_ssvToken = (block.chainid == 1)
            ? IERC20(0x9D65fF81a3c488d585bBfb0Bfe3c7707c7917f54)
            : IERC20(0x3a9f01091C446bdE031E39ea8354647AFef091E7);
    }

    /// @inheritdoc IP2pSsvProxy
    function initialize(
        address _feeDistributor
    ) external onlyP2pSsvProxyFactory {
        s_feeDistributor = IFeeDistributor(_feeDistributor);

        i_ssvToken.approve(address(i_ssvNetwork), type(uint256).max);

        emit P2pSsvProxy__Initialized(_feeDistributor);
    }

    /// @dev Access any SSVNetwork function as cluster owner (this P2pSsvProxy instance)
    /// Each selector access is managed by P2pSsvProxyFactory roles (owner, operator, client)
    fallback() external {
        address caller = msg.sender;
        bytes4 selector = msg.sig;

        bool isAllowed = msg.sender == owner() ||
            (msg.sender == operator() && i_p2pSsvProxyFactory.isOperatorSelectorAllowed(selector)) ||
            (msg.sender == getClient() && i_p2pSsvProxyFactory.isClientSelectorAllowed(selector));

        if (!isAllowed) {
            revert P2pSsvProxy__SelectorNotAllowed(caller, selector);
        }

        (bool success, bytes memory data) = address(i_ssvNetwork).call(msg.data);
        if (success) {
            emit P2pSsvProxy__SuccessfullyCalledViaFallback(caller, selector);

            assembly {
                return(add(data, 0x20), mload(data))
            }
        } else {
            emit P2pSsvProxy__CallingViaFallbackFailed(caller, selector);

            // Decode the reason from the error data returned from the call and revert with it.
            revert(string(data));
        }
    }

    /// @inheritdoc IP2pSsvProxy
    function registerValidators(
        SsvPayload calldata _ssvPayload,
        address _feeDistributorInstance
    ) external onlyP2pSsvProxyFactory {
        (
            uint64[] memory operatorIds,
            uint64 clusterIndex
        ) = _getOperatorIdsAndClusterIndex(_ssvPayload.ssvOperators);

        uint256 ssvSlot0 = uint256(_ssvPayload.ssvSlot0);

        // see https://github.com/bloxapp/ssv-network/blob/1e61c35736578d4b03bacbff9da2128ad12a5620/contracts/libraries/ProtocolLib.sol#L15
        uint64 currentNetworkFeeIndex = uint64(ssvSlot0 >> 192) + uint64(block.number - uint32(ssvSlot0)) * uint64(ssvSlot0 >> 128);

        uint256 balance = _getBalance(_ssvPayload.cluster, clusterIndex, currentNetworkFeeIndex, _ssvPayload.tokenAmount);

        i_ssvNetwork.registerValidator(
            _ssvPayload.ssvValidators[0].pubkey,
            operatorIds,
            _ssvPayload.ssvValidators[0].sharesData,
            _ssvPayload.tokenAmount,
            _ssvPayload.cluster
        );

        for (uint256 i = 1; i < _ssvPayload.ssvValidators.length;) {
            _registerValidator(
                i,
                operatorIds,
                _ssvPayload.cluster,
                clusterIndex,
                _ssvPayload.ssvValidators[i].pubkey,
                _ssvPayload.ssvValidators[i].sharesData,
                currentNetworkFeeIndex,
                balance
            );

            unchecked {++i;}
        }

        i_ssvNetwork.setFeeRecipientAddress(_feeDistributorInstance);
    }

    /// @inheritdoc IP2pSsvProxy
    function removeValidators(
        bytes[] calldata _pubkeys,
        uint64[] calldata _operatorIds,
        ISSVNetwork.Cluster[] calldata _clusters
    ) external onlyOperatorOrOwnerOrClient {
        uint256 validatorCount = _pubkeys.length;

        if (!(
            _clusters.length == validatorCount
        )) {
            revert P2pSsvProxy__AmountOfParametersError();
        }

        for (uint256 i = 0; i < validatorCount;) {
            i_ssvNetwork.removeValidator(_pubkeys[i], _operatorIds, _clusters[i]);

            unchecked {++i;}
        }
    }

    /// @inheritdoc IP2pSsvProxy
    function liquidate(
        uint64[] calldata _operatorIds,
        ISSVNetwork.Cluster[] calldata _clusters
    ) external onlyOperatorOrOwner {
        address clusterOwner = address(this);
        uint256 validatorCount = _clusters.length;

        for (uint256 i = 0; i < validatorCount;) {
            i_ssvNetwork.liquidate(clusterOwner, _operatorIds, _clusters[i]);

            unchecked {++i;}
        }
    }

    /// @inheritdoc IP2pSsvProxy
    function reactivate(
        uint256 _tokenAmount,
        uint64[] calldata _operatorIds,
        ISSVNetwork.Cluster[] calldata _clusters
    ) external onlyOperatorOrOwner {
        uint256 tokenPerValidator = _tokenAmount / _clusters.length;
        uint256 validatorCount = _clusters.length;

        for (uint256 i = 0; i < validatorCount;) {
            i_ssvNetwork.reactivate(_operatorIds, tokenPerValidator, _clusters[i]);

            unchecked {++i;}
        }
    }

    /// @inheritdoc IP2pSsvProxy
    function depositToSSV(
        uint256 _tokenAmount,
        uint64[] calldata _operatorIds,
        ISSVNetwork.Cluster[] calldata _clusters
    ) external {
        address clusterOwner = address(this);
        uint256 validatorCount = _clusters.length;
        uint256 tokenPerValidator = _tokenAmount / validatorCount;

        for (uint256 i = 0; i < validatorCount;) {
            i_ssvNetwork.deposit(clusterOwner, _operatorIds, tokenPerValidator, _clusters[i]);

            unchecked {++i;}
        }
    }

    /// @inheritdoc IP2pSsvProxy
    function withdrawFromSSV(
        uint256 _tokenAmount,
        uint64[] calldata _operatorIds,
        ISSVNetwork.Cluster[] calldata _clusters
    ) external onlyOperatorOrOwner {
        uint256 tokenPerValidator = _tokenAmount / _clusters.length;
        uint256 validatorCount = _clusters.length;

        for (uint256 i = 0; i < validatorCount;) {
            i_ssvNetwork.withdraw(_operatorIds, tokenPerValidator, _clusters[i]);

            unchecked {++i;}
        }
    }

    /// @inheritdoc IP2pSsvProxy
    function withdrawSSVTokens(
        address _to,
        uint256 _amount
    ) external onlyOwner {
        i_ssvToken.transfer(_to, _amount);
    }

    /// @inheritdoc IP2pSsvProxy
    function setFeeRecipientAddress(
        address _feeRecipientAddress
    ) external onlyOperatorOrOwner {
        i_ssvNetwork.setFeeRecipientAddress(_feeRecipientAddress);
    }

    /// @notice Extract operatorIds and clusterIndex out of SsvOperator list
    /// @param _ssvOperators list of SSV operator data
    /// @return operatorIds list of SSV operator IDs, clusterIndex updated cluster index
    function _getOperatorIdsAndClusterIndex(
        SsvOperator[] calldata _ssvOperators
    ) private view returns(
        uint64[] memory operatorIds,
        uint64 clusterIndex
    ) {
        // clusterIndex updating logic reflects
        // https://github.com/bloxapp/ssv-network/blob/fe3b9b178344dd723b19792d01ab5010dfd2dcf9/contracts/modules/SSVClusters.sol#L77

        clusterIndex = 0;
        uint256 operatorCount = _ssvOperators.length;
        operatorIds = new uint64[](operatorCount);
        for (uint256 i = 0; i < operatorCount;) {
            operatorIds[i] = _ssvOperators[i].id;

            uint256 snapshot = uint256(_ssvOperators[i].snapshot);

            // see https://github.com/bloxapp/ssv-network/blob/6ae5903a5c99c8d75b59fc0d35574d87f82e5861/contracts/libraries/OperatorLib.sol#L13
            clusterIndex += uint64(snapshot >> 32) + (uint32(block.number) - uint32(snapshot)) * uint64(_ssvOperators[i].fee / 10_000_000);

            unchecked {++i;}
        }
    }

    /// @notice Calculate the balance for the subsequent cluster values in a batch
    /// @param _cluster cluster value before the 1st validator registration
    /// @param _newIndex clusterIndex value after the 1st validator registration
    /// @param _currentNetworkFeeIndex currentNetworkFeeIndex from ssvSlot0
    /// @param _tokenAmount amount of SSV tokens deposited along with the 1st validator registration
    /// @return balance updated balance after the 1st validator registration
    function _getBalance(
        ISSVNetwork.Cluster calldata _cluster,
        uint64 _newIndex,
        uint64 _currentNetworkFeeIndex,
        uint256 _tokenAmount
    ) private pure returns(uint256 balance) {
        uint256 balanceBefore = _cluster.balance + _tokenAmount;

        // see https://github.com/bloxapp/ssv-network/blob/1e61c35736578d4b03bacbff9da2128ad12a5620/contracts/libraries/ClusterLib.sol#L16
        uint64 networkFee = uint64(_currentNetworkFeeIndex - _cluster.networkFeeIndex) * _cluster.validatorCount;
        uint64 usage = (_newIndex - _cluster.index) * _cluster.validatorCount + networkFee;
        uint256 expandedUsage = usage * 10_000_000;
        balance = expandedUsage > balanceBefore? 0 : balanceBefore - expandedUsage;
    }

    /// @notice Register subsequent validators after the 1st one
    /// @param i validator index in calldata
    /// @param _operatorIds list of SSV operator IDs
    /// @param _cluster cluster value before the 1st registration
    /// @param _clusterIndex calculated clusterIndex after the 1st registration
    /// @param _pubkey validator pubkey
    /// @param _sharesData validator SSV sharesData
    /// @param _currentNetworkFeeIndex currentNetworkFeeIndex from ssvSlot0
    /// @param _balance cluster balance after the 1st validator registration
    function _registerValidator(
        uint256 i,
        uint64[] memory _operatorIds,
        ISSVNetwork.Cluster calldata _cluster,
        uint64 _clusterIndex,
        bytes calldata _pubkey,
        bytes calldata _sharesData,
        uint64 _currentNetworkFeeIndex,
        uint256 _balance
    ) private {
        ISSVClusters.Cluster memory cluster = ISSVClusters.Cluster({
            validatorCount: uint32(_cluster.validatorCount + i),
            networkFeeIndex: _currentNetworkFeeIndex,
            index: _clusterIndex,
            active: true,
            balance: _balance
        });

        i_ssvNetwork.registerValidator(
            _pubkey,
            _operatorIds,
            _sharesData,
            0,
            cluster
        );
    }

    /// @inheritdoc IP2pSsvProxy
    function getClient() public view returns (address) {
        return s_feeDistributor.client();
    }

    /// @inheritdoc IP2pSsvProxy
    function getFactory() external view returns (address) {
        return address(i_p2pSsvProxyFactory);
    }

    /// @inheritdoc IOwnable
    function owner() public view override(OwnableBase, IOwnable) returns (address) {
        return i_p2pSsvProxyFactory.owner();
    }

    /// @inheritdoc IOwnableWithOperator
    function operator() public view returns (address) {
        return i_p2pSsvProxyFactory.operator();
    }

    /// @inheritdoc IP2pSsvProxy
    function getFeeDistributor() external view returns (address) {
        return address(s_feeDistributor);
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IP2pSsvProxy).interfaceId || super.supportsInterface(interfaceId);
    }
}
