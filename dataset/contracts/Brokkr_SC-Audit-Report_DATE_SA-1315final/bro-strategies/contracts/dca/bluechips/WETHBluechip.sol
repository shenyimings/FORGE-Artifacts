// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { DCABaseUpgradeableCutted } from "../base/DCABaseUpgradeableCutted.sol";
import { IAavePool } from "../../dependencies/aave/IAavePool.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract WETHBluechip is UUPSUpgradeable, DCABaseUpgradeableCutted {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct AaveInfo {
        IAavePool aavePool;
        IERC20Upgradeable aToken;
    }

    TokenInfo public bluechipTokenInfo;

    AaveInfo public aaveInfo;

    uint256 private aTokenCompoundingBalance;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        DCAStrategyInitArgs calldata args,
        TokenInfo calldata bluechipTokenInfo_,
        AaveInfo calldata aaveInfo_
    ) external initializer {
        __UUPSUpgradeable_init();
        __DCABaseUpgradeable_init(args);

        bluechipTokenInfo = bluechipTokenInfo_;
        aaveInfo = aaveInfo_;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    // ----- Base Contract Overrides -----
    function _invest(uint256 amount)
        internal
        virtual
        override
        returns (uint256 receivedAToken)
    {
        // 1. Approve bluechip to aave pool
        bluechipTokenInfo.token.safeIncreaseAllowance(
            address(aaveInfo.aavePool),
            amount
        );

        // 2. Supply bluechip
        aaveInfo.aavePool.supply(
            address(bluechipTokenInfo.token),
            amount,
            address(this),
            0 // referal code
        );

        // 3. Actual received amount of aTokens
        // Compouding rewards included into this amount
        uint256 currentATokenBalance = aaveInfo.aToken.balanceOf(address(this));
        receivedAToken = currentATokenBalance - aTokenCompoundingBalance;

        aTokenCompoundingBalance = currentATokenBalance;
    }

    function _claimRewards() internal virtual override returns (uint256) {
        // AAVE Compounds aTokens on its own.
        // Contract includes them when _invest function is triggered.
        return 0;
    }

    function _withdrawInvestedBluechip(uint256 amount)
        internal
        virtual
        override
        returns (uint256 receivedBluechip)
    {
        aTokenCompoundingBalance -= amount;
        receivedBluechip = aaveInfo.aavePool.withdraw(
            address(bluechipTokenInfo.token),
            amount,
            address(this)
        );
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
        if (bluechipInvestmentState == BluechipInvestmentState.Investing) {
            // When investing we exchange bluechip to aToken.
            // Since aToken is not 'staked' somewhere we just have it on contract balance
            return aaveInfo.aToken.balanceOf(address(this));
        }

        if (bluechipInvestmentState == BluechipInvestmentState.Withdrawn) {
            // in case of withdrawn all bluechip is hodling on contract balance
            return bluechipTokenInfo.token.balanceOf(address(this));
        }

        // When emergency exit was triggered the strategy
        // no longer holds any bluechip asset
        return 0;
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
