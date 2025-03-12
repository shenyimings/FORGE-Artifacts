// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { NameValuePair } from "../../Common.sol";
import { PortfolioArgs } from "./PortfolioBaseUpgradeable.sol";
import { PortfolioRoleableBaseUpgradeable } from "./PortfolioRoleableBaseUpgradeable.sol";
import { PAUSE_ROLE } from "../RoleableUpgradeable.sol";

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

abstract contract PortfolioRoleablePausableBaseUpgradeable is
    PausableUpgradeable,
    PortfolioRoleableBaseUpgradeable
{
    uint256[4] private __gap;

    // solhint-disable-next-line
    function __PortfolioRoleablePausableBaseUpgradeable_init(
        PortfolioArgs calldata portfolioArgs
    ) internal onlyInitializing {
        __Pausable_init();
        __PortfolioRoleableBaseUpgradeable_init(portfolioArgs);
    }

    function pause() external onlyRole(PAUSE_ROLE) {
        super._pause();
    }

    function unpause() external onlyRole(PAUSE_ROLE) {
        super._unpause();
    }

    function deposit(
        uint256 depositTokenAmountIn,
        uint256 minimumDepositTokenAmountOut,
        address investmentTokenReceiver,
        NameValuePair[] calldata params
    ) public virtual override whenNotPaused {
        super._deposit(
            depositTokenAmountIn,
            minimumDepositTokenAmountOut,
            investmentTokenReceiver,
            params,
            false
        );
    }

    function withdraw(
        uint256 investmentTokenAmountIn,
        uint256 minimumDepositTokenAmountOut,
        address depositTokenReceiver,
        NameValuePair[] calldata params
    ) public virtual override whenNotPaused {
        super._withdraw(
            investmentTokenAmountIn,
            minimumDepositTokenAmountOut,
            depositTokenReceiver,
            params,
            true
        );
    }
}
