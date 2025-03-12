// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../FeeUpgradeable.sol";
import "../InvestmentLimitUpgradeable.sol";
import "../../interfaces/IERC20UpgradeableExt.sol";
import "../../interfaces/IInvestmentToken.sol";
import "../../interfaces/IPortfolio.sol";
import { IPriceOracle } from "../../interfaces/IPriceOracle.sol";
import "../../libraries/InvestableLib.sol";
import { PortfolioBaseAumLib } from "./libraries/PortfolioBaseAumLib.sol";
import { PortfolioBaseFeeLib } from "./libraries/PortfolioBaseFeeLib.sol";
import { PortfolioBaseInvestmentLib, DepositArgs, WithdrawArgs } from "./libraries/PortfolioBaseInvestmentLib.sol";
import { PortfolioBaseManagementLib, RebalanceArgs } from "./libraries/PortfolioBaseManagementLib.sol";
import { RoleToUsers } from "../../Common.sol";

import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";

struct PortfolioArgs {
    IInvestmentToken investmentToken;
    IERC20UpgradeableExt depositToken;
    FeeArgs feeArgs;
    uint256 totalInvestmentLimit;
    uint256 investmentLimitPerAddress;
    RoleToUsers[] roleToUsersArray;
    IPriceOracle priceOracle;
}

