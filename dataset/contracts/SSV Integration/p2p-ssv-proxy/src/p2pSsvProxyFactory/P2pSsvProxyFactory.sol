// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../@openzeppelin/contracts/proxy/Clones.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "../interfaces/IDepositContract.sol";
import "../interfaces/p2p/IFeeDistributor.sol";
import "../interfaces/p2p/IFeeDistributorFactory.sol";
import "../interfaces/ssv/ISSVViews.sol";

import "../assetRecovering/OwnableAssetRecoverer.sol";
import "../access/OwnableWithOperator.sol";
import "../p2pSsvProxy/P2pSsvProxy.sol";
import "../structs/P2pStructs.sol";
import "./IP2pSsvProxyFactory.sol";

/// @notice Passed address is not a valid FeeDistributorFactory
/// @param _passedAddress Passed address
error P2pSsvProxyFactory__NotFeeDistributorFactory(address _passedAddress);

/// @notice Passed address is not a valid FeeDistributor
/// @param _passedAddress Passed address
error P2pSsvProxyFactory__NotFeeDistributor(address _passedAddress);

/// @notice Passed address is not a valid P2pSsvProxy
/// @param _passedAddress Passed address
error P2pSsvProxyFactory__NotP2pSsvProxy(address _passedAddress);

/// @notice Caller in not an allowed SSV operator owner
/// @param _caller Caller address
error P2pSsvProxyFactory__NotAllowedSsvOperatorOwner(address _caller);

/// @notice Cannot add an already existing SSV operator owner address
/// @param _ssvOperatorOwner an already existing SSV operator owner address
error P2pSsvProxyFactory__SsvOperatorOwnerAlreadyExists(address _ssvOperatorOwner);

/// @notice Cannot remove a nonexisting SSV operator owner address
/// @param _ssvOperatorOwner a nonexisting SSV operator owner address
error P2pSsvProxyFactory__SsvOperatorOwnerDoesNotExist(address _ssvOperatorOwner);

/// @notice This SSV operator ID is not allowed. Check both the operator owner address and the ID for being allowed
/// @param _ssvOperatorOwner operator owner address
/// @param _ssvOperatorId operator ID
error P2pSsvProxyFactory__SsvOperatorNotAllowed(address _ssvOperatorOwner, uint64 _ssvOperatorId);

/// @notice All operators should belong to different owners
/// @param _ssvOperatorOwner operator owner who owns at least 2 of the passed operator IDs
/// @param _ssvOperatorId1 passed operator ID owned by the same owner
/// @param _ssvOperatorId2 passed operator ID owned by the same owner
error P2pSsvProxyFactory__DuplicateOperatorOwnersNotAllowed(
    address _ssvOperatorOwner,
    uint64 _ssvOperatorId1,
    uint64 _ssvOperatorId2
);

/// @notice All the SSV operator IDs must be unique
/// @param _ssvOperatorId duplicated operator ID
error P2pSsvProxyFactory__DuplicateIdsNotAllowed(uint64 _ssvOperatorId);

/// @notice ETH value passed with the transaction must be equal to the needed value
/// @param _needed needed ETH value
/// @param _paid actually sent ETH value
error P2pSsvProxyFactory__NotEnoughEtherPaidToCoverSsvFees(uint256 _needed, uint256 _paid);

/// @notice ETH value passed with the transaction must be equal to 32 times validator count
/// @param _actualEthValue actually sent ETH value
error P2pSsvProxyFactory__EthValueMustBe32TimesValidatorCount(uint256 _actualEthValue);

/// @dev We assume, SSV won't either drop 7539x or soar higher than 100 ETH.
/// If it does, this contract won't be operational and another contract will have to be deployed.
error P2pSsvProxyFactory__SsvPerEthExchangeRateDividedByWeiOutOfRange();

/// @notice SSV per ETH exchange rate has not been set. Cannot register validators without it.
error P2pSsvProxyFactory__SsvPerEthExchangeRateDividedByWeiNotSet();

/// @notice This SSV operator ID does not belong to the passed owner
/// @param _operatorId SSV operator ID
/// @param _passedOwner passed address for SSV operator owner
/// @param _actualOwner actual SSV operator owner address
error P2pSsvProxyFactory__SsvOperatorIdDoesNotBelongToOwner(
    uint64 _operatorId,
    address _passedOwner,
    address _actualOwner
);

