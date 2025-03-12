// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./FreeMoneyProvider.sol";
import "../bases/strategy/StrategyOwnablePausableBaseUpgradeable.sol";
import "../InvestmentToken.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MockStrategy is
    UUPSUpgradeable,
    StrategyOwnablePausableBaseUpgradeable
{
    // solhint-disable-next-line const-name-snakecase
    string public constant trackingName =
        "brokkr.mock_strategy.<insert git label here>";
    // solhint-disable-next-line const-name-snakecase
    string public constant humanReadableName = "Mock strategy";
    // solhint-disable-next-line const-name-snakecase
    string public constant version = "1.0.0";

    using SafeERC20Upgradeable for IInvestmentToken;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    FreeMoneyProvider public freeMoneyProvider;
    uint256 public balance;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(StrategyArgs calldata strategyArgs)
        external
        initializer
    {
        __StrategyOwnablePausableBaseUpgradeable_init(strategyArgs);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _deposit(uint256 amount, NameValuePair[] calldata)
        internal
        virtual
        override
    {
        balance += amount;

        // incoming deposit token needs to be sent away, otherwise it would be
        // counted towards the equity
        depositToken.transfer(address(freeMoneyProvider), amount);
    }

    function takePerformanceFee(NameValuePair[] calldata params)
        public
        virtual
        override
    {
        uint256 accumulatedFeeBefore = currentAccumulatedFee;

        // initiate withdrawal
        super.takePerformanceFee(params);

        // calculating withdrawal fee
        uint256 performanceFee = currentAccumulatedFee - accumulatedFeeBefore;

        // adjusting the balance of the strategy
        balance -= performanceFee;
    }

    function takeManagementFee(NameValuePair[] calldata params)
        public
        virtual
        override
    {
        uint256 accumulatedFeeBefore = currentAccumulatedFee;

        // initiate withdrawal
        super.takeManagementFee(params);

        // calculating withdrawal fee
        uint256 performanceFee = currentAccumulatedFee - accumulatedFeeBefore;

        // adjusting the balance of the strategy
        balance -= performanceFee;
    }

    function withdraw(
        uint256 investmentTokenAmountIn,
        uint256 minimumDepositTokenAmountOut,
        address depositTokenReceiver,
        NameValuePair[] calldata params
    ) public virtual override {
        // calculating the amount of deposit tokens the receiver should get, without the withdrawal fee
        uint256 withdrawAmountInDepositToken = (balance *
            investmentTokenAmountIn) / getInvestmentTokenSupply();

        // making sure the contract holds enough deposit token
        freeMoneyProvider.giveMeMoney(
            withdrawAmountInDepositToken,
            depositToken
        );

        // initiate withdrawal
        super.withdraw(
            investmentTokenAmountIn,
            minimumDepositTokenAmountOut,
            depositTokenReceiver,
            params
        );

        // adjusting the balance of the strategy
        balance = balance - withdrawAmountInDepositToken;
    }

    function _beforeWithdraw(
        uint256, /*amount*/
        NameValuePair[] calldata /*params*/
    ) internal virtual override returns (uint256) {
        return 0;
    }

    function _withdraw(
        uint256 amount,
        NameValuePair[] calldata /*params*/
    ) internal virtual override {}

    function _afterWithdraw(
        uint256 amount,
        NameValuePair[] calldata /*params*/
    ) internal virtual override returns (uint256) {
        return (amount * balance) / getInvestmentTokenSupply();
    }

    function _reapReward(
        NameValuePair[] calldata /*params*/
    ) internal virtual override {
        freeMoneyProvider.giveMeMoney(10**6, depositToken);
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

    function getEquityValuation(bool, bool)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return balance;
    }

    function setFreeMoneyProvider(FreeMoneyProvider freeMoneyProvider_)
        external
    {
        freeMoneyProvider = freeMoneyProvider_;
    }

    function changeBalanceByPercentage(uint256 balanceMultiplier) external {
        balance =
            (balance * balanceMultiplier) /
            Math.SHORT_FIXED_DECIMAL_FACTOR /
            100;
    }

    function increaseBalanceByAmount(uint256 balanceIncrease) external {
        balance += balanceIncrease;
    }

    function decreaseBalanceByAmount(uint256 balanceDecrease) external {
        balance -= balanceDecrease;
    }
}
