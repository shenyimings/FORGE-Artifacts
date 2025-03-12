// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IRubic } from "../Interfaces/IRubic.sol";
import { LibAsset, IERC20 } from "../Libraries/LibAsset.sol";
import { IXSwapper } from "../Interfaces/IXSwapper.sol";
import { LibFees } from "../Libraries/LibFees.sol";
import { ReentrancyGuard } from "../Helpers/ReentrancyGuard.sol";
import { SwapperV2, LibSwap } from "../Helpers/SwapperV2.sol";
import { Validatable } from "../Helpers/Validatable.sol";

/// @title XY Facet
/// @notice Provides functionality for bridging through XY Protocol
contract XYFacet is IRubic, ReentrancyGuard, SwapperV2, Validatable {
    address private constant xyNativeAddress =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice The contract address of the XY router on the source chain
    IXSwapper private immutable router;

    /// Types ///

    struct XYData {
        address toChainToken;
        uint256 expectedToChainTokenAmount;
        uint32 slippage;
    }

    /// Constructor ///

    /// @notice Initialize the contract.
    /// @param _router The contract address of the XY Swapper on the source chain.
    constructor(IXSwapper _router) {
        router = _router;
    }

    /// External Methods ///

    /// @notice Bridges tokens via XY
    /// @param _bridgeData the core information needed for bridging
    /// @param _xyData data specific to XY
    function startBridgeTokensViaXY(
        IRubic.BridgeData memory _bridgeData,
        XYData calldata _xyData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(msg.sender))
        validateBridgeData(_bridgeData)
        doesNotContainSourceSwaps(_bridgeData)
        doesNotContainDestinationCalls(_bridgeData)
    {
        _bridgeData.minAmount = LibAsset.depositAssetAndAccrueFees(
            _bridgeData.sendingAssetId,
            _bridgeData.minAmount,
            0,
            _bridgeData.integrator
        );

        _startBridge(_bridgeData, _xyData);
    }

    /// @notice Performs a swap before bridging via XY
    /// @param _bridgeData the core information needed for bridging
    /// @param _swapData an array of swap related data for performing swaps before bridging
    /// @param _xyData data specific to XY
    function swapAndStartBridgeTokensViaXY(
        IRubic.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        XYData calldata _xyData
    )
        external
        payable
        nonReentrant
        refundExcessNative(payable(msg.sender))
        containsSourceSwaps(_bridgeData)
        validateBridgeData(_bridgeData)
    {
        _bridgeData.minAmount = _depositAndSwap(
            _bridgeData.transactionId,
            _bridgeData.minAmount,
            _swapData,
            _bridgeData.integrator,
            payable(msg.sender)
        );

        _startBridge(_bridgeData, _xyData);
    }

    /// Internal Methods ///

    /// @dev Contains the business logic for the bridge via XY
    /// @param _bridgeData the core information needed for bridging
    /// @param _xyData data specific to XY
    function _startBridge(
        IRubic.BridgeData memory _bridgeData,
        XYData calldata _xyData
    ) internal {
        bool isNative = LibAsset.isNativeAsset(_bridgeData.sendingAssetId);
        uint256 nativeAssetAmount;

        if (isNative) {
            nativeAssetAmount = _bridgeData.minAmount;
            _bridgeData.sendingAssetId = xyNativeAddress;
        } else {
            LibAsset.maxApproveERC20(
                IERC20(_bridgeData.sendingAssetId),
                address(router),
                _bridgeData.minAmount
            );
        }

        router.swap{ value: nativeAssetAmount }(
            address(0),
            IXSwapper.SwapDescription(
                _bridgeData.sendingAssetId,
                _bridgeData.sendingAssetId,
                _bridgeData.receiver,
                _bridgeData.minAmount,
                _bridgeData.minAmount
            ),
            "",
            IXSwapper.ToChainDescription(
                uint32(_bridgeData.destinationChainId),
                _xyData.toChainToken,
                _xyData.expectedToChainTokenAmount,
                _xyData.slippage
            )
        );

        if (isNative) {
            _bridgeData.sendingAssetId = address(0);
        }

        emit RubicTransferStarted(_bridgeData);
    }
}
