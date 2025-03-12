// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../bases/strategy/StrategyRoleablePausableBaseUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract RoleableV2 is
    UUPSUpgradeable,
    StrategyRoleablePausableBaseUpgradeable
{
    // solhint-disable-next-line const-name-snakecase
    string public constant trackingName =
        "brokkr.test_strategy.roleable_strategy_v2.0.0";
    // solhint-disable-next-line const-name-snakecase
    string public constant humanReadableName = "Roleable Strategy V2";
    // solhint-disable-next-line const-name-snakecase
    string public constant version = "2.0.0";

    function initialize(StrategyArgs calldata strategyArgs)
        external
        initializer
    {
        __UUPSUpgradeable_init();
        __StrategyRoleablePausableBaseUpgradeable_init(strategyArgs);
    }

    function reinitialize() external reinitializer(2) {}

    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(UPGRADE_ROLE)
    {}

    function _deposit(uint256, NameValuePair[] calldata)
        internal
        virtual
        override
    {}

    function _withdraw(uint256, NameValuePair[] calldata)
        internal
        virtual
        override
    {}

    function _reapReward(NameValuePair[] calldata) internal virtual override {}

    function _getAssetBalances()
        internal
        view
        virtual
        override
        returns (Balance[] memory assetBalances)
    {}

    function _getLiabilityBalances()
        internal
        view
        virtual
        override
        returns (Balance[] memory liabilityBalances)
    {}

    function _getAssetValuations(bool, bool)
        internal
        view
        virtual
        override
        returns (Valuation[] memory assetValuations)
    {}

    function _getLiabilityValuations(bool, bool)
        internal
        view
        virtual
        override
        returns (Valuation[] memory liabilityValuations)
    {}
}
