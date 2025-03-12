// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

import "./interfaces/CloberOrderBook.sol";
import "./interfaces/CloberMarketSwapCallbackReceiver.sol";
import "./interfaces/CloberRouter.sol";
import "./interfaces/CloberMarketFactory.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/CloberOrderNFT.sol";
import "./Errors.sol";

contract MarketRouter is CloberMarketSwapCallbackReceiver, CloberRouter {
    using SafeERC20 for IERC20;

    bool private constant _BID = true;
    bool private constant _ASK = false;

    CloberMarketFactory private immutable _factory;

    mapping(address => bool) private _registeredMarkets;

    modifier checkDeadline(uint64 deadline) {
        _checkDeadline(deadline);
        _;
    }

    function _checkDeadline(uint64 deadline) internal view {
        if (block.timestamp > deadline) {
            revert Errors.CloberError(Errors.DEADLINE);
        }
    }

    modifier flushNative() {
        _;
        if (address(this).balance > 0) {
            (bool success, ) = msg.sender.call{value: address(this).balance}("");
            if (!success) {
                revert Errors.CloberError(Errors.FAILED_TO_SEND_VALUE);
            }
        }
    }

    constructor(address factory) {
        _factory = CloberMarketFactory(factory);
    }

    function cloberMarketSwapCallback(
        address inputToken,
        address,
        uint256 inputAmount,
        uint256,
        bytes calldata data
    ) external payable {
        // check if caller is registered market
        if (!isRegisteredMarket(msg.sender) && _factory.getMarketHost(msg.sender) == address(0)) {
            revert Errors.CloberError(Errors.ACCESS);
        }

        (address payer, bool useNative, uint256 nativeToRemain) = abi.decode(data, (address, bool, uint256));

        // transfer input tokens
        if (useNative) {
            uint256 nativeAmount = address(this).balance - nativeToRemain;
            (inputAmount, nativeAmount) = nativeAmount > inputAmount
                ? (0, inputAmount)
                : (inputAmount - nativeAmount, nativeAmount);

            IWETH(inputToken).deposit{value: nativeAmount}();
            IWETH(inputToken).transfer(msg.sender, nativeAmount);
        }
        if (inputAmount > 0) {
            IERC20(inputToken).safeTransferFrom(payer, msg.sender, inputAmount);
        }
    }

    function limitOrder(
        GeneralLimitOrderParams[] calldata limitOrderParamsList,
        ClaimOrderParams[] calldata claimParamsList
    ) external payable flushNative returns (uint256[] memory orderIds) {
        orderIds = new uint256[](limitOrderParamsList.length);
        _claim(claimParamsList);
        uint256 nativeToRemain;
        for (uint256 i = 0; i < limitOrderParamsList.length; ++i) {
            _checkDeadline(limitOrderParamsList[i].params.deadline);
            nativeToRemain += uint256(limitOrderParamsList[i].params.claimBounty) * 1 gwei;
        }

        for (uint256 i = 0; i < limitOrderParamsList.length; ++i) {
            nativeToRemain -= uint256(limitOrderParamsList[i].params.claimBounty) * 1 gwei;
            orderIds[i] = _limitOrder(limitOrderParamsList[i].params, limitOrderParamsList[i].isBid, nativeToRemain);
        }
    }

    function limitBid(LimitOrderParams calldata params)
        external
        payable
        checkDeadline(params.deadline)
        flushNative
        returns (uint256)
    {
        return _limitOrder(params, _BID);
    }

    function limitAsk(LimitOrderParams calldata params)
        external
        payable
        checkDeadline(params.deadline)
        flushNative
        returns (uint256)
    {
        return _limitOrder(params, _ASK);
    }

    function _limitOrder(LimitOrderParams calldata params, bool isBid) internal returns (uint256) {
        return _limitOrder(params, isBid, 0);
    }

    function _limitOrder(
        LimitOrderParams calldata params,
        bool isBid,
        uint256 nativeToRemain
    ) internal returns (uint256) {
        return
            CloberOrderBook(params.market).limitOrder{value: uint256(params.claimBounty) * 1 gwei}(
                params.user,
                params.priceIndex,
                params.rawAmount,
                params.baseAmount,
                (isBid ? 1 : 0) + (params.postOnly ? 2 : 0),
                abi.encode(msg.sender, params.useNative, nativeToRemain)
            );
    }

    function marketBid(MarketOrderParams calldata params) external payable checkDeadline(params.deadline) flushNative {
        _marketOrder(params, _BID);
    }

    function marketAsk(MarketOrderParams calldata params) external payable checkDeadline(params.deadline) flushNative {
        _marketOrder(params, _ASK);
    }

    function _marketOrder(MarketOrderParams calldata params, bool isBid) internal {
        CloberOrderBook(params.market).marketOrder(
            params.user,
            params.limitPriceIndex,
            params.rawAmount,
            params.baseAmount,
            (isBid ? 1 : 0) + (params.expendInput ? 2 : 0),
            abi.encode(msg.sender, params.useNative, 0)
        );
    }

    function claim(uint64 deadline, ClaimOrderParams[] calldata paramsList)
        external
        checkDeadline(deadline)
        flushNative
    {
        _claim(paramsList);
    }

    function _claim(ClaimOrderParams[] calldata paramsList) internal {
        for (uint256 i = 0; i < paramsList.length; ++i) {
            ClaimOrderParams calldata params = paramsList[i];
            CloberOrderBook(params.market).claim(msg.sender, params.orderKeys);
        }
    }

    function limitBidAfterClaim(ClaimOrderParams[] calldata claimParamsList, LimitOrderParams calldata limitOrderParams)
        external
        payable
        checkDeadline(limitOrderParams.deadline)
        flushNative
        returns (uint256)
    {
        _claim(claimParamsList);
        return _limitOrder(limitOrderParams, _BID);
    }

    function limitAskAfterClaim(ClaimOrderParams[] calldata claimParamsList, LimitOrderParams calldata limitOrderParams)
        external
        payable
        checkDeadline(limitOrderParams.deadline)
        flushNative
        returns (uint256)
    {
        _claim(claimParamsList);
        return _limitOrder(limitOrderParams, _ASK);
    }

    function marketBidAfterClaim(
        ClaimOrderParams[] calldata claimParamsList,
        MarketOrderParams calldata marketOrderParams
    ) external payable checkDeadline(marketOrderParams.deadline) flushNative {
        _claim(claimParamsList);
        _marketOrder(marketOrderParams, _BID);
    }

    function marketAskAfterClaim(
        ClaimOrderParams[] calldata claimParamsList,
        MarketOrderParams calldata marketOrderParams
    ) external payable checkDeadline(marketOrderParams.deadline) flushNative {
        _claim(claimParamsList);
        _marketOrder(marketOrderParams, _ASK);
    }

    function isRegisteredMarket(address market) public view returns (bool) {
        return _registeredMarkets[market];
    }

    function registerMarkets(address[] calldata markets) external {
        if (msg.sender != _factory.owner()) {
            revert Errors.CloberError(Errors.ACCESS);
        }
        for (uint256 i = 0; i < markets.length; ++i) {
            _registeredMarkets[markets[i]] = true;
        }
    }

    function unregisterMarkets(address[] calldata markets) external {
        if (msg.sender != _factory.owner()) {
            revert Errors.CloberError(Errors.ACCESS);
        }
        for (uint256 i = 0; i < markets.length; ++i) {
            _registeredMarkets[markets[i]] = false;
        }
    }
}