/// @notice Should pass at least 1 selector
error P2pSsvProxyFactory__CannotSetZeroSelectors();

/// @notice Should pass at least 1 SSV operator owner
error P2pSsvProxyFactory__CannotSetZeroAllowedSsvOperatorOwners();

/// @notice Should pass at least 1 SSV operator owner
error P2pSsvProxyFactory__CannotRemoveZeroAllowedSsvOperatorOwners();

/// @notice There should equal number of pubkeys, signatures, and depositDataRoots
/// @param _ssvValidatorsLength validators list length
/// @param _signaturesLength signatures list length
/// @param _depositDataRootsLength depositDataRoots list length
error P2pSsvProxyFactory__DepositDataArraysShouldHaveTheSameLength(
    uint256 _ssvValidatorsLength,
    uint256 _signaturesLength,
    uint256 _depositDataRootsLength
);

/// @title Entry point for SSV validator registration
/// @dev Deploys P2pSsvProxy instances
contract P2pSsvProxyFactory is OwnableAssetRecoverer, OwnableWithOperator, ERC165, IP2pSsvProxyFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Beacon Deposit Contract
    IDepositContract private immutable i_depositContract;

    /// @notice FeeDistributorFactory
    IFeeDistributorFactory private immutable i_feeDistributorFactory;

    /// @notice SSV ERC-20 token
    IERC20 private immutable i_ssvToken;

    /// @notice SSVNetworkViews
    ISSVViews private immutable i_ssvViews;

    /// @notice Template set by P2P to be used for new FeeDistributor instances.
    /// @dev Can be changed by P2P at any time. It will only affect the new clusters.
    /// Existing clusters will keep their existing FeeDistributor instance.
    address private s_referenceFeeDistributor;

    /// @notice Template set by P2P to be used for new P2pSsvProxy instances.
    /// @dev Can be changed by P2P at any time. It will only affect the new clusters.
    /// Existing clusters will keep their existing P2pSsvProxy instance.
    P2pSsvProxy private s_referenceP2pSsvProxy;

    /// @notice a set of addresses of SSV operator owners (both P2P and partners).
    /// @dev Only P2P can add or remove addresses from the set.
    EnumerableSet.AddressSet private s_allowedSsvOperatorOwners;

    /// @notice a mapping of (operator owner address → SSV operator IDs list).
    /// @dev The list of allowed SSV operator IDs for each address is limited to 8 IDs.
    /// The operator owner can update only their list. P2P can update lists of any owners.
    mapping(address => uint64[MAX_ALLOWED_SSV_OPERATOR_IDS]) private s_allowedSsvOperatorIds;

    /// @notice a mapping of (client address → a list of addresses of the deployed client P2pSsvProxy instances).
    /// @dev Updated automatically during P2pSsvProxy instance deployment.
    mapping(address => address[]) private s_allClientP2pSsvProxies;

    /// @notice a list of all ever deployed client P2pSsvProxy instances.
    /// @dev Updated automatically during P2pSsvProxy instance deployment.
    address[] private s_allP2pSsvProxies;

    /// @notice a mapping to check if a certain selector (function signature) is allowed for clients to call on SSVNetwork via P2pSsvProxy.
    mapping(bytes4 => bool) private s_clientSelectors;

    /// @notice a mapping to check if a certain selector (function signature) is allowed for a P2P operator to call on SSVNetwork via P2pSsvProxy.
    mapping(bytes4 => bool) private s_operatorSelectors;

    /// @notice Exchange rate between SSV and ETH set by P2P.
    /// @dev (If 1 SSV = 0.007539 ETH, it should be 0.007539 * 10^18 = 7539000000000000).
    /// Only used during validator registration without ETH deposits to cover SSV token costs with client ETH.
    /// SSV tokens exchanged with this rate cannot be withdrawn by the client.
    /// P2P is willing to tolarate potential discrepancies with the market exchange rate for the sake of simplicity.
    /// The client agrees to this rate when calls `registerValidators` function.
    uint256 private s_ssvPerEthExchangeRateDividedByWei;

    /// @notice If the given _ssvOperatorOwner is not allowed, revert
    modifier onlyAllowedSsvOperatorOwner(address _ssvOperatorOwner) {
        bool isAllowed = s_allowedSsvOperatorOwners.contains(_ssvOperatorOwner);
        if (!isAllowed) {
            revert P2pSsvProxyFactory__NotAllowedSsvOperatorOwner(_ssvOperatorOwner);
        }
        _;
    }

    /// @notice If the msg.sender is not an allowed SSV operator owner, revert
    modifier onlySsvOperatorOwner() {
        bool isAllowed = s_allowedSsvOperatorOwners.contains(msg.sender);
        if (!isAllowed) {
            revert P2pSsvProxyFactory__NotAllowedSsvOperatorOwner(msg.sender);
        }
        _;
    }

    /// @notice Revert if either 1) one of the operator IDs is not allowed 2) at least 2 operator IDs belong to the same owner
    modifier onlyAllowedOperators(SsvOperator[] calldata _operators) {
        uint256 operatorCount = _operators.length;
        for (uint256 i = 0; i < operatorCount;) {
            address currentOperatorOwner = _operators[i].owner;

            uint64[MAX_ALLOWED_SSV_OPERATOR_IDS] memory allowedIds = s_allowedSsvOperatorIds[currentOperatorOwner];

            bool isAllowed;
            for (uint256 j = 0; j < MAX_ALLOWED_SSV_OPERATOR_IDS;) {
                if (allowedIds[j] == _operators[i].id) {
                    isAllowed = true;
                    break;
                }

                unchecked {++j;}
            }
            if (!isAllowed) {
                revert P2pSsvProxyFactory__SsvOperatorNotAllowed(currentOperatorOwner, _operators[i].id);
            }

            for (uint256 k = 0; k < operatorCount;) {
                if (i != k && currentOperatorOwner == _operators[k].owner) {
                    revert P2pSsvProxyFactory__DuplicateOperatorOwnersNotAllowed(
                        currentOperatorOwner,
                        _operators[i].id,
                        _operators[k].id
                    );
                }

                unchecked {++k;}
            }

            unchecked {++i;}
        }

        _;
    }

    /// @dev Set values that are constant, common for all clients, known at the initial deploy time.
    /// @param _feeDistributorFactory FeeDistributorFactory address
    /// @param _referenceFeeDistributor reference FeeDistributor address
    constructor(
        address _feeDistributorFactory,
        address _referenceFeeDistributor
    ) {
        if (!ERC165Checker.supportsInterface(_feeDistributorFactory, type(IFeeDistributorFactory).interfaceId)) {
            revert P2pSsvProxyFactory__NotFeeDistributorFactory(_feeDistributorFactory);
        }
        i_feeDistributorFactory = IFeeDistributorFactory(_feeDistributorFactory);

        if (!ERC165Checker.supportsInterface(_referenceFeeDistributor, type(IFeeDistributor).interfaceId)) {
            revert P2pSsvProxyFactory__NotFeeDistributor(_referenceFeeDistributor);
        }

        s_referenceFeeDistributor = _referenceFeeDistributor;
        emit P2pSsvProxyFactory__ReferenceFeeDistributorSet(_referenceFeeDistributor);

        i_depositContract = (block.chainid == 1)
            ? IDepositContract(0x00000000219ab540356cBB839Cbe05303d7705Fa)
            : IDepositContract(0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b);

        i_ssvToken = (block.chainid == 1)
            ? IERC20(0x9D65fF81a3c488d585bBfb0Bfe3c7707c7917f54)
            : IERC20(0x3a9f01091C446bdE031E39ea8354647AFef091E7);

        i_ssvViews = (block.chainid == 1)
            ? ISSVViews(0xafE830B6Ee262ba11cce5F32fDCd760FFE6a66e4)
            : ISSVViews(0xAE2C84c48272F5a1746150ef333D5E5B51F68763);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function setSsvPerEthExchangeRateDividedByWei(uint256 _ssvPerEthExchangeRateDividedByWei) external onlyOwner {
        if (_ssvPerEthExchangeRateDividedByWei < 10 ** 12 || _ssvPerEthExchangeRateDividedByWei > 10 ** 20) {
            revert P2pSsvProxyFactory__SsvPerEthExchangeRateDividedByWeiOutOfRange();
        }

        s_ssvPerEthExchangeRateDividedByWei = _ssvPerEthExchangeRateDividedByWei;
        emit P2pSsvProxyFactory__SsvPerEthExchangeRateDividedByWeiSet(_ssvPerEthExchangeRateDividedByWei);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function setReferenceP2pSsvProxy(address _referenceP2pSsvProxy) external onlyOwner {
        if (!ERC165Checker.supportsInterface(_referenceP2pSsvProxy, type(IP2pSsvProxy).interfaceId)) {
            revert P2pSsvProxyFactory__NotP2pSsvProxy(_referenceP2pSsvProxy);
        }

        s_referenceP2pSsvProxy = P2pSsvProxy(_referenceP2pSsvProxy);
        emit P2pSsvProxyFactory__ReferenceP2pSsvProxySet(_referenceP2pSsvProxy);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function setAllowedSelectorsForClient(bytes4[] calldata _selectors) external onlyOwner {
        uint256 count = _selectors.length;

        if (count == 0) {
            revert P2pSsvProxyFactory__CannotSetZeroSelectors();
        }

        for (uint256 i = 0; i < count;) {
            s_clientSelectors[_selectors[i]] = true;

            unchecked {
                ++i;
            }
        }

        emit P2pSsvProxyFactory__AllowedSelectorsForClientSet(_selectors);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function setAllowedSelectorsForOperator(bytes4[] calldata _selectors) external onlyOwner {
        uint256 count = _selectors.length;

        if (count == 0) {
            revert P2pSsvProxyFactory__CannotSetZeroSelectors();
        }

        for (uint256 i = 0; i < count;) {
            s_operatorSelectors[_selectors[i]] = true;

            unchecked {
                ++i;
            }
        }

        emit P2pSsvProxyFactory__AllowedSelectorsForOperatorSet(_selectors);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function setReferenceFeeDistributor(
        address _referenceFeeDistributor
    ) external onlyOperatorOrOwner {
        if (!ERC165Checker.supportsInterface(_referenceFeeDistributor, type(IFeeDistributor).interfaceId)) {
            revert P2pSsvProxyFactory__NotFeeDistributor(_referenceFeeDistributor);
        }

        s_referenceFeeDistributor = _referenceFeeDistributor;
        emit P2pSsvProxyFactory__ReferenceFeeDistributorSet(_referenceFeeDistributor);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function setAllowedSsvOperatorOwners(
        address[] calldata _allowedSsvOperatorOwners
    ) external onlyOperatorOrOwner {
        uint256 count = _allowedSsvOperatorOwners.length;

        if (count == 0) {
            revert P2pSsvProxyFactory__CannotSetZeroAllowedSsvOperatorOwners();
        }

        for (uint256 i = 0; i < count;) {
            address allowedSsvOperatorOwner = _allowedSsvOperatorOwners[i];

            if (!s_allowedSsvOperatorOwners.add(allowedSsvOperatorOwner)) {
                revert P2pSsvProxyFactory__SsvOperatorOwnerAlreadyExists(allowedSsvOperatorOwner);
            }

            unchecked {
                ++i;
            }
        }

        emit P2pSsvProxyFactory__AllowedSsvOperatorOwnersSet(_allowedSsvOperatorOwners);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function removeAllowedSsvOperatorOwners(
        address[] calldata _allowedSsvOperatorOwnersToRemove
    ) external onlyOperatorOrOwner {
        uint256 count = _allowedSsvOperatorOwnersToRemove.length;

        if (count == 0) {
            revert P2pSsvProxyFactory__CannotRemoveZeroAllowedSsvOperatorOwners();
        }

        for (uint256 i = 0; i < count;) {
            address allowedSsvOperatorOwnersToRemove = _allowedSsvOperatorOwnersToRemove[i];

            if (!s_allowedSsvOperatorOwners.remove(allowedSsvOperatorOwnersToRemove)) {
                revert P2pSsvProxyFactory__SsvOperatorOwnerDoesNotExist(allowedSsvOperatorOwnersToRemove);
            }

            unchecked {
                ++i;
            }
        }

        emit P2pSsvProxyFactory__AllowedSsvOperatorOwnersRemoved(_allowedSsvOperatorOwnersToRemove);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function setSsvOperatorIds(
        uint64[MAX_ALLOWED_SSV_OPERATOR_IDS] calldata _operatorIds
    ) external onlySsvOperatorOwner {
        _setSsvOperatorIds(_operatorIds, msg.sender);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function setSsvOperatorIds(
        uint64[MAX_ALLOWED_SSV_OPERATOR_IDS] calldata _operatorIds,
        address _ssvOperatorOwner
    ) external onlyOperatorOrOwner onlyAllowedSsvOperatorOwner(_ssvOperatorOwner) {
        _setSsvOperatorIds(_operatorIds, _ssvOperatorOwner);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function clearSsvOperatorIds() external onlySsvOperatorOwner {
        _clearSsvOperatorIds(msg.sender);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function clearSsvOperatorIds(
        address _ssvOperatorOwner
    ) external onlyOperatorOrOwner {
        _clearSsvOperatorIds(_ssvOperatorOwner);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function predictP2pSsvProxyAddress(
        address _feeDistributorInstance
    ) public view returns (address) {
        return Clones.predictDeterministicAddress(
            address(s_referenceP2pSsvProxy),
            bytes32(bytes20(_feeDistributorInstance))
        );
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function createP2pSsvProxy(
        address _feeDistributorInstance
    ) external onlyOperatorOrOwner returns(address p2pSsvProxyInstance) {
        p2pSsvProxyInstance = _createP2pSsvProxy(_feeDistributorInstance);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function depositEthAndRegisterValidators(
        DepositData calldata _depositData,
        address _withdrawalCredentialsAddress,

        SsvPayload calldata _ssvPayload,

        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) external payable returns (address p2pSsvProxy) {
        _makeBeaconDeposits(_depositData, _withdrawalCredentialsAddress, _ssvPayload.ssvValidators);

        p2pSsvProxy = _registerValidators(_ssvPayload, _clientConfig, _referrerConfig);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function registerValidators(
        SsvPayload calldata _ssvPayload,
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) external payable returns (address p2pSsvProxy) {
        _checkEthValue(_ssvPayload.tokenAmount);

        p2pSsvProxy = _registerValidators(_ssvPayload, _clientConfig, _referrerConfig);
    }

    /// @notice Register validators with SSV (up to 60, calldata size is the limit) without ETH deposits
    /// @dev Common logic for depositEthAndRegisterValidators and registerValidators functions
    /// @param _ssvPayload a stuct with data necessary for SSV registration (see `SsvPayload` struct for details)
    /// @param _clientConfig address and basis points (percent * 100) of the client (for FeeDistributor)
    /// @param _referrerConfig address and basis points (percent * 100) of the referrer (for FeeDistributor)
    /// @return p2pSsvProxy client P2pSsvProxy instance that became the SSV cluster owner
    function _registerValidators(
        SsvPayload calldata _ssvPayload,
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) private onlyAllowedOperators(_ssvPayload.ssvOperators) returns (address p2pSsvProxy) {
        address feeDistributorInstance = _createFeeDistributor(_clientConfig, _referrerConfig);
        p2pSsvProxy = _createP2pSsvProxy(feeDistributorInstance);

        i_ssvToken.transfer(address(p2pSsvProxy), _ssvPayload.tokenAmount);

        P2pSsvProxy(p2pSsvProxy).registerValidators(
            _ssvPayload,
            feeDistributorInstance
        );

        emit P2pSsvProxyFactory__RegistrationCompleted(p2pSsvProxy);
    }

    /// @notice Deploy P2pSsvProxy instance if not deployed before
    /// @param _feeDistributorInstance The address of FeeDistributor instance
    /// @return p2pSsvProxyInstance client P2pSsvProxy instance that has been deployed
    function _createP2pSsvProxy(
        address _feeDistributorInstance
    ) private returns(address p2pSsvProxyInstance) {
        p2pSsvProxyInstance = predictP2pSsvProxyAddress(_feeDistributorInstance);
        if (p2pSsvProxyInstance.code.length == 0) { // if p2pSsvProxyInstance doesn't exist, deploy it
            if (!ERC165Checker.supportsInterface(_feeDistributorInstance, type(IFeeDistributor).interfaceId)) {
                revert P2pSsvProxyFactory__NotFeeDistributor(_feeDistributorInstance);
            }

            // clone the reference implementation of P2pSsvProxy
            p2pSsvProxyInstance = Clones.cloneDeterministic(
                address(s_referenceP2pSsvProxy),
                bytes32(bytes20(_feeDistributorInstance))
            );

            // set the client address to the cloned P2pSsvProxy instance
            P2pSsvProxy(p2pSsvProxyInstance).initialize(_feeDistributorInstance);

            address client = IFeeDistributor(_feeDistributorInstance).client();

            // append new P2pSsvProxy address to all client P2pSsvProxies array
            s_allClientP2pSsvProxies[client].push(p2pSsvProxyInstance);

            // append new P2pSsvProxy address to all P2pSsvProxies array
            s_allP2pSsvProxies.push(p2pSsvProxyInstance);

            // emit event with the address of the newly created instance for the external listener
            emit P2pSsvProxyFactory__P2pSsvProxyCreated(
                p2pSsvProxyInstance,
                client,
                _feeDistributorInstance
            );
        }
    }

    /// @notice Deploy FeeDistributor instance if not deployed before
    /// @param _clientConfig address and basis points (percent * 100) of the client (for FeeDistributor)
    /// @param _referrerConfig address and basis points (percent * 100) of the referrer (for FeeDistributor)
    /// @return feeDistributorInstance client FeeDistributor instance that has been deployed
    function _createFeeDistributor(
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) private returns(address feeDistributorInstance) {
        address referenceFeeDistributor_ = s_referenceFeeDistributor;

        feeDistributorInstance = i_feeDistributorFactory.predictFeeDistributorAddress(
            referenceFeeDistributor_,
            _clientConfig,
            _referrerConfig
        );
        if (feeDistributorInstance.code.length == 0) {
            // if feeDistributorInstance doesn't exist, deploy it
            i_feeDistributorFactory.createFeeDistributor(
                referenceFeeDistributor_,
                _clientConfig,
                _referrerConfig
            );
        }
    }

    /// @notice Check ETH value for validator registrations without ETH deposits.
    /// @dev P2P cannot afford totally free validator registrations since they are paid with P2P's SSV tokens.
    /// It's OK for validator registrations with ETH deposits since we can be confident in the existense of EL rewards
    /// that will cover the SSV tokens cost in that case.
    /// If there are no ETH deposits, to prevent draining of SSV tokens from P2pSsvProxyFactory,
    /// the client pays for the used SSV tokens.
    /// The client will only need to pay once. Starting from the next month, P2P will be depositing SSV tokens to the clusters
    /// the same way as with ETH deposits.
    /// @param _tokenAmount amount of ERC-20 SSV tokens for validator registration
    function _checkEthValue(
        uint256 _tokenAmount
    ) private view {
        uint256 exchangeRate = s_ssvPerEthExchangeRateDividedByWei;
        if (exchangeRate == 0) {
            revert P2pSsvProxyFactory__SsvPerEthExchangeRateDividedByWeiNotSet();
        }

        uint256 ssvTokensValueInWei = (_tokenAmount * exchangeRate) / 10**18;
        if (msg.value != ssvTokensValueInWei) {
            revert P2pSsvProxyFactory__NotEnoughEtherPaidToCoverSsvFees(ssvTokensValueInWei, msg.value);
        }
    }

    /// @notice Set SSV operator IDs list for a SSV operator owner
    /// @param _operatorIds SSV operator IDs list
    /// @param _ssvOperatorOwner SSV operator owner
    function _setSsvOperatorIds(
        uint64[MAX_ALLOWED_SSV_OPERATOR_IDS] calldata _operatorIds,
        address _ssvOperatorOwner
    ) private {
        for (uint i = 0; i < _operatorIds.length;) {
            uint64 id = _operatorIds[i];

            for (uint j = i + 1; j < _operatorIds.length;) {
                if (id == _operatorIds[j] && id != 0) {
                    revert P2pSsvProxyFactory__DuplicateIdsNotAllowed(id);
                }
                unchecked {
                    ++j;
                }
            }

            if (id != 0) {
                (address actualOwner,,,,,) = i_ssvViews.getOperatorById(id);
                if (actualOwner != _ssvOperatorOwner) {
                    revert P2pSsvProxyFactory__SsvOperatorIdDoesNotBelongToOwner(id, _ssvOperatorOwner, actualOwner);
                }
            }

            unchecked {
                ++i;
            }
        }

        s_allowedSsvOperatorIds[_ssvOperatorOwner] = _operatorIds;
        emit P2pSsvProxyFactory__SsvOperatorIdsSet(_ssvOperatorOwner, _operatorIds);
    }

    /// @notice Clear SSV operator IDs list for a SSV operator owner
    /// @param _ssvOperatorOwner SSV operator owner
    function _clearSsvOperatorIds(
        address _ssvOperatorOwner
    ) private {
        delete s_allowedSsvOperatorIds[_ssvOperatorOwner];
        emit P2pSsvProxyFactory__SsvOperatorIdsCleared(_ssvOperatorOwner);
    }

    /// @notice Make ETH2 (Beacon) deposits via the official Beacon Deposit Contract
    /// @param _depositData signatures and depositDataRoots from Beacon deposit data
    /// @param _withdrawalCredentialsAddress address for 0x01 withdrawal credentials from Beacon deposit data (1 for the batch)
    /// @param _ssvValidators list of pubkeys and SSV sharesData
    function _makeBeaconDeposits(
        DepositData calldata _depositData,
        address _withdrawalCredentialsAddress,
        SsvValidator[] calldata _ssvValidators
    ) private {
        uint256 validatorCount = _ssvValidators.length;

        if (msg.value != COLLATERAL * validatorCount) {
            revert P2pSsvProxyFactory__EthValueMustBe32TimesValidatorCount(msg.value);
        }

        if (_depositData.signatures.length != validatorCount || _depositData.depositDataRoots.length != validatorCount) {
            revert P2pSsvProxyFactory__DepositDataArraysShouldHaveTheSameLength(
                validatorCount,
                _depositData.signatures.length,
                _depositData.depositDataRoots.length
            );
        }

        for (uint256 i = 0; i < validatorCount;) {
            // ETH deposit
            bytes memory withdrawalCredentials = abi.encodePacked(
                hex'010000000000000000000000',
                _withdrawalCredentialsAddress
            );
            i_depositContract.deposit{value: COLLATERAL}(
                _ssvValidators[i].pubkey,
                withdrawalCredentials,
                _depositData.signatures[i],
                _depositData.depositDataRoots[i]
            );

            unchecked {++i;}
        }
    }

    /// @inheritdoc IOwnable
    function owner() public view override(Ownable, OwnableBase, IOwnable) returns (address) {
        return super.owner();
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function getFeeDistributorFactory() external view returns (address) {
        return address(i_feeDistributorFactory);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function getAllClientP2pSsvProxies(
        address _client
    ) external view returns (address[] memory) {
        return s_allClientP2pSsvProxies[_client];
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function getAllP2pSsvProxies() external view returns (address[] memory) {
        return s_allP2pSsvProxies;
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function isClientSelectorAllowed(bytes4 _selector) external view returns (bool) {
        return s_clientSelectors[_selector];
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function isOperatorSelectorAllowed(bytes4 _selector) external view returns (bool) {
        return s_operatorSelectors[_selector];
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function getAllowedSsvOperatorIds(address _ssvOperatorOwner) external view returns (uint64[MAX_ALLOWED_SSV_OPERATOR_IDS] memory) {
        return s_allowedSsvOperatorIds[_ssvOperatorOwner];
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function getAllowedSsvOperatorOwners() external view returns (address[] memory) {
        return s_allowedSsvOperatorOwners.values();
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function getReferenceFeeDistributor() external view returns (address) {
        return s_referenceFeeDistributor;
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function getReferenceP2pSsvProxy() external view returns (address) {
        return address(s_referenceP2pSsvProxy);
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function getSsvPerEthExchangeRateDividedByWei() external view returns (uint256) {
        return s_ssvPerEthExchangeRateDividedByWei;
    }

    /// @inheritdoc IP2pSsvProxyFactory
    function getNeededAmountOfEtherToCoverSsvFees(uint256 _tokenAmount) external view returns (uint256) {
        return (_tokenAmount * s_ssvPerEthExchangeRateDividedByWei) / 10**18;
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IP2pSsvProxyFactory).interfaceId || super.supportsInterface(interfaceId);
    }
}
