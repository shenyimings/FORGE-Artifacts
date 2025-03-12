// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { DCABaseUpgradeableCutted } from "../base/DCABaseUpgradeableCutted.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract CoinBluechip is UUPSUpgradeable, DCABaseUpgradeableCutted {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    TokenInfo public bluechipTokenInfo;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        DCAStrategyInitArgs calldata args,
        TokenInfo calldata bluechipTokenInfo_
    ) external initializer {
        __UUPSUpgradeable_init();
        __DCABaseUpgradeable_init(args);

        bluechipTokenInfo = bluechipTokenInfo_;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    // ----- Base Contract Overrides -----
    function _invest(uint256 amount)
        internal
        virtual
        override
        returns (uint256)
    {
        return amount;
    }

    function _claimRewards()
        internal
        virtual
        override
        returns (uint256 claimedAmount)
    {}

    function _withdrawInvestedBluechip(uint256 amount)
        internal
        virtual
        override
        returns (uint256)
    {
        return amount;
    }

    function _transferBluechip(address to, uint256 amount)
        internal
        virtual
        override
    {
        bluechipTokenInfo.token.safeTransfer(to, amount);
    }

    function _totalBluechipInvested()
        internal
        view
        virtual
        override
        returns (uint256)
    {
        if (
            bluechipInvestmentState == BluechipInvestmentState.Investing ||
            bluechipInvestmentState == BluechipInvestmentState.Withdrawn
        ) {
            return bluechipTokenInfo.token.balanceOf(address(this));
        } else return 0;
    }

    function _bluechipAddress()
        internal
        view
        virtual
        override
        returns (address)
    {
        return address(bluechipTokenInfo.token);
    }

    function _bluechipDecimals()
        internal
        view
        virtual
        override
        returns (uint8)
    {
        return bluechipTokenInfo.decimals;
    }
}
