// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { LibMappings } from "../Libraries/LibMappings.sol";
import { IRubic } from "../Interfaces/IRubic.sol";
import { LibAsset, IERC20 } from "../Libraries/LibAsset.sol";
import { LibFees } from "../Libraries/LibFees.sol";
import { LibUtil } from "../Libraries/LibUtil.sol";
import { LibDiamond } from "../Libraries/LibDiamond.sol";
import { ReentrancyGuard } from "../Helpers/ReentrancyGuard.sol";
import { SwapperV2, LibSwap } from "../Helpers/SwapperV2.sol";
import { UnAuthorized, LengthMissmatch, InvalidContract } from "../Errors/GenericErrors.sol";
import { Validatable } from "../Helpers/Validatable.sol";

/// @title Generic Cross-Chain Facet
/// @notice Provides functionality for bridging through arbitrary cross-chain provider
contract GenericCrossChainFacet is
    IRubic,
    ReentrancyGuard,
    SwapperV2,
    Validatable
{
    /// Events ///

    event ProviderFunctionAmountOffsetUpdated(
        address[] _routers,
        bytes4[] _selectors,
        uint256[] _offsets
    );

    /// Types ///

    struct GenericCrossChainData {
        address router;
        bytes callData;
    }

    /// Modifiers ///

    modifier validateGenericData(GenericCrossChainData calldata _genericData) {
        if (!LibAsset.isContract(_genericData.router))
            revert InvalidContract();
        if (_genericData.router == address(LibAsset.getERC20proxy()))
            revert UnAuthorized();
        _;
    }

    /// External Methods ///

    /// @notice Updates the amount offset of the specific function of the specific provider's router
    /// @param _routers Array of provider's routers
    /// @param _selectors Array of function selectors
    /// @param _offsets Array of amount offsets
    function updateProviderFunctionAmountOffset(
        address[] calldata _routers,
        bytes4[] calldata _selectors,
        uint256[] calldata _offsets
    ) external {
        LibDiamond.enforceIsContractOwner();

        LibMappings.GenericCrossChainMappings storage sm = LibMappings
            .getGenericCrossChainMappings();

        if (
            _routers.length != _selectors.length ||
            _selectors.length != _offsets.length
        ) {
            revert LengthMissmatch();
        }

        for (uint64 i; i < _routers.length; ) {
            sm.providerFunctionAmountOffset[_routers[i]][
                _selectors[i]
            ] = _offsets[i];
            unchecked {
                ++i;
            }
        }

        emit ProviderFunctionAmountOffsetUpdated(
            _routers,
            _selectors,
            _offsets
        );
    }

    /// @notice Bridges tokens via arbitrary cross-chain provider
    /// @param _bridgeData the core information needed for bridging
    /// @param _genericData data specific to GenericCrossChainFacet
    function startBridgeTokensViaGenericCrossChain(
        IRubic.BridgeData memory _bridgeData,
        GenericCrossChainData calldata _genericData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(msg.sender))
        validateBridgeData(_bridgeData)
        validateGenericData(_genericData)
        doesNotContainSourceSwaps(_bridgeData)
        doesNotContainDestinationCalls(_bridgeData)
    {
        _bridgeData.minAmount = LibAsset.depositAssetAndAccrueFees(
            _bridgeData.sendingAssetId,
            _bridgeData.minAmount,
            0,
            _bridgeData.integrator
        );

        _startBridge(
            _bridgeData,
            _patchGenericCrossChainData(_genericData, _bridgeData.minAmount)
        );
    }

    /// @notice Bridges tokens via arbitrary cross-chain provider with swaps before bridging
    /// @param _bridgeData the core information needed for bridging
    /// @param _swapData an array of swap related data for performing swaps before bridging
    /// @param _genericData data specific to GenericCrossChainFacet
    function swapAndStartBridgeTokensViaGenericCrossChain(
        IRubic.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        GenericCrossChainData calldata _genericData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(msg.sender))
        containsSourceSwaps(_bridgeData)
        validateBridgeData(_bridgeData)
        validateGenericData(_genericData)
    {
        _bridgeData.minAmount = _depositAndSwap(
            _bridgeData.transactionId,
            _bridgeData.minAmount,
            _swapData,
            _bridgeData.integrator,
            payable(msg.sender)
        );

        _startBridge(
            _bridgeData,
            _patchGenericCrossChainData(_genericData, _bridgeData.minAmount)
        );
    }

    /// View Methods ///

    /// @notice Fetches the amount offset of the specific function of the specific provider's router
    /// @param _router Address of provider's router
    /// @param _selector Selector of the function
    /// @return Amount offset
    function getProviderFunctionAmountOffset(
        address _router,
        bytes4 _selector
    ) external view returns (uint256) {
        LibMappings.GenericCrossChainMappings storage sm = LibMappings
            .getGenericCrossChainMappings();

        return sm.providerFunctionAmountOffset[_router][_selector];
    }

    /// Internal Methods ///

    /// @dev Contains the business logic for the bridge via arbitrary cross-chain provider
    /// @param _bridgeData the core information needed for bridging
    /// @param _genericData data specific to GenericCrossChainFacet
    function _startBridge(
        IRubic.BridgeData memory _bridgeData,
        GenericCrossChainData memory _genericData
    ) internal {
        bool isNative = LibAsset.isNativeAsset(_bridgeData.sendingAssetId);
        uint256 nativeAssetAmount;

        if (isNative) {
            nativeAssetAmount = _bridgeData.minAmount;
        } else {
            LibAsset.maxApproveERC20(
                IERC20(_bridgeData.sendingAssetId),
                _genericData.router,
                _bridgeData.minAmount
            );
        }

        (bool success, bytes memory res) = _genericData.router.call{
            value: nativeAssetAmount
        }(_genericData.callData);
        if (!success) {
            string memory reason = LibUtil.getRevertMsg(res);
            revert(reason);
        }

        emit RubicTransferStarted(_bridgeData);
    }

    function _patchGenericCrossChainData(
        GenericCrossChainData calldata _genericData,
        uint256 amount
    ) private view returns (GenericCrossChainData memory) {
        LibMappings.GenericCrossChainMappings storage sm = LibMappings
            .getGenericCrossChainMappings();
        uint256 offset = sm.providerFunctionAmountOffset[_genericData.router][
            bytes4(_genericData.callData[:4])
        ];

        if (offset > 0) {
            return
                GenericCrossChainData(
                    _genericData.router,
                    bytes.concat(
                        _genericData.callData[:offset],
                        abi.encode(amount),
                        _genericData.callData[offset + 32:]
                    )
                );
        } else {
            return
                GenericCrossChainData(
                    _genericData.router,
                    _genericData.callData
                );
        }
    }
}