abstract contract PortfolioBaseUpgradeable is
    ContextUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC165Upgradeable,
    FeeUpgradeable,
    InvestmentLimitUpgradeable,
    IPortfolio
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IERC20UpgradeableExt;
    using SafeERC20Upgradeable for IInvestmentToken;
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.AddressToUintMap;

    InvestableDesc[] private investableDescs;

    IInvestmentToken internal investmentToken;
    IERC20UpgradeableExt internal depositToken;
    IPriceOracle public priceOracle;
    uint256[19] private __gap;

    // solhint-disable-next-line
    function __PortfolioBaseUpgradeable_init(
        PortfolioArgs calldata portfolioArgs
    ) internal onlyInitializing {
        __Context_init();
        __ReentrancyGuard_init();
        __ERC165_init();

        __FeeUpgradeable_init(
            portfolioArgs.feeArgs,
            portfolioArgs.depositToken.decimals()
        );

        __InvestmentLimitUpgradeable_init(
            portfolioArgs.totalInvestmentLimit,
            portfolioArgs.investmentLimitPerAddress
        );
        investmentToken = portfolioArgs.investmentToken;
        depositToken = portfolioArgs.depositToken;
        priceOracle = portfolioArgs.priceOracle;
    }

    function _addInvestable(
        IInvestable investable,
        uint24[] calldata newAllocations,
        NameValuePair[] calldata params
    ) internal virtual {
        PortfolioBaseManagementLib.addInvestable(
            investable,
            newAllocations,
            params,
            investableDescs
        );
        emit InvestableAdd(investable, newAllocations, params);
    }

    function _removeInvestable(
        IInvestable investable,
        uint24[] calldata newAllocations
    ) internal virtual {
        PortfolioBaseManagementLib.removeInvestable(
            investable,
            newAllocations,
            investableDescs
        );
        emit InvestableRemove(investable, newAllocations);
    }

    function _changeInvestable(
        IInvestable investable,
        NameValuePair[] calldata params
    ) internal virtual {
        PortfolioBaseManagementLib.changeInvestable(
            investable,
            params,
            investableDescs
        );
        emit InvestableChange(investable, params);
    }

    function _setTargetInvestableAllocations(uint24[] calldata newAllocations)
        internal
        virtual
    {
        PortfolioBaseManagementLib.setTargetInvestableAllocations(
            newAllocations,
            investableDescs
        );
        emit TargetInvestableAllocationsSet(newAllocations);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IAum).interfaceId ||
            interfaceId == type(IFee).interfaceId ||
            interfaceId == type(IInvestable).interfaceId ||
            interfaceId == type(IPortfolio).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _deposit(
        uint256 depositTokenAmountIn,
        uint256 minimumDepositTokenAmountOut,
        address investmentTokenReceiver,
        NameValuePair[] calldata params,
        bool depositTokenAlreadyTransferred
    ) internal virtual nonReentrant {
        address msgSender = _msgSender();

        // 1. emitting event for portfolios at the higher level first
        // 2. emitting the deposit amount versus the actual invested amount
        // 3. library cannot reference events that are defined in the contract, so emitting it here, rather than in the library
        emit Deposit(msgSender, investmentTokenReceiver, depositTokenAmountIn);

        PortfolioBaseInvestmentLib.deposit(
            DepositArgs(
                depositTokenAmountIn,
                minimumDepositTokenAmountOut,
                investmentTokenReceiver,
                depositToken,
                investmentToken,
                msgSender,
                getTotalInvestmentLimit(),
                getInvestmentLimitPerAddress(),
                depositTokenAlreadyTransferred,
                priceOracle
            ),
            investableDescs,
            params
        );
    }

    function _withdraw(
        uint256 investmentTokenAmountIn,
        uint256 minimumDepositTokenAmountOut,
        address depositTokenReceiver,
        NameValuePair[] calldata params,
        bool shouldTransferDepositTokens
    ) public virtual nonReentrant {
        address msgSender = _msgSender();
        emit Withdrawal(
            msgSender,
            depositTokenReceiver,
            investmentTokenAmountIn
        );

        PortfolioBaseInvestmentLib.withdraw(
            WithdrawArgs(
                investmentTokenAmountIn,
                minimumDepositTokenAmountOut,
                depositTokenReceiver,
                depositToken,
                investmentToken,
                msgSender,
                shouldTransferDepositTokens
            ),
            investableDescs,
            params
        );
    }

    function _takePerformanceFee(NameValuePair[] calldata params)
        internal
        virtual
    {}

    function _takeManagementFee(NameValuePair[] calldata params)
        internal
        virtual
    {}

    // workaround for 'stack too deep' error
    struct RebalanceLocalVars {
        uint256 totalEquityBeforeRebalance;
        uint256 totalEquityAfterRebalance;
        uint256 withdrawnAmount;
        uint256 remainingAmount;
    }

    function _rebalance(
        uint256 minimumDepositTokenAmountOut,
        NameValuePair[][] calldata depositParams,
        NameValuePair[][] calldata withdrawParams
    ) internal virtual nonReentrant {
        PortfolioBaseManagementLib._rebalance(
            RebalanceArgs(
                minimumDepositTokenAmountOut,
                depositToken,
                investmentToken
            ),
            investableDescs,
            depositParams,
            withdrawParams
        );
        emit Rebalance();
    }

    function getAssetBalances()
        external
        view
        virtual
        override
        returns (Balance[] memory)
    {
        return PortfolioBaseAumLib.getAssetBalances(investableDescs);
    }

    function getLiabilityBalances()
        external
        view
        virtual
        override
        returns (Balance[] memory liabilityBalances)
    {}

    function getAssetValuations(bool shouldMaximise, bool shouldIncludeAmmPrice)
        public
        view
        virtual
        override
        returns (Valuation[] memory)
    {
        return
            PortfolioBaseAumLib.getAssetValuations(
                shouldMaximise,
                shouldIncludeAmmPrice,
                investableDescs
            );
    }

    function getLiabilityValuations(
        bool, /*shouldMaximise*/
        bool /*shouldIncludeAmmPrice*/
    )
        public
        view
        virtual
        override
        returns (Valuation[] memory liabilityValuations)
    {}

    function getEquityValuation(bool shouldMaximise, bool shouldIncludeAmmPrice)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return
            PortfolioBaseAumLib.getEquityValuation(
                shouldMaximise,
                shouldIncludeAmmPrice,
                investableDescs
            );
    }

    function getTotalDepositFee(NameValuePair[] calldata params)
        external
        view
        virtual
        override
        returns (uint24)
    {
        return
            PortfolioBaseFeeLib.calculateEmbeddedFeeTargetAllocation(
                PortfolioBaseFeeLib.FeeType.Deposit,
                params,
                investableDescs
            ) + getDepositFee(params);
    }

    function getTotalWithdrawalFee(NameValuePair[] calldata params)
        external
        view
        virtual
        override
        returns (uint24)
    {
        return
            PortfolioBaseFeeLib.calculateEmbeddedFeeActualAllocation(
                PortfolioBaseFeeLib.FeeType.Withdrawal,
                params,
                investableDescs
            ) + getWithdrawalFee(params);
    }

    function getTotalPerformanceFee(NameValuePair[] calldata params)
        external
        view
        virtual
        override
        returns (uint24)
    {
        return
            PortfolioBaseFeeLib.calculateEmbeddedFeeActualAllocation(
                PortfolioBaseFeeLib.FeeType.Performance,
                params,
                investableDescs
            ) + getPerformanceFee(params);
    }

    function getTotalManagementFee(NameValuePair[] calldata params)
        external
        view
        virtual
        override
        returns (uint24)
    {
        return
            PortfolioBaseFeeLib.calculateEmbeddedFeeActualAllocation(
                PortfolioBaseFeeLib.FeeType.Management,
                params,
                investableDescs
            ) + getManagementFee(params);
    }

    function getDepositToken()
        external
        view
        virtual
        override
        returns (IERC20Upgradeable)
    {
        return depositToken;
    }

    function _setInvestmentToken(IInvestmentToken investmentToken_)
        internal
        virtual
    {
        investmentToken = investmentToken_;
    }

    function getInvestmentToken()
        external
        view
        virtual
        override
        returns (IInvestmentToken)
    {
        return investmentToken;
    }

    function getInvestmentTokenSupply()
        public
        view
        virtual
        override
        returns (uint256)
    {
        return investmentToken.totalSupply();
    }

    function getInvestmentTokenBalanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return investmentToken.balanceOf(account);
    }

    function claimFee(NameValuePair[] calldata params)
        public
        virtual
        override
        nonReentrant
    {}

    function getInvestables() external view returns (InvestableDesc[] memory) {
        return investableDescs;
    }
}
