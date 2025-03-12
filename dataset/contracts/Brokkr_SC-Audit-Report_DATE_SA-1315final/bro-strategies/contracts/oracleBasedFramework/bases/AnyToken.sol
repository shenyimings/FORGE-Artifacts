// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { NameValuePair } from "../Common.sol";
import { IAnyToken } from "../interfaces/IAnyToken.sol";
import { SwapServiceLib, SwapService, SwapServiceProvider } from "../libraries/SwapServiceLib.sol";
import { IInvestable } from "../interfaces/IInvestable.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

struct SwapDetail {
    SwapService swapService;
    address[] path;
    address[] reversePath;
    bytes data;
}

abstract contract AnyToken is IAnyToken {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    mapping(IERC20Upgradeable => SwapDetail) public swapDetails;
    address public swapLibAddress;

    function _depositAnyToken(
        IERC20Upgradeable convertableToken,
        uint256 convertableTokenAmountIn,
        NameValuePair[] calldata,
        address msgSender,
        IERC20Upgradeable depositToken
    ) internal returns (uint256) {
        // transferring tokens from sender to this contract
        convertableToken.safeTransferFrom(
            msgSender,
            address(this),
            convertableTokenAmountIn
        );

        if (depositToken == convertableToken) {
            return convertableTokenAmountIn;
        } else {
            // calling the swap library
            SwapDetail storage swapDetail = swapDetails[convertableToken];
            return
                SwapServiceLib.swapExactTokensForTokensExtWrapper(
                    swapLibAddress,
                    swapDetail.swapService,
                    convertableTokenAmountIn,
                    0,
                    swapDetail.path,
                    swapDetail.data
                );
        }
    }

    function _withdrawAnyToken(
        IERC20Upgradeable convertableToken,
        uint256 depositTokenAmountOut,
        NameValuePair[] calldata,
        address msgSender,
        IERC20Upgradeable depositToken
    ) internal {
        SwapDetail storage swapDetail = swapDetails[convertableToken];

        convertableToken.safeTransfer(
            msgSender,
            (depositToken == convertableToken)
                ? depositTokenAmountOut
                : SwapServiceLib.swapExactTokensForTokensExtWrapper(
                    swapLibAddress,
                    swapDetail.swapService,
                    depositTokenAmountOut,
                    0,
                    swapDetail.reversePath,
                    swapDetail.data
                )
        );
    }

    function _setSwapDetail(
        IERC20Upgradeable swapFrom,
        SwapServiceProvider swapServiceProvider,
        address router,
        address[] calldata path,
        bytes calldata data
    ) internal {
        uint256 pathLength = path.length;
        address[] memory reversePath = new address[](pathLength);
        for (uint256 i = 0; i < pathLength; i++) {
            reversePath[i] = path[pathLength - 1 - i];
        }

        swapDetails[swapFrom] = SwapDetail(
            SwapService(swapServiceProvider, router),
            path,
            reversePath,
            data
        );
    }

    function _removeSwapDetail(IERC20Upgradeable swapDetailToRemove) internal {
        delete swapDetails[swapDetailToRemove];
    }

    function _setSwapLibAddress(address newSwapLibAddress) internal {
        swapLibAddress = newSwapLibAddress;
    }
}
