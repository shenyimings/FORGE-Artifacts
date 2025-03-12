// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { PortfolioArgs } from "../../bases/portfolio/PortfolioBaseUpgradeable.sol";
import { PortfolioRoleablePausableAnyTokenBaseUpgradeable } from "../../bases/portfolio/PortfolioRoleablePausableAnyTokenBaseUpgradeable.sol";
import { UPGRADE_ROLE } from "../../bases/RoleableUpgradeable.sol";

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract PercentageAllocationAnyToken is
    UUPSUpgradeable,
    PortfolioRoleablePausableAnyTokenBaseUpgradeable
{
    // solhint-disable-next-line const-name-snakecase
    string public constant trackingName =
        "brokkr.percentage_allocation_any_token_portfolio.percentage_allocation_any_token_portfolio_v1.0.0";
    // solhint-disable-next-line const-name-snakecase
    string public constant humanReadableName =
        "Percentage allocation any token portfolio";
    // solhint-disable-next-line const-name-snakecase
    string public constant version = "1.0.0";

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        PortfolioArgs calldata portfolioArgs,
        address newSwapLibAddress
    ) external initializer {
        __UUPSUpgradeable_init();
        __PortfolioRoleablePausableAnyTokenBaseUpgradeable_init(
            portfolioArgs,
            newSwapLibAddress
        );
    }

    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(UPGRADE_ROLE)
    {}
}
