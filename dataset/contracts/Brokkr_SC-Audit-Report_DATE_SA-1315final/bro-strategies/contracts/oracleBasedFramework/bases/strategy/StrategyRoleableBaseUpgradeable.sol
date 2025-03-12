// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./StrategyBaseUpgradeable.sol";
import { RoleableUpgradeable, GOVERNOR_ROLE, STRATEGIST_ROLE, MAINTAINER_ROLE, UPGRADE_ROLE, PAUSE_ROLE, ADMIN_ROLE } from "../RoleableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

abstract contract StrategyRoleableBaseUpgradeable is
    RoleableUpgradeable,
    StrategyBaseUpgradeable
{
    uint256[8] private __gap;

    // solhint-disable-next-line
    function __StrategyRoleableBaseUpgradeable_init(
        StrategyArgs calldata strategyArgs
    ) internal onlyInitializing {
        __RoleableBaseUpgradeable_init(strategyArgs.roleToUsersArray);
        __StrategyBaseUpgradeable_init(strategyArgs);
    }

    function setDepositFee(uint24 fee_, NameValuePair[] calldata params)
        public
        virtual
        onlyRole(GOVERNOR_ROLE)
    {
        super._setDepositFee(fee_, params);
    }

    function setWithdrawalFee(uint24 fee_, NameValuePair[] calldata params)
        public
        virtual
        onlyRole(GOVERNOR_ROLE)
    {
        super._setWithdrawalFee(fee_, params);
    }

    function setPerformanceFee(uint24 fee_, NameValuePair[] calldata params)
        public
        virtual
        onlyRole(GOVERNOR_ROLE)
    {
        super._setPerformanceFee(fee_, params);
    }

    function takePerformanceFee(NameValuePair[] calldata params)
        external
        virtual
        onlyRole(MAINTAINER_ROLE)
    {
        super._takePerformanceFee(params);
    }

    function setManagementFee(uint24 fee_, NameValuePair[] calldata params)
        public
        virtual
        onlyRole(GOVERNOR_ROLE)
    {
        super._setManagementFee(fee_, params);
    }

    function takeManagementFee(NameValuePair[] calldata params)
        external
        virtual
        onlyRole(MAINTAINER_ROLE)
    {
        super._takeManagementFee(params);
    }

    function setFeeReceiver(
        address feeReceiver_,
        NameValuePair[] calldata params
    ) public virtual onlyRole(GOVERNOR_ROLE) {
        super._setFeeReceiver(feeReceiver_, params);
    }

    function setInvestmentToken(IInvestmentToken investmentToken)
        public
        virtual
        onlyRole(GOVERNOR_ROLE)
    {
        super._setInvestmentToken(investmentToken);
    }

    function setTotalInvestmentLimit(uint256 totalInvestmentLimit)
        public
        virtual
        onlyRole(STRATEGIST_ROLE)
    {
        super._setTotalInvestmentLimit(totalInvestmentLimit);
    }

    function setInvestmentLimitPerAddress(uint256 investmentLimitPerAddress)
        public
        virtual
        onlyRole(STRATEGIST_ROLE)
    {
        super._setInvestmentLimitPerAddress(investmentLimitPerAddress);
    }

    function setPriceOracle(IPriceOracle priceOracle)
        public
        virtual
        onlyRole(GOVERNOR_ROLE)
    {
        super._setPriceOracle(priceOracle);
    }

    function setSwapService(SwapServiceProvider provider, address router)
        public
        virtual
        onlyRole(GOVERNOR_ROLE)
    {
        super._setSwapService(provider, router);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerableUpgradeable, StrategyBaseUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
