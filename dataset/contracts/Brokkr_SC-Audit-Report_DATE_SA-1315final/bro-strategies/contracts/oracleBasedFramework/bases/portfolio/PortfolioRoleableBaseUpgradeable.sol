// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./PortfolioBaseUpgradeable.sol";
import { RoleableUpgradeable, GOVERNOR_ROLE, STRATEGIST_ROLE, MAINTAINER_ROLE, UPGRADE_ROLE, PAUSE_ROLE, ADMIN_ROLE } from "../RoleableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

abstract contract PortfolioRoleableBaseUpgradeable is
    RoleableUpgradeable,
    PortfolioBaseUpgradeable
{
    uint256[8] private __gap;

    // solhint-disable-next-line
    function __PortfolioRoleableBaseUpgradeable_init(
        PortfolioArgs calldata portfolioArgs
    ) internal onlyInitializing {
        __RoleableBaseUpgradeable_init(portfolioArgs.roleToUsersArray);
        __PortfolioBaseUpgradeable_init(portfolioArgs);
    }

    function addInvestable(
        IInvestable investable,
        uint24[] calldata newAllocations,
        NameValuePair[] calldata params
    ) public virtual onlyRole(GOVERNOR_ROLE) {
        super._addInvestable(investable, newAllocations, params);
    }

    function removeInvestable(
        IInvestable investable,
        uint24[] calldata newAllocations
    ) public virtual onlyRole(GOVERNOR_ROLE) {
        super._removeInvestable(investable, newAllocations);
    }

    function changeInvestable(
        IInvestable investable,
        NameValuePair[] calldata params
    ) public virtual onlyRole(GOVERNOR_ROLE) {
        super._changeInvestable(investable, params);
    }

    function setTargetInvestableAllocations(uint24[] calldata newAllocations)
        public
        virtual
        onlyRole(MAINTAINER_ROLE)
    {
        super._setTargetInvestableAllocations(newAllocations);
    }

    function rebalance(
        uint256 minimumDepositTokenAmountOut,
        NameValuePair[][] calldata depositParams,
        NameValuePair[][] calldata withdrawParams
    ) public virtual onlyRole(MAINTAINER_ROLE) {
        super._rebalance(
            minimumDepositTokenAmountOut,
            depositParams,
            withdrawParams
        );
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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerableUpgradeable, PortfolioBaseUpgradeable)
        returns (bool)
    {
        return
            interfaceId == type(PortfolioRoleableBaseUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
