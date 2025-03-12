// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../bases/strategy/StrategyOwnablePausableBaseUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract OwnableV2 is UUPSUpgradeable, StrategyOwnablePausableBaseUpgradeable {
    // solhint-disable-next-line const-name-snakecase
    string public constant trackingName =
        "brokkr.test_strategy.ownable_strategy_v2.0.0";
    // solhint-disable-next-line const-name-snakecase
    string public constant humanReadableName = "Ownable Strategy V2";
    // solhint-disable-next-line const-name-snakecase
    string public constant version = "2.0.0";

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(StrategyArgs calldata strategyArgs)
        external
        initializer
    {
        __UUPSUpgradeable_init();
        __StrategyOwnablePausableBaseUpgradeable_init(strategyArgs);
    }

    function reinitialize() external reinitializer(2) {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

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
