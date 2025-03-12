// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "../external/@openzeppelin/token/ERC20/IERC20.sol";

interface IRiskProviderRegistry {
    /* ========== FUNCTIONS ========== */

    function isProvider(address provider) external view returns (bool);

    function getRisk(address riskProvider, address strategy) external view returns (uint8);

    function getRisks(address riskProvider, address[] memory strategies) external view returns (uint8[] memory);

    /* ========== EVENTS ========== */

    event RiskAssessed(address indexed provider, address indexed strategy, uint8 riskScore);
    event ProviderAdded(address provider);
    event ProviderRemoved(address provider);
}
