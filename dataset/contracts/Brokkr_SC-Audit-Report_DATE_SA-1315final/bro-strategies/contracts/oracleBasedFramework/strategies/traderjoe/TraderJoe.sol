// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./TraderJoeInvestmentLib.sol";
import "./TraderJoeStorageLib.sol";
import "../../bases/strategy/StrategyOwnablePausableBaseUpgradeable.sol";
import "../../libraries/SwapServiceLib.sol";
import "../../../dependencies/traderjoe/ITraderJoeLBPair.sol";
import "../../../dependencies/traderjoe/ITraderJoeLBRouter.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TraderJoe is UUPSUpgradeable, StrategyOwnablePausableBaseUpgradeable {
    using SafeERC20Upgradeable for IInvestmentToken;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    error InvalidAllocations();
    error InvalidBinId();
    error InvalidBinsAmount();
    error InvalidBinsAndAllocations();
    error InvalidTraderJoeLBPair();
    error TooBigValuationLoss();

    // solhint-disable-next-line const-name-snakecase
    string public constant trackingName =
        "brokkr.traderjoe_strategy.traderjoe_strategy_v1.2.1";
    // solhint-disable-next-line const-name-snakecase
    string public constant humanReadableName = "TraderJoe Strategy";
    // solhint-disable-next-line const-name-snakecase
    string public constant version = "1.2.1";

    struct TraderJoeArgs {
        ITraderJoeLBPair lbPair;
        ITraderJoeLBRouter lbRouter;
        uint256 binStep;
        uint256[] binIds;
        uint256[] binAllocations;
        uint256 minValuation;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        StrategyArgs calldata strategyArgs,
        TraderJoeArgs calldata traderJoeArgs
    ) external initializer {
        __checkBinIdsAndAllocations(
            traderJoeArgs.binIds,
            traderJoeArgs.binAllocations
        );

        __UUPSUpgradeable_init();
        __StrategyOwnablePausableBaseUpgradeable_init(strategyArgs);

        __initialize(
            traderJoeArgs,
            SwapService(
                strategyArgs.swapServiceProvider,
                strategyArgs.swapServiceRouter
            )
        );
    }

    function reinitialize(TraderJoeArgs calldata traderJoeArgs)
        external
        reinitializer(2)
    {
        __checkBinIdsAndAllocations(
            traderJoeArgs.binIds,
            traderJoeArgs.binAllocations
        );

        TraderJoeStorage storage strategyStorage = TraderJoeStorageLib
            .getStorage();

        // Initialization.
        __initialize(
            traderJoeArgs,
            SwapService(
                SwapServiceProvider.TraderJoeV2,
                address(traderJoeArgs.lbRouter)
            )
        );

        // Migration from V1 to V2 consists of three steps.
        // 0. Withdraw all depositToken and pairDepositToken from V1.
        // 1. Deposit all withdrawn depositToken and pairDepositToken into V2.
        // 2. Check if valuation after migration is greater than or equal to minValuation.

        // 0. Withdraw all depositToken and pairDepositToken from V1.
        uint256 depositTokenBefore = depositToken.balanceOf(address(this));
        uint256 pairDepositTokenBefore = strategyStorage
            .pairDepositToken
            .balanceOf(address(this));

        uint256 lpBalanceToWithdraw = strategyStorage
            .masterChef
            .userInfo(strategyStorage.farmId, address(this))
            .amount;

        strategyStorage.masterChef.withdraw(
            strategyStorage.farmId,
            lpBalanceToWithdraw
        );

        strategyStorage.lpToken.approve(
            address(strategyStorage.router),
            lpBalanceToWithdraw
        );

        strategyStorage.router.removeLiquidity(
            address(strategyStorage.pairDepositToken),
            address(depositToken),
            lpBalanceToWithdraw,
            0,
            0,
            address(this),
            // solhint-disable-next-line not-rely-on-time
            block.timestamp
        );

        uint256 depositTokenAfter = depositToken.balanceOf(address(this));
        uint256 pairDepositTokenAfter = strategyStorage
            .pairDepositToken
            .balanceOf(address(this));

        // 1. Deposit all withdrawn depositToken and pairDepositToken into V2.
        uint256 depositTokenIncrement = depositTokenAfter - depositTokenBefore;
        uint256 pairDepositTokenIncrement = pairDepositTokenAfter -
            pairDepositTokenBefore;

        TraderJoeInvestmentLib.deposit(
            depositTokenIncrement,
            pairDepositTokenIncrement
        );

        // 2. Check if valuation after migration is greater than or equal to minValuation.
        uint256 valuation = getEquityValuation(true, false);

        if (valuation < traderJoeArgs.minValuation) {
            revert TooBigValuationLoss();
        }
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _deposit(uint256 amount, NameValuePair[] calldata)
        internal
        virtual
        override
    {
        TraderJoeInvestmentLib.deposit(amount, 0);
    }

    function _withdraw(uint256 amount, NameValuePair[] calldata)
        internal
        virtual
        override
    {
        TraderJoeStorage storage strategyStorage = TraderJoeStorageLib
            .getStorage();

        // Withdraw.
        uint256 pairdepositTokenBefore = strategyStorage
            .pairDepositToken
            .balanceOf(address(this));

        TraderJoeInvestmentLib.withdraw(amount, getInvestmentTokenSupply());

        uint256 pairDepositTokenAfter = strategyStorage
            .pairDepositToken
            .balanceOf(address(this));

        // Swap withdrawn pairDepositToken to depositToken.
        uint256 pairDepositTokenIncrement = pairDepositTokenAfter -
            pairdepositTokenBefore;

        TraderJoeInvestmentLib.swapTokens(
            pairDepositTokenIncrement,
            strategyStorage.pairDepositToken,
            depositToken
        );
    }

    function _reapReward(NameValuePair[] calldata) internal virtual override {
        TraderJoeInvestmentLib.reapReward();
    }

    function _getAssetBalances()
        internal
        view
        virtual
        override
        returns (Balance[] memory assetBalances)
    {
        TraderJoeStorage storage strategyStorage = TraderJoeStorageLib
            .getStorage();

        uint256 binsAmount = strategyStorage.binIds.length;
        assetBalances = new Balance[](binsAmount);

        for (uint256 i; i < binsAmount; ++i) {
            uint256 balance = strategyStorage.lbPair.balanceOf(
                address(this),
                strategyStorage.binIds[i]
            );

            assetBalances[i] = Balance(
                address(strategyStorage.lbPair),
                balance
            );
        }
    }

    function _getLiabilityBalances()
        internal
        view
        virtual
        override
        returns (Balance[] memory)
    {}

    function _getAssetValuations(bool, bool)
        internal
        view
        virtual
        override
        returns (Valuation[] memory assetValuations)
    {
        TraderJoeStorage storage strategyStorage = TraderJoeStorageLib
            .getStorage();

        uint256 binsAmount = strategyStorage.binIds.length;
        assetValuations = new Valuation[](binsAmount);

        for (uint256 i; i < binsAmount; ++i) {
            uint256 lpTokenBalance = strategyStorage.lbPair.balanceOf(
                address(this),
                strategyStorage.binIds[i]
            );

            (uint256 reserveX, uint256 reserveY) = strategyStorage
                .lbPair
                .getBin(uint24(strategyStorage.binIds[i]));

            uint256 totalSupply = strategyStorage.lbPair.totalSupply(
                strategyStorage.binIds[i]
            );

            uint256 valuation;

            if (totalSupply != 0) {
                // Assume that token X and token Y have the same price.
                valuation =
                    (lpTokenBalance * (reserveX + reserveY)) /
                    totalSupply;
            }

            assetValuations[i] = Valuation(
                address(strategyStorage.lbPair),
                valuation
            );
        }
    }

    function _getLiabilityValuations(bool, bool)
        internal
        view
        virtual
        override
        returns (Valuation[] memory)
    {}

    function setSwapService(SwapServiceProvider provider, address router)
        public
        virtual
        override
        onlyOwner
    {
        super.setSwapService(provider, router);

        TraderJoeStorage storage strategyStorage = TraderJoeStorageLib
            .getStorage();

        strategyStorage.swapService = SwapService(provider, router);
    }

    function adjustBins(
        uint256[] calldata binIds,
        uint256[] calldata binAllocations
    ) public onlyOwner {
        __checkBinIdsAndAllocations(binIds, binAllocations);

        TraderJoeInvestmentLib.adjustBins(
            binIds,
            binAllocations,
            getInvestmentTokenSupply()
        );
    }

    function getBinIds() public view returns (uint256[] memory) {
        TraderJoeStorage storage strategyStorage = TraderJoeStorageLib
            .getStorage();

        return strategyStorage.binIds;
    }

    function getBinAllocations() public view returns (uint256[] memory) {
        TraderJoeStorage storage strategyStorage = TraderJoeStorageLib
            .getStorage();

        return strategyStorage.binAllocations;
    }

    function __checkBinIdsAndAllocations(
        uint256[] calldata binIds,
        uint256[] calldata binAllocations
    ) private pure {
        uint256 binsAmount = binIds.length;
        uint256 allocationsAmount = binAllocations.length;

        if (binsAmount != allocationsAmount) {
            revert InvalidBinsAndAllocations();
        }

        if (binsAmount < 1 || binsAmount > 51) {
            revert InvalidBinsAmount();
        }
        // No need to check the number of allocations.

        uint256 allocations;

        for (uint256 i; i < binsAmount; i++) {
            if (binIds[i] > type(uint24).max) {
                revert InvalidBinId();
            }

            if (binAllocations[i] == 0) {
                revert InvalidAllocations();
            }

            allocations += binAllocations[i];
        }

        if (allocations != 1e3) {
            revert InvalidAllocations();
        }
    }

    function __initialize(
        TraderJoeArgs calldata traderJoeArgs,
        SwapService memory swapService
    ) private {
        TraderJoeStorage storage strategyStorage = TraderJoeStorageLib
            .getStorage();

        strategyStorage.lbPair = traderJoeArgs.lbPair;
        strategyStorage.lbRouter = traderJoeArgs.lbRouter;
        strategyStorage.tokenX = IERC20Upgradeable(
            traderJoeArgs.lbPair.tokenX()
        );
        strategyStorage.tokenY = IERC20Upgradeable(
            traderJoeArgs.lbPair.tokenY()
        );
        strategyStorage.binStep = traderJoeArgs.binStep;
        strategyStorage.binIds = traderJoeArgs.binIds;
        strategyStorage.binAllocations = traderJoeArgs.binAllocations;
        setSwapService(swapService.provider, swapService.router);

        if (strategyStorage.tokenX == depositToken) {
            strategyStorage.depositToken = IERC20Upgradeable(
                strategyStorage.tokenX
            );
            strategyStorage.pairDepositToken = IERC20Upgradeable(
                strategyStorage.tokenY
            );
        } else if (strategyStorage.tokenY == depositToken) {
            strategyStorage.depositToken = IERC20Upgradeable(
                strategyStorage.tokenY
            );
            strategyStorage.pairDepositToken = IERC20Upgradeable(
                strategyStorage.tokenX
            );
        } else {
            revert InvalidTraderJoeLBPair();
        }
    }
}
