// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./BaseSwap.sol";
import "../interfaces/IKyberProxy.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@kyber.network/utils-sc/contracts/IERC20Ext.sol";

/// General swap for uniswap and its clones
contract KyberProxy is BaseSwap {
    using SafeERC20 for IERC20Ext;
    using SafeMath for uint256;
    using Address for address;

    IKyberProxy public kyberProxy;

    event UpdatedKyberProxy(IKyberProxy kyberProxy);

    constructor(address _admin, IKyberProxy _kyberProxy) BaseSwap(_admin) {
        kyberProxy = _kyberProxy;
    }

    function updateKyberProxy(IKyberProxy _kyberProxy) external onlyAdmin {
        kyberProxy = _kyberProxy;
        emit UpdatedKyberProxy(kyberProxy);
    }

    /// @dev get expected return and conversion rate
    function getExpectedReturn(GetExpectedReturnParams calldata params)
        external
        view
        override
        onlyProxyContract
        returns (uint256 destAmount)
    {
        require(params.tradePath.length == 2, "kyber_invalidTradepath");
        uint256 expectedRate;
        try
            kyberProxy.getExpectedRateAfterFee(
                IERC20Ext(params.tradePath[0]),
                IERC20Ext(params.tradePath[1]),
                params.srcAmount,
                params.feeBps,
                params.extraArgs
            )
        returns (uint256 rate) {
            expectedRate = rate;
        } catch {
            expectedRate = 0;
        }
        destAmount = calcDestAmount(
            IERC20Ext(params.tradePath[0]),
            IERC20Ext(params.tradePath[1]),
            params.srcAmount,
            expectedRate
        );
    }

    /// @dev swap token
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
        require(params.tradePath.length == 2, "kyber_invalidTradepath");

        safeApproveAllowance(address(kyberProxy), IERC20Ext(params.tradePath[0]));

        uint256 destBalanceBefore = getBalance(IERC20Ext(params.tradePath[1]), params.recipient);
        uint256 callValue = params.tradePath[0] == address(ETH_TOKEN_ADDRESS)
            ? params.srcAmount
            : 0;
        kyberProxy.tradeWithHintAndFee{value: callValue}(
            IERC20Ext(params.tradePath[0]),
            params.srcAmount,
            IERC20Ext(params.tradePath[1]),
            payable(params.recipient),
            MAX_AMOUNT,
            params.minDestAmount,
            params.feeReceiver,
            params.feeBps,
            params.extraArgs
        );
        destAmount = getBalance(IERC20Ext(params.tradePath[1]), params.recipient).sub(
            destBalanceBefore
        );
    }
}
