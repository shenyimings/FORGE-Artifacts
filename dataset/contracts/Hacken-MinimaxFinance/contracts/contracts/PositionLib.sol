// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./PositionInfo.sol";
import "./pool/IPoolAdapter.sol";
import "./ProxyCaller.sol";
import "./ProxyCallerApi.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IMinimaxMain.sol";
import "./interfaces/IERC20Decimals.sol";
import "./market/IMarket.sol";
import "./PositionBalanceLib.sol";
import "./PositionExchangeLib.sol";

library PositionLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ProxyCallerApi for ProxyCaller;

    uint public constant StakeSimpleKind = 1;

    uint public constant StakeSwapMarketKind = 2;

    struct StakeSwapMarket {
        bytes hints;
    }

    uint public constant StakeSwapOneInchKind = 3;

    struct StakeSwapOneInch {
        bytes oneInchCallData;
    }

    struct StakeParams {
        uint inputAmount;
        IERC20Upgradeable inputToken;
        uint stakingAmountMin;
        IERC20Upgradeable stakingToken;
        address stakingPool;
        uint maxSlippage;
        uint stopLossPrice;
        uint takeProfitPrice;
    }

    function stake(
        IMinimaxMain main,
        ProxyCaller proxy,
        uint positionIndex,
        StakeParams memory genericParams,
        uint swapKind,
        bytes memory swapParams
    ) external returns (PositionInfo memory) {
        uint tokenAmount;
        if (swapKind == StakeSimpleKind) {
            tokenAmount = stakeSimple(genericParams);
        } else if (swapKind == StakeSwapMarketKind) {
            StakeSwapMarket memory decoded = abi.decode(swapParams, (StakeSwapMarket));
            tokenAmount = stakeSwapMarket(main, genericParams, decoded);
        } else if (swapKind == StakeSwapOneInchKind) {
            StakeSwapOneInch memory decoded = abi.decode(swapParams, (StakeSwapOneInch));
            tokenAmount = stakeSwapOneInch(main, genericParams, decoded);
        } else {
            revert("invalid stake kind param");
        }
        return createPosition(main, genericParams, tokenAmount, positionIndex, proxy);
    }

    function stakeSimple(StakeParams memory params) private returns (uint) {
        params.stakingToken.safeTransferFrom(address(msg.sender), address(this), params.inputAmount);
        return params.inputAmount;
    }

    function stakeSwapMarket(
        IMinimaxMain main,
        StakeParams memory genericParams,
        StakeSwapMarket memory params
    ) private returns (uint) {
        IMarket market = main.market();
        require(address(market) != address(0), "no market");
        genericParams.inputToken.safeTransferFrom(address(msg.sender), address(this), genericParams.inputAmount);
        genericParams.inputToken.approve(address(market), genericParams.inputAmount);

        return
            market.swap(
                address(genericParams.inputToken),
                address(genericParams.stakingToken),
                genericParams.inputAmount,
                genericParams.stakingAmountMin,
                address(this),
                params.hints
            );
    }

    function makeSwapOneInchImpl(
        uint amount,
        IERC20Upgradeable inputToken,
        address router,
        StakeSwapOneInch memory params
    ) private returns (uint) {
        require(router != address(0), "no 1inch router set");
        inputToken.approve(router, amount);

        (bool success, bytes memory retData) = router.call(params.oneInchCallData);

        ProxyCallerApi.propagateError(success, retData, "1inch");

        require(success == true, "calling 1inch got an error");
        (uint actualAmount, ) = abi.decode(retData, (uint, uint));
        return actualAmount;
    }

    function makeSwapOneInch(
        uint amount,
        address inputToken,
        address router,
        StakeSwapOneInch memory params
    ) external returns (uint) {
        return makeSwapOneInchImpl(amount, IERC20Upgradeable(inputToken), router, params);
    }

    function stakeSwapOneInch(
        IMinimaxMain main,
        StakeParams memory genericParams,
        StakeSwapOneInch memory params
    ) private returns (uint) {
        genericParams.inputToken.safeTransferFrom(address(msg.sender), address(this), genericParams.inputAmount);
        address oneInchRouter = main.oneInchRouter();
        return makeSwapOneInchImpl(genericParams.inputAmount, genericParams.inputToken, oneInchRouter, params);
    }

    function createPosition(
        IMinimaxMain main,
        StakeParams memory genericParams,
        uint tokenAmount,
        uint positionIndex,
        ProxyCaller proxy
    ) private returns (PositionInfo memory) {
        IPoolAdapter adapter = main.getPoolAdapterSafe(genericParams.stakingPool);

        require(
            adapter.stakedToken(genericParams.stakingPool, abi.encode(genericParams.stakingToken)) ==
                address(genericParams.stakingToken),
            "stakeToken: invalid staking token."
        );

        address rewardToken = adapter.rewardToken(genericParams.stakingPool, abi.encode(genericParams.stakingToken));

        uint userFeeAmount = main.getUserFeeAmount(address(msg.sender), tokenAmount);
        uint amountToStake = tokenAmount - userFeeAmount;

        PositionInfo memory position = PositionInfo({
            stakedAmount: amountToStake,
            feeAmount: userFeeAmount,
            stopLossPrice: genericParams.stopLossPrice,
            maxSlippage: genericParams.maxSlippage,
            poolAddress: genericParams.stakingPool,
            owner: address(msg.sender),
            callerAddress: proxy,
            closed: false,
            takeProfitPrice: genericParams.takeProfitPrice,
            stakedToken: genericParams.stakingToken,
            rewardToken: IERC20Upgradeable(rewardToken),
            gelatoLiquidateTaskId: 0
        });

        proxyDeposit(position, adapter, amountToStake);

        return position;
    }

    function proxyDeposit(
        PositionInfo memory position,
        IPoolAdapter adapter,
        uint amount
    ) private {
        position.stakedToken.safeTransfer(address(position.callerAddress), amount);
        position.callerAddress.approve(position.stakedToken, position.poolAddress, amount);
        position.callerAddress.deposit(
            adapter,
            position.poolAddress,
            amount,
            abi.encode(position.stakedToken) // pass stakedToken for aave pools
        );
    }

    function alterPositionParams(
        IMinimaxMain main,
        PositionInfo storage position,
        uint positionIndex,
        uint newAmount,
        uint newStopLossPrice,
        uint newTakeProfitPrice,
        uint newSlippage
    ) external returns (bool shouldClose) {
        require(position.owner == address(msg.sender), "stop loss may be changed only by position owner");

        position.stopLossPrice = newStopLossPrice;
        position.takeProfitPrice = newTakeProfitPrice;
        position.maxSlippage = newSlippage;

        if (newAmount < position.stakedAmount) {
            uint withdrawAmount = position.stakedAmount - newAmount;
            return withdraw(main, position, positionIndex, withdrawAmount, false);
        } else if (newAmount > position.stakedAmount) {
            uint depositAmount = newAmount - position.stakedAmount;
            deposit(main, position, positionIndex, depositAmount);
            return false;
        }
    }

    // Withdraws `amount` tokens from position on underlying proxyCaller address
    function withdraw(
        IMinimaxMain main,
        PositionInfo storage position,
        uint positionIndex,
        uint amount,
        bool amountAll
    ) public returns (bool shouldClose) {
        require(position.owner == address(msg.sender), "withdraw: only position owner allowed");

        IPoolAdapter adapter = main.getPoolAdapterSafe(position.poolAddress);
        require(position.closed == false, "withdraw: position is closed");

        if (amountAll) {
            position.callerAddress.withdrawAll(
                adapter,
                position.poolAddress,
                abi.encode(position.stakedToken) // pass stakedToken for aave pools
            );
        } else {
            position.callerAddress.withdraw(
                adapter,
                position.poolAddress,
                amount,
                abi.encode(position.stakedToken) // pass stakedToken for aave pools
            );
        }

        uint poolBalance = position.callerAddress.stakingBalance(
            adapter,
            position.poolAddress,
            abi.encode(position.stakedToken)
        );
        if (poolBalance == 0 || amountAll) {
            return true;
        }

        position.stakedAmount = poolBalance;
        return false;
    }

    // Emits `PositionsWasModified` always.
    function deposit(
        IMinimaxMain main,
        PositionInfo storage position,
        uint positionIndex,
        uint amount
    ) public {
        IPoolAdapter adapter = main.getPoolAdapterSafe(position.poolAddress);

        require(position.owner == address(msg.sender), "deposit: only position owner allowed");
        require(position.closed == false, "deposit: position is closed");

        position.stakedToken.safeTransferFrom(address(msg.sender), address(this), amount);

        uint userFeeAmount = main.getUserFeeAmount(msg.sender, amount);
        uint amountToDeposit = amount - userFeeAmount;

        position.stakedAmount = position.stakedAmount + amountToDeposit;
        position.feeAmount = position.feeAmount + userFeeAmount;

        proxyDeposit(position, adapter, amountToDeposit);
        position.callerAddress.transferAll(position.rewardToken, position.owner);
    }

    function estimatePositionStakedTokenPrice(IMinimaxMain minimaxMain, IERC20Upgradeable positionStakedToken)
        public
        returns (uint price, uint8 priceDecimals)
    {
        // Try price oracle first.

        IPriceOracle priceOracle = minimaxMain.priceOracles(positionStakedToken);
        if (address(priceOracle) != address(0)) {
            int price = Math.max(0, priceOracle.latestAnswer());
            return (uint(price), priceOracle.decimals());
        }

        // We don't have price oracles for `positionStakedToken` -- try to estimate via the Market.

        IMarket market = minimaxMain.market();

        // Market is unavailable, nothing we can do here.
        if (address(market) == address(0)) {
            return (0, 0);
        }

        uint8 positionStakedTokenDecimals = IERC20Decimals(address(positionStakedToken)).decimals();

        (bool success, bytes memory encodedEstimateOutResult) = address(market).call(
            abi.encodeCall(
                market.estimateOut,
                (address(positionStakedToken), minimaxMain.busdAddress(), 10**positionStakedTokenDecimals)
            )
        );
        if (!success) {
            return (0, 0);
        }

        (uint estimatedOut, ) = abi.decode(encodedEstimateOutResult, (uint256, bytes));
        uint8 stablecoinDecimals = IERC20Decimals(minimaxMain.busdAddress()).decimals();
        return (estimatedOut, stablecoinDecimals);
    }

    function estimateLpPartsForPosition(IMinimaxMain minimaxMain, PositionInfo memory position)
        internal
        returns (uint, uint)
    {
        uint withdrawnBalance = position.stakedToken.balanceOf(address(position.callerAddress));
        position.callerAddress.transferAll(position.stakedToken, address(minimaxMain));

        IERC20Upgradeable(position.stakedToken).transfer(address(position.stakedToken), withdrawnBalance);

        (uint amount0, uint amount1) = IPairToken(address(position.stakedToken)).burn(address(minimaxMain));
        return (amount0, amount1);
    }

    function isOutsideRange(IMinimaxMain minimaxMain, PositionInfo storage position)
        external
        returns (
            bool isOutsideRange,
            uint256 amountOut,
            bytes memory hints
        )
    {
        bool isOutsideRange;
        isOutsideRange = isOpen(position);
        if (!isOutsideRange) {
            return (isOutsideRange, amountOut, hints);
        }

        PositionBalanceLib.PositionBalance memory balance = PositionBalanceLib.get(minimaxMain, position);

        uint amountIn = balance.total;
        (amountOut, hints) = minimaxMain.market().estimateOut(
            address(position.stakedToken),
            minimaxMain.busdAddress(),
            amountIn
        );

        uint8 outDecimals = IERC20Decimals(minimaxMain.busdAddress()).decimals();
        uint8 inDecimals = IERC20Decimals(address(position.stakedToken)).decimals();
        isOutsideRange = PositionExchangeLib.isPriceOutsideRange(
            position,
            amountOut,
            amountIn,
            outDecimals,
            inDecimals
        );
        if (!isOutsideRange) {
            return (isOutsideRange, amountOut, hints);
        }

        // if price oracle exists then double check
        // that price is outside range
        IPriceOracle oracle = minimaxMain.priceOracles(position.stakedToken);
        if (address(oracle) != address(0)) {
            uint oracleMultiplier = 10**oracle.decimals();
            uint oraclePrice = uint(oracle.latestAnswer());
            isOutsideRange = PositionExchangeLib.isPriceOutsideRange(position, oraclePrice, oracleMultiplier, 0, 0);
            if (!isOutsideRange) {
                return (isOutsideRange, amountOut, hints);
            }
        }

        return (isOutsideRange, amountOut, hints);
    }

    function isOpen(PositionInfo storage position) private view returns (bool) {
        return !position.closed && position.owner != address(0);
    }
}
