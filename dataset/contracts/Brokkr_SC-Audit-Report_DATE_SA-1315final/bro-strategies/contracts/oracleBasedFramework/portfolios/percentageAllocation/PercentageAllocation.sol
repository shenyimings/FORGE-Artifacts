// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../bases/portfolio/PortfolioRoleablePausableBaseUpgradeable.sol";

import { UPGRADE_ROLE } from "../../bases/RoleableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract PercentageAllocation is
    UUPSUpgradeable,
    PortfolioRoleablePausableBaseUpgradeable
{
    // solhint-disable-next-line const-name-snakecase
    string public constant trackingName =
        "brokkr.percentage_allocation_portfolio.percentage_allocation_portfolio_v1.1.0";
    // solhint-disable-next-line const-name-snakecase
    string public constant humanReadableName =
        "Percentage allocation portfolio";
    // solhint-disable-next-line const-name-snakecase
    string public constant version = "1.1.0";

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(PortfolioArgs calldata portfolioArgs)
        external
        initializer
    {
        __UUPSUpgradeable_init();
        __PortfolioRoleablePausableBaseUpgradeable_init(portfolioArgs);
    }

    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(UPGRADE_ROLE)
    {}
}
