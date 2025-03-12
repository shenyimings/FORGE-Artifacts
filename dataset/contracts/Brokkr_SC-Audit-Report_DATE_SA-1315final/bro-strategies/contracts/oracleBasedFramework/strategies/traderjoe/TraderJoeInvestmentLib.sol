// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./TraderJoeStorageLib.sol";
import "../../libraries/Math.sol";
import "../../libraries/SwapServiceLib.sol";

import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

library TraderJoeInvestmentLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    error InvalidActiveBinAllocation();

    function deposit(uint256 depositTokenAmount, uint256 pairDepositTokenAmount)
        public
    {
        TraderJoeStorage storage strategyStorage = TraderJoeStorageLib
            .getStorage();

        uint256 pairDepositTokenBefore = strategyStorage
            .pairDepositToken
            .balanceOf(address(this)) - pairDepositTokenAmount;

        uint256 amountXIn;
        uint256 amountYIn;

        if (strategyStorage.tokenX == strategyStorage.depositToken) {
            amountXIn = depositTokenAmount;
            amountYIn = pairDepositTokenAmount;
        } else {
            amountXIn = pairDepositTokenAmount;
            amountYIn = depositTokenAmount;
        }

        (
            uint256 amountX,
            uint256 amountY,
            uint256 activeId,
            int256[] memory deltaIds,
            uint256[] memory distributionX,
            uint256[] memory distributionY
        ) = __prepareParams(amountXIn, amountYIn);

        // Deposit.
        ITraderJoeLBRouter.LiquidityParameters memory liquidityParameters = ITraderJoeLBRouter
            .LiquidityParameters(
                address(strategyStorage.tokenX),
                address(strategyStorage.tokenY),
                strategyStorage.binStep,
                amountX,
                amountY,
                0, // Base contracts take care of min amount.
                0, // Base contracts take care of min amount.
                activeId,
                0,
                deltaIds,
                distributionX,
                distributionY,
                address(this),
                // solhint-disable-next-line not-rely-on-time
                block.timestamp
            );

        strategyStorage.tokenX.approve(
            address(strategyStorage.lbRouter),
            amountX
        );
        strategyStorage.tokenY.approve(
            address(strategyStorage.lbRouter),
            amountY
        );

        strategyStorage.lbRouter.addLiquidity(liquidityParameters);

        uint256 pairDepositTokenAfter = strategyStorage
            .pairDepositToken
            .balanceOf(address(this));

        uint256 pairDepositTokenIncrement = pairDepositTokenAfter -
            pairDepositTokenBefore;

        // Swap back remaining pairDepositToken to strategyStorage.depositToken if possible.
        swapTokens(
            pairDepositTokenIncrement,
            strategyStorage.pairDepositToken,
            strategyStorage.depositToken
        );
    }

    function withdraw(uint256 amount, uint256 investmentTokenSupply) public {
        TraderJoeStorage storage strategyStorage = TraderJoeStorageLib
            .getStorage();

        // Calculate LP token balance to withdraw per bin.
        uint256 binsAmount = strategyStorage.binIds.length;
        uint256[] memory amounts = new uint256[](binsAmount);

        for (uint256 i; i < binsAmount; ++i) {
            uint256 lpTokenBalance = strategyStorage.lbPair.balanceOf(
                address(this),
                strategyStorage.binIds[i]
            );

            amounts[i] = (lpTokenBalance * amount) / investmentTokenSupply;
        }

        // Withdraw.
        strategyStorage.lbPair.setApprovalForAll(
            address(strategyStorage.lbRouter),
            true
        );

        strategyStorage.lbRouter.removeLiquidity(
            address(strategyStorage.tokenX),
            address(strategyStorage.tokenY),
            uint16(strategyStorage.binStep),
            0, // Base contracts take care of min amount.
            0, // Base contracts take care of min amount.
            strategyStorage.binIds,
            amounts,
            address(this),
            // solhint-disable-next-line not-rely-on-time
            block.timestamp
        );
    }

    function reapReward() external {
        TraderJoeStorage storage strategyStorage = TraderJoeStorageLib
            .getStorage();

        uint256 pairdepositTokenBefore = strategyStorage
            .pairDepositToken
            .balanceOf(address(this));

        strategyStorage.lbPair.collectFees(
            address(this),
            strategyStorage.binIds
        );

        uint256 pairDepositTokenAfter = strategyStorage
            .pairDepositToken
            .balanceOf(address(this));

        uint256 pairDepositTokenIncrement = pairDepositTokenAfter -
            pairdepositTokenBefore;

        swapTokens(
            pairDepositTokenIncrement,
            strategyStorage.pairDepositToken,
            strategyStorage.depositToken
        );
    }

    function adjustBins(
        uint256[] calldata binIds,
        uint256[] calldata binAllocations,
        uint256 investmentTokenSupply
    ) external {
        TraderJoeStorage storage strategyStorage = TraderJoeStorageLib
            .getStorage();

        // Withdraw from all bins.
        uint256 depositTokenBefore = strategyStorage.depositToken.balanceOf(
            address(this)
        );
        uint256 pairDepositTokenBefore = strategyStorage
            .pairDepositToken
            .balanceOf(address(this));

        withdraw(investmentTokenSupply, investmentTokenSupply);

        uint256 depositTokenAfter = strategyStorage.depositToken.balanceOf(
            address(this)
        );
        uint256 pairDepositTokenAfter = strategyStorage
            .pairDepositToken
            .balanceOf(address(this));

        // Set bin IDs and allocations to the given ones.
        strategyStorage.binIds = binIds;
        strategyStorage.binAllocations = binAllocations;

        // Deposit into the new bins with the new allocations.
        uint256 depositTokenIncrement = depositTokenAfter - depositTokenBefore;
        uint256 pairDepositTokenIncrement = pairDepositTokenAfter -
            pairDepositTokenBefore;

        deposit(depositTokenIncrement, pairDepositTokenIncrement);
    }

    function swapTokens(
        uint256 amountIn,
        IERC20Upgradeable tokenIn,
        IERC20Upgradeable tokenOut
    ) public returns (uint256 amountOut) {
        TraderJoeStorage storage strategyStorage = TraderJoeStorageLib
            .getStorage();

        (amountOut, ) = strategyStorage.lbRouter.getSwapOut(
            address(strategyStorage.lbPair),
            amountIn,
            strategyStorage.tokenY == strategyStorage.depositToken
        );

        if (amountOut == 0) {
            return 0;
        }

        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        uint256[] memory binSteps = new uint256[](1);
        binSteps[0] = strategyStorage.binStep;

        amountOut = SwapServiceLib.swapExactTokensForTokens(
            strategyStorage.swapService,
            amountIn,
            0,
            path,
            binSteps
        );
    }

    function __prepareParams(uint256 amountXIn, uint256 amountYIn)
        private
        returns (
            uint256 amountX,
            uint256 amountY,
            uint256 activeId,
            int256[] memory deltaIds,
            uint256[] memory distributionX,
            uint256[] memory distributionY
        )
    {
        TraderJoeStorage storage strategyStorage = TraderJoeStorageLib
            .getStorage();

        uint256 binsAmount = strategyStorage.binIds.length;

        (, , activeId) = strategyStorage.lbPair.getReservesAndId();

        // Assume that token X and token Y have the same price.
        uint256 totalAmount = amountXIn + amountYIn;

        // Delta IDs.
        deltaIds = new int256[](binsAmount);

        // Distributions.
        distributionX = new uint256[](binsAmount);
        distributionY = new uint256[](binsAmount);

        // The maximum of the number of bins is 51.
        uint256 activeBinIndex = type(uint256).max;

        for (uint256 i; i < binsAmount; ++i) {
            deltaIds[i] = int256(strategyStorage.binIds[i]) - int256(activeId);

            // Bin allocation has precision of 1e3.
            uint256 amount = (totalAmount * strategyStorage.binAllocations[i]) /
                1e3;

            if (strategyStorage.binIds[i] < activeId) {
                distributionY[i] = amount;
                amountY += amount;
            } else if (strategyStorage.binIds[i] > activeId) {
                distributionX[i] = amount;
                amountX += amount;
            } else {
                activeBinIndex = i;
            }
        }

        // If one of our target bins is active, allocate rest of amountXIn and amountYIn to it to minimize swap fee.
        if (activeBinIndex != type(uint256).max) {
            uint256 amount = totalAmount - amountX - amountY;

            if (amountXIn > amountX) {
                uint256 amountXActive = Math.min(amountXIn - amountX, amount);

                distributionX[activeBinIndex] = amountXActive;
                amountX += amountXActive;

                amount -= amountXActive;
            }

            if (amountYIn > amountY) {
                uint256 amountYActive = Math.min(amountYIn - amountY, amount);

                distributionY[activeBinIndex] = amountYActive;
                amountY += amountYActive;

                amount -= amountYActive;
            }

            if (amount > 0) {
                revert InvalidActiveBinAllocation();
            }
        }

        // Calibrate distributions so that the sum of them equals to 1e18, a precision of TraderJoe V2.
        for (uint256 i; i < binsAmount; ++i) {
            bool calibrateX;
            bool calibrateY;

            if (strategyStorage.binIds[i] < activeId) {
                calibrateY = true;
            } else if (strategyStorage.binIds[i] > activeId) {
                calibrateX = true;
            } else {
                calibrateX = true;
                calibrateY = true;
            }

            if (calibrateX && amountX != 0) {
                distributionX[i] = (distributionX[i] * 1e18) / amountX;
            }
            if (calibrateY && amountY != 0) {
                distributionY[i] = (distributionY[i] * 1e18) / amountY;
            }
        }

        // Swap only as much as is needed.
        if (amountXIn > amountX) {
            amountY =
                amountYIn +
                swapTokens(
                    amountXIn - amountX,
                    strategyStorage.tokenX,
                    strategyStorage.tokenY
                );
        } else if (amountYIn > amountY) {
            amountX =
                amountXIn +
                swapTokens(
                    amountYIn - amountY,
                    strategyStorage.tokenY,
                    strategyStorage.tokenX
                );
        }
    }
}
