// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./VestedToken.sol";

contract GalaxyArena is VestedToken, AccessControlUpgradeable {
    function initialize() public initializer {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        __ERC20_init("Essence Token", "ESNC");
        _mint(msg.sender, 1000000000 ether);
    }

    function setupVestingSchedule(
        uint256 cliff,
        uint256 cliffAmount,
        uint256 duration,
        address vestingAdmin
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setupSchedule(cliff, cliffAmount, duration, vestingAdmin);
    }

    uint256[50] private __gap;
}
