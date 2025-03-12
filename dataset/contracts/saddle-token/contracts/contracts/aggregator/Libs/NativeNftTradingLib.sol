// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "../../marketplace/lib/LibSignature.sol";

interface INativeNftTrading {
    function buyNow(
        LibSignature.Order calldata sellOrder,
        address recipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function executeSwap(
        LibSignature.Order calldata sellOrder,
        LibSignature.Order calldata buyOrder,
        uint8[2] calldata v,
        bytes32[2] calldata r,
        bytes32[2] calldata s
    ) external;
}

error InvalidChain();

struct ExecuteSwapParams {
    LibSignature.Order sellOrder;
    LibSignature.Order buyOrder;
    uint8[2] v;
    bytes32[2] r;
    bytes32[2] s;
}

struct BuyNowParams {
    LibSignature.Order sellOrder;
    address recipient;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

library NativeNftTradingLib {
    function _buySwap(BuyNowParams calldata params, uint256 _msgValue, bool _revertIfTrxFails) external {
        bytes memory _data = abi.encodeWithSelector(
            INativeNftTrading.buyNow.selector,
            params.sellOrder,
            params.recipient,
            params.v,
            params.r,
            params.s
        );

        address NftNativeTrading;
        if (block.chainid == 1) {
            NftNativeTrading = 0x1fD9Bc58C7FfdB18D19a8A8d791B6ae9fa2BD097;
        } else if (block.chainid == 5 || block.chainid == 31337) {
            NftNativeTrading = 0xa75F995f252ba5F7C17f834b314201271d32eC35;
        } else {
            revert InvalidChain();
        }

        (bool success, ) = NftNativeTrading.call{ value: _msgValue }(_data);

        if (!success && _revertIfTrxFails) {
            // Copy revert reason from call
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function _executeSwap(ExecuteSwapParams calldata params, uint256 _msgValue, bool _revertIfTrxFails) external {
        bytes memory _data = abi.encodeWithSelector(
            INativeNftTrading.executeSwap.selector,
            params.sellOrder,
            params.buyOrder,
            params.v,
            params.r,
            params.s
        );

        address NftNativeTrading;
        if (block.chainid == 1) {
            NftNativeTrading = 0x1fD9Bc58C7FfdB18D19a8A8d791B6ae9fa2BD097;
        } else if (block.chainid == 5 || block.chainid == 31337) {
            NftNativeTrading = 0xa75F995f252ba5F7C17f834b314201271d32eC35;
        } else {
            revert InvalidChain();
        }

        (bool success, ) = NftNativeTrading.call{ value: _msgValue }(_data);

        if (!success && _revertIfTrxFails) {
            // Copy revert reason from call
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}
