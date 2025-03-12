// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DnsVectorStrategyAumLib.sol";
import "./DnsVectorStrategyCommon.sol";
import "./DnsVectorStrategyInvestmentLib.sol";
import "./DnsVectorStrategyStorageLib.sol";
import "../../bases/strategy/StrategyRoleablePausableBaseUpgradeable.sol";
import "../../InvestmentToken.sol";
import "../../interfaces/IPriceOracle.sol";
import "../../libraries/SwapServiceLib.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract DnsVectorStrategy is
    UUPSUpgradeable,
    StrategyRoleablePausableBaseUpgradeable
{
    using SafeERC20Upgradeable for IInvestmentToken;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    error SafetyFactorRangeError();
    error TooLowMinimumEquityAfterOperation();
    error InvalidPangolinParams();
    error TooBigValuationLoss();

    // solhint-disable-next-line const-name-snakecase
    string public constant trackingName =
        "brokkr.dns_vector_strategy.dns_vector_strategy_v1.1.1";
    // solhint-disable-next-line const-name-snakecase
    string public constant humanReadableName =
        "Dns vector delta neutral strategy";
    // solhint-disable-next-line const-name-snakecase
    string public constant version = "1.1.1";

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    struct AaveParams {
        uint256 safetyFactor;
        IERC20Upgradeable aaveSupplyToken;
        IERC20Upgradeable aAaveSupplyToken;
        ERC20Upgradeable aaveBorrowToken;
        IERC20Upgradeable vAaveBorrowToken;
        IPool aavePool;
        AaveProtocolDataProvider aaveProtocolDataProvider;
    }

    struct PangolinParams {
        IERC20Upgradeable pngToken;
        IPangolinRouter pangolinRouter;
        IPangolinMiniChef pangolinMiniChef;
        IPangolinPair pangolinPair;
        uint256 pangolinPoolId;
    }

    struct InitializeParams {
        AaveParams aaveParams;
        IERC20Upgradeable ammPairDepositToken;
        PangolinParams pangolinParams;
    }

    struct ReinitializeParams {
        PangolinParams pangolinParams;
        uint256 minValuation;
    }

    function initialize(
        StrategyArgs calldata strategyArgs,
        InitializeParams calldata initializeParams
    ) external initializer {
        __UUPSUpgradeable_init();
        __StrategyRoleablePausableBaseUpgradeable_init(strategyArgs);

        require(
            initializeParams.aaveParams.aaveSupplyToken ==
                InvestableLib.AVALANCHE_USDC,
            "aaveSupplyToken != USDC"
        );
        require(
            initializeParams.aaveParams.aaveBorrowToken ==
                InvestableLib.AVALANCHE_WAVAX,
            "aaveBorrowToken!= WAVAX"
        );
        require(
            initializeParams.ammPairDepositToken ==
                InvestableLib.AVALANCHE_USDC,
            "ammPairDepositToken != USDC"
        );

        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        __initializeAaveParams(initializeParams.aaveParams);

        strategyStorage.ammPairDepositToken = initializeParams
            .ammPairDepositToken;

        __initializePangolinParams(initializeParams.pangolinParams);

        strategyStorage.depositToken = strategyArgs.depositToken;
        strategyStorage.priceOracle = strategyArgs.priceOracle;
        strategyStorage.swapService = SwapService(
            strategyArgs.swapServiceProvider,
            strategyArgs.swapServiceRouter
        );
    }

    function _deposit(uint256 amount, NameValuePair[] calldata params)
        internal
        virtual
        override
    {
        DnsVectorStrategyInvestmentLib.deposit(amount, params);
    }

    function _withdraw(uint256 amount, NameValuePair[] calldata params)
        internal
        virtual
        override
    {
        DnsVectorStrategyInvestmentLib.withdraw(
            amount,
            params,
            getInvestmentTokenSupply()
        );
    }

    function _reapReward(NameValuePair[] calldata params)
        internal
        virtual
        override
    {
        DnsVectorStrategyInvestmentLib.reapReward(params);
    }

    modifier checkMinimumEquityAfterOperation(
        uint256 minimumEquityAfterOperation
    ) {
        _;
        if (getEquityValuation(false, false) < minimumEquityAfterOperation)
            revert TooLowMinimumEquityAfterOperation();
    }

    function repayDebt(
        uint256 pangolinPairAmount,
        NameValuePair[] calldata params,
        uint256 minimumEquityAfterOperation
    )
        external
        onlyRole(MAINTAINER_ROLE)
        checkMinimumEquityAfterOperation(minimumEquityAfterOperation)
    {
        DnsVectorStrategyInvestmentLib.repayDebt(pangolinPairAmount, params);
    }

    function increaseDebt(
        uint256 aaveBorrowTokenAmount,
        NameValuePair[] calldata params,
        uint256 minimumEquityAfterOperation
    )
        external
        onlyRole(MAINTAINER_ROLE)
        checkMinimumEquityAfterOperation(minimumEquityAfterOperation)
    {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        uint256 depositTokenBalanceBefore = depositToken.balanceOf(
            address(this)
        );

        DnsVectorStrategyInvestmentLib.increaseDebt(
            aaveBorrowTokenAmount,
            params
        );

        // handling dust amount caused by providing liquidity
        uninvestedDepositTokenAmount +=
            strategyStorage.depositToken.balanceOf(address(this)) -
            depositTokenBalanceBefore;
    }

    function decreaseSupply(
        uint256 aaveSupplyTokenAmount,
        NameValuePair[] calldata params,
        uint256 minimumEquityAfterOperation
    )
        external
        onlyRole(MAINTAINER_ROLE)
        checkMinimumEquityAfterOperation(minimumEquityAfterOperation)
    {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        uint256 depositTokenBalanceBefore = depositToken.balanceOf(
            address(this)
        );

        DnsVectorStrategyInvestmentLib.decreaseSupply(
            aaveSupplyTokenAmount,
            params
        );

        // handling dust amount caused by providing liquidity
        uninvestedDepositTokenAmount +=
            strategyStorage.depositToken.balanceOf(address(this)) -
            depositTokenBalanceBefore;
    }

    function _getAssetBalances()
        internal
        view
        virtual
        override
        returns (Balance[] memory)
    {
        return DnsVectorStrategyAumLib.getAssetBalances();
    }

    function _getLiabilityBalances()
        internal
        view
        virtual
        override
        returns (Balance[] memory)
    {
        return DnsVectorStrategyAumLib.getLiabilityBalances();
    }

    function _getAssetValuations(
        bool shouldMaximise,
        bool shouldIncludeAmmPrice
    ) internal view virtual override returns (Valuation[] memory) {
        return
            DnsVectorStrategyAumLib.getAssetValuations(
                shouldMaximise,
                shouldIncludeAmmPrice
            );
    }

    function _getLiabilityValuations(
        bool shouldMaximise,
        bool shouldIncludeAmmPrice
    ) internal view virtual override returns (Valuation[] memory) {
        return
            DnsVectorStrategyAumLib.getLiabilityValuations(
                shouldMaximise,
                shouldIncludeAmmPrice
            );
    }

    function getAaveDebt() external view returns (uint256) {
        return DnsVectorStrategyAumLib.getAaveDebt();
    }

    function getAaveSupply() external view returns (uint256) {
        return DnsVectorStrategyAumLib.getAaveSupply();
    }

    function getPoolDebt() external view returns (uint256) {
        return DnsVectorStrategyAumLib.getPoolDebt();
    }

    function getInverseCollateralRatio(
        bool shouldMaximise,
        bool shouldIncludeAmmPrice
    ) external view returns (uint256) {
        return
            DnsVectorStrategyAumLib.getInverseCollateralRatio(
                shouldMaximise,
                shouldIncludeAmmPrice
            );
    }

    // precision of 0.001, 800 means 0.8 -> 80%
    function getSafetyFactor() external view returns (uint256) {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();
        return strategyStorage.safetyFactor;
    }

    // precision of 0.001, 800 means 0.8 -> 80%
    function getCombinedSafetyFactor() external view returns (uint256) {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        (, , uint256 maxLoanToValueFactor, , , , , , , ) = strategyStorage
            .aaveProtocolDataProvider
            .getReserveConfigurationData(
                address(strategyStorage.aaveSupplyToken)
            );
        return
            (strategyStorage.safetyFactor * maxLoanToValueFactor) /
            DnsVectorStrategyCommon.AAVE_FIXED_DECIMAL_FACTOR;
    }

    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(UPGRADE_ROLE)
    {}

    function setSafetyFactor(uint256 safetyFactor)
        external
        onlyRole(STRATEGIST_ROLE)
    {
        if (safetyFactor > 950 || safetyFactor == 0)
            revert SafetyFactorRangeError();

        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        strategyStorage.safetyFactor = safetyFactor;
    }

    function setSwapService(SwapServiceProvider provider, address router)
        public
        virtual
        override
        onlyRole(GOVERNOR_ROLE)
    {
        super.setSwapService(provider, router);

        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        strategyStorage.swapService = SwapService(provider, router);
    }

    function setPriceOracle(IPriceOracle priceOracle)
        public
        virtual
        override
        onlyRole(GOVERNOR_ROLE)
    {
        super.setPriceOracle(priceOracle);

        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        strategyStorage.priceOracle = priceOracle;
    }

    // This function is added to help developers/integrators to obtain all data
    // stored in the strategy using a blockchain explorer.
    // This function should not be relied upon except during development.
    function getDnsVectorStorage()
        public
        pure
        returns (DnsVectorStorage memory)
    {
        return DnsVectorStorageLib.getStorage();
    }

    function __initializeAaveParams(AaveParams calldata aaveParams) private {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        strategyStorage.safetyFactor = aaveParams.safetyFactor;
        strategyStorage.aaveSupplyToken = aaveParams.aaveSupplyToken;
        strategyStorage.aAaveSupplyToken = aaveParams.aAaveSupplyToken;
        strategyStorage.aaveBorrowToken = aaveParams.aaveBorrowToken;
        strategyStorage.vAaveBorrowToken = aaveParams.vAaveBorrowToken;
        strategyStorage.aavePool = aaveParams.aavePool;
        strategyStorage.aaveProtocolDataProvider = aaveParams
            .aaveProtocolDataProvider;
    }

    function __initializePangolinParams(PangolinParams calldata pangolinParams)
        private
    {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        strategyStorage.pngToken = pangolinParams.pngToken;
        strategyStorage.pangolinRouter = pangolinParams.pangolinRouter;
        strategyStorage.pangolinMiniChef = pangolinParams.pangolinMiniChef;
        strategyStorage.pangolinPair = pangolinParams.pangolinPair;
        strategyStorage.pangolinPoolId = pangolinParams.pangolinPoolId;

        address pangolinLpToken = strategyStorage.pangolinMiniChef.lpToken(
            strategyStorage.pangolinPoolId
        );

        if (pangolinLpToken != address(strategyStorage.pangolinPair)) {
            revert InvalidPangolinParams();
        }
    }
}
