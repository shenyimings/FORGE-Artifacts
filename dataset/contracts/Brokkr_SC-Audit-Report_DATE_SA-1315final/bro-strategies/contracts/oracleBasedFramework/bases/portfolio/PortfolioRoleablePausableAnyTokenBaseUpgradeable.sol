// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { PortfolioArgs } from "./PortfolioBaseUpgradeable.sol";
import { PortfolioRoleablePausableBaseUpgradeable } from "./PortfolioRoleablePausableBaseUpgradeable.sol";
import { AnyToken } from "../AnyToken.sol";
import { NameValuePair } from "../../Common.sol";
import { GOVERNOR_ROLE } from "../RoleableUpgradeable.sol";
import { SwapServiceProvider } from "../../libraries/SwapServiceLib.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

abstract contract PortfolioRoleablePausableAnyTokenBaseUpgradeable is
    PortfolioRoleablePausableBaseUpgradeable,
    AnyToken
{
    // solhint-disable-next-line
    function __PortfolioRoleablePausableAnyTokenBaseUpgradeable_init(
        PortfolioArgs calldata portfolioArgs,
        address newSwapLibAddress
    ) internal onlyInitializing {
        __PortfolioRoleablePausableBaseUpgradeable_init(portfolioArgs);
        _setSwapLibAddress(newSwapLibAddress);
    }

    function depositAnyToken(
        IERC20Upgradeable convertableToken,
        uint256 convertableTokenAmountIn,
        uint256 minimumDepositTokenAmountOut,
        address investmentTokenReceiver,
        NameValuePair[] calldata params
    ) external virtual override whenNotPaused {
        _deposit(
            _depositAnyToken(
                convertableToken,
                convertableTokenAmountIn,
                params,
                _msgSender(),
                depositToken
            ),
            minimumDepositTokenAmountOut,
            investmentTokenReceiver,
            params,
            true
        );
    }

    function withdrawAnyToken(
        IERC20Upgradeable convertableToken,
        uint256 investmentTokenAmountIn,
        uint256 minimumDepositTokenAmountOut,
        address depositTokenReceiver,
        NameValuePair[] calldata params
    ) external virtual override whenNotPaused {
        uint256 depositTokenBalanceBeforeWithdraw = depositToken.balanceOf(
            address(this)
        );
        _withdraw(
            investmentTokenAmountIn,
            minimumDepositTokenAmountOut,
            depositTokenReceiver,
            params,
            false
        );
        _withdrawAnyToken(
            convertableToken,
            depositToken.balanceOf(address(this)) -
                depositTokenBalanceBeforeWithdraw,
            params,
            _msgSender(),
            depositToken
        );
    }

    function setSwapLibAddress(address newSwapLibAddress)
        public
        onlyRole(GOVERNOR_ROLE)
    {
        _setSwapLibAddress(newSwapLibAddress);
    }

    function setSwapDetail(
        IERC20Upgradeable swapFrom,
        SwapServiceProvider swapServiceProvider,
        address router,
        address[] calldata path,
        bytes calldata data
    ) external onlyRole(GOVERNOR_ROLE) {
        _setSwapDetail(swapFrom, swapServiceProvider, router, path, data);
    }

    function removeSwapDetail(IERC20Upgradeable swapDetailToRemove)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        _removeSwapDetail(swapDetailToRemove);
    }
}
