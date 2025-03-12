// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/IInvestable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract InvestmentLimitUpgradeable is Initializable, IInvestable {
    error TotalInvestmentLimitExceeded();
    error InvestmentLimitPerAddressExceeded();

    uint256 private totalInvestmentLimit;
    uint256 private investmentLimitPerAddress;
    uint256[8] private __gap;

    // solhint-disable-next-line func-name-mixedcase
    function __InvestmentLimitUpgradeable_init(
        uint256 totalInvestmentLimit_,
        uint256 investmentLimitPerAddress_
    ) internal onlyInitializing {
        _setTotalInvestmentLimit(totalInvestmentLimit_);
        _setInvestmentLimitPerAddress(investmentLimitPerAddress_);
    }

    function getTotalInvestmentLimit()
        public
        view
        virtual
        override
        returns (uint256)
    {
        return totalInvestmentLimit;
    }

    function _setTotalInvestmentLimit(uint256 totalInvestmentLimit_)
        internal
        virtual
    {
        totalInvestmentLimit = totalInvestmentLimit_;
    }

    function getInvestmentLimitPerAddress()
        public
        view
        virtual
        override
        returns (uint256)
    {
        return investmentLimitPerAddress;
    }

    function _setInvestmentLimitPerAddress(uint256 investmentLimitPerAddress_)
        internal
        virtual
    {
        investmentLimitPerAddress = investmentLimitPerAddress_;
    }
}

library InvestmentLimitLib {
    function checkTotalInvestmentLimit(
        uint256 aboutToInvest,
        uint256 totalInvestedSoFar,
        uint256 totalInvestmentLimit
    ) internal pure {
        if (aboutToInvest + totalInvestedSoFar > totalInvestmentLimit)
            revert InvestmentLimitUpgradeable.TotalInvestmentLimitExceeded();
    }

    function checkInvestmentLimitPerAddress(
        uint256 aboutToInvest,
        uint256 investedSoFarPerAddress,
        uint256 investmentLimitPerAddress
    ) internal pure {
        if (aboutToInvest + investedSoFarPerAddress > investmentLimitPerAddress)
            revert InvestmentLimitUpgradeable
                .InvestmentLimitPerAddressExceeded();
    }
}
