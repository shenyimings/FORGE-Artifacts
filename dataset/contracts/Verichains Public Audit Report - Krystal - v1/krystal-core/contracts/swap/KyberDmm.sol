// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./BaseSwap.sol";
import "../interfaces/IDMMRouter.sol";
import "../libraries/BytesLib.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@kyber.network/utils-sc/contracts/IERC20Ext.sol";

/// General swap for uniswap and its clones
contract KyberDmm is BaseSwap {
    using SafeMath for uint256;
    using Address for address;
    using BytesLib for bytes;

    IDMMRouter public dmmRouter;

    event UpdatedDmmRouter(IDMMRouter router);

    constructor(address _admin, IDMMRouter router) BaseSwap(_admin) {
        dmmRouter = router;
    }

    function updateDmmRouter(IDMMRouter router) external onlyAdmin {
        dmmRouter = router;
        emit UpdatedDmmRouter(dmmRouter);
    }

    /// @dev get expected return and conversion rate if using a Uni router
    function getExpectedReturn(GetExpectedReturnParams calldata params)
        external
        view
        override
        onlyProxyContract
        returns (uint256 destAmount)
    {
        address[] memory pools = parseExtraArgs(params.tradePath.length - 1, params.extraArgs);
        IERC20[] memory tradePathErc = new IERC20[](params.tradePath.length);
        for (uint256 i = 0; i < params.tradePath.length; i++) {
            tradePathErc[i] = IERC20(params.tradePath[i]);
        }

        // in case pair is not supported
        try dmmRouter.getAmountsOut(params.srcAmount, pools, tradePathErc) returns (
            uint256[] memory amounts
        ) {
            destAmount = amounts[params.tradePath.length - 1];
        } catch {
            destAmount = 0;
        }
    }

    /// @dev swap token via a supported UniSwap router
    /// @notice for some tokens that are paying fee, for example: DGX
    /// contract will trade with received src token amount (after minus fee)
    /// for UniSwap, fee will be taken in src token
    function swap(SwapParams calldata params)
        external
        payable
        override
        nonReentrant
        onlyProxyContract
        returns (uint256 destAmount)
    {
        require(params.tradePath.length >= 2, "invalid tradePath");

        address[] memory pools = parseExtraArgs(params.tradePath.length - 1, params.extraArgs);

        safeApproveAllowance(address(dmmRouter), IERC20Ext(params.tradePath[0]));

        uint256 tradeLen = params.tradePath.length;
        IERC20Ext actualSrc = IERC20Ext(params.tradePath[0]);
        IERC20Ext actualDest = IERC20Ext(params.tradePath[tradeLen - 1]);

        // convert eth/bnb -> weth/wbnb address to trade on Uni
        IERC20[] memory convertedTradePath = new IERC20[](params.tradePath.length);
        for (uint256 i = 0; i < params.tradePath.length; i++) {
            convertedTradePath[i] = params.tradePath[i] == address(ETH_TOKEN_ADDRESS)
                ? dmmRouter.weth()
                : IERC20(params.tradePath[i]);
        }

        uint256 destBalanceBefore = getBalance(actualDest, params.recipient);

        if (actualSrc == ETH_TOKEN_ADDRESS) {
            // swap eth/bnb -> token
            dmmRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: params.srcAmount}(
                params.minDestAmount,
                pools,
                convertedTradePath,
                params.recipient,
                MAX_AMOUNT
            );
        } else {
            if (actualDest == ETH_TOKEN_ADDRESS) {
                // swap token -> eth/bnb
                dmmRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
                    params.srcAmount,
                    params.minDestAmount,
                    pools,
                    convertedTradePath,
                    params.recipient,
                    MAX_AMOUNT
                );
            } else {
                // swap token -> token
                dmmRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    params.srcAmount,
                    params.minDestAmount,
                    pools,
                    convertedTradePath,
                    params.recipient,
                    MAX_AMOUNT
                );
            }
        }

        destAmount = getBalance(actualDest, params.recipient).sub(destBalanceBefore);
    }

    /// @param extraArgs expecting <[20B] address pool1><[20B] address pool2><[20B] address pool3>...
    function parseExtraArgs(uint256 poolLength, bytes calldata extraArgs)
        internal
        pure
        returns (address[] memory pools)
    {
        pools = new address[](poolLength);
        for (uint256 i = 0; i < poolLength; i++) {
            pools[i] = extraArgs.toAddress(i * 20);
        }
    }
}
