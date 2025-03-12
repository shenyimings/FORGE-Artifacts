// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./CashStorageLib.sol";
import "../../bases/strategy/StrategyOwnablePausableBaseUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Cash is UUPSUpgradeable, StrategyOwnablePausableBaseUpgradeable {
    // solhint-disable-next-line const-name-snakecase
    string public constant trackingName =
        "brokkr.cash_strategy.cash_strategy_v1.1.0";
    // solhint-disable-next-line const-name-snakecase
    string public constant humanReadableName = "Cash strategy";
    // solhint-disable-next-line const-name-snakecase
    string public constant version = "1.1.0";

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

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _deposit(uint256 amount, NameValuePair[] calldata)
        internal
        virtual
        override
    {}

    function _beforeWithdraw(uint256, NameValuePair[] calldata)
        internal
        virtual
        override
        returns (uint256)
    {
        return 0;
    }

    function _withdraw(uint256 amount, NameValuePair[] calldata)
        internal
        virtual
        override
    {}

    function _afterWithdraw(uint256, NameValuePair[] calldata)
        internal
        virtual
        override
        returns (uint256)
    {
        return 0;
    }

    function _reapReward(NameValuePair[] calldata params)
        internal
        virtual
        override
    {}

    function processReward(NameValuePair[] calldata, NameValuePair[] calldata)
        external
        virtual
        override
        nonReentrant
    {
        emit RewardProcess(0);
        emit Deposit(address(this), address(0), 0);
    }

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
