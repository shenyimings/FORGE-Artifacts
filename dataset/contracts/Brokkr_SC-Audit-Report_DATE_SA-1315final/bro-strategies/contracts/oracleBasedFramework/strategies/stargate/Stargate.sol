// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./StargateStorageLib.sol";
import "../../bases/strategy/StrategyOwnablePausableBaseUpgradeable.sol";
import "../../libraries/SwapServiceLib.sol";
import "../../../dependencies/stargate/IStargateLpStaking.sol";
import "../../../dependencies/stargate/IStargatePool.sol";
import "../../../dependencies/stargate/IStargateRouter.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Stargate is UUPSUpgradeable, StrategyOwnablePausableBaseUpgradeable {
    using SafeERC20Upgradeable for IInvestmentToken;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    error InvalidBinStep();
    error InvalidStargateLpToken();
    error NotEnoughDeltaCredit();

    // solhint-disable-next-line const-name-snakecase
    string public constant trackingName =
        "brokkr.stargate_strategy.stargate_strategy_v1.1.2";
    // solhint-disable-next-line const-name-snakecase
    string public constant humanReadableName = "Stargate Strategy";
    // solhint-disable-next-line const-name-snakecase
    string public constant version = "1.1.2";

    struct StargateArgs {
        address traderjoeLBRouter;
        uint256 binStep;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        StrategyArgs calldata strategyArgs,
        IStargateRouter router,
        IStargatePool pool,
        IStargateLpStaking lpStaking,
        IERC20Upgradeable lpToken,
        IERC20Upgradeable stgToken,
        StargateArgs calldata stargateArgs
    ) external initializer {
        __UUPSUpgradeable_init();
        __StrategyOwnablePausableBaseUpgradeable_init(strategyArgs);

        StargateStorage storage strategyStorage = StargateStorageLib
            .getStorage();

        strategyStorage.router = router;
        strategyStorage.pool = pool;
        strategyStorage.lpStaking = lpStaking;
        strategyStorage.lpToken = lpToken;
        strategyStorage.stgToken = stgToken;

        strategyStorage.poolDepositToken = IERC20Upgradeable(pool.token());
        strategyStorage.poolId = pool.poolId();

        IStargateLpStaking.PoolInfo memory poolInfo;
        uint256 poolLength = lpStaking.poolLength();
        bool isPoolFound = false;
        for (uint256 i = 0; i < poolLength; i++) {
            poolInfo = lpStaking.poolInfo(i);
            if (address(poolInfo.lpToken) == address(lpToken)) {
                strategyStorage.farmId = i;
                isPoolFound = true;
                break;
            }
        }

        if (!isPoolFound) {
            revert InvalidStargateLpToken();
        }

        __switchSwapService(stargateArgs);
    }

    function reinitialize(StargateArgs calldata stargateArgs)
        external
        reinitializer(3)
    {
        __switchSwapService(stargateArgs);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _deposit(uint256 amount, NameValuePair[] calldata)
        internal
        virtual
        override
    {
        StargateStorage storage strategyStorage = StargateStorageLib
            .getStorage();

        if (depositToken != strategyStorage.poolDepositToken) {
            amount = __swapTokens(
                amount,
                depositToken,
                strategyStorage.poolDepositToken
            );
        }

        uint256 lpBalanceBefore = strategyStorage.lpToken.balanceOf(
            address(this)
        );
        strategyStorage.poolDepositToken.approve(
            address(strategyStorage.router),
            amount
        );
        strategyStorage.router.addLiquidity(
            strategyStorage.poolId,
            amount,
            address(this)
        );
        uint256 lpBalanceAfter = strategyStorage.lpToken.balanceOf(
            address(this)
        );

        uint256 lpBalanceIncrement = lpBalanceAfter - lpBalanceBefore;

        strategyStorage.lpToken.approve(
            address(strategyStorage.lpStaking),
            lpBalanceIncrement
        );
        strategyStorage.lpStaking.deposit(
            strategyStorage.farmId,
            lpBalanceIncrement
        );
    }

    function _withdraw(uint256 amount, NameValuePair[] calldata)
        internal
        virtual
        override
    {
        StargateStorage storage strategyStorage = StargateStorageLib
            .getStorage();

        uint256 lpBalanceToWithdraw = (getStargateLpBalance() * amount) /
            getInvestmentTokenSupply();

        if (lpBalanceToWithdraw > strategyStorage.pool.deltaCredit()) {
            revert NotEnoughDeltaCredit();
        }

        uint256 poolDepositTokenBalanceBefore = strategyStorage
            .poolDepositToken
            .balanceOf(address(this));
        strategyStorage.lpStaking.withdraw(
            strategyStorage.farmId,
            lpBalanceToWithdraw
        );
        strategyStorage.router.instantRedeemLocal(
            uint16(strategyStorage.poolId),
            lpBalanceToWithdraw,
            address(this)
        );
        uint256 poolDepositTokenBalanceAfter = strategyStorage
            .poolDepositToken
            .balanceOf(address(this));

        if (depositToken != strategyStorage.poolDepositToken) {
            uint256 poolDepositTokenBalanceIncrement = poolDepositTokenBalanceAfter -
                    poolDepositTokenBalanceBefore;

            __swapTokens(
                poolDepositTokenBalanceIncrement,
                strategyStorage.poolDepositToken,
                depositToken
            );
        }
    }

    function _reapReward(NameValuePair[] calldata) internal virtual override {
        StargateStorage storage strategyStorage = StargateStorageLib
            .getStorage();

        strategyStorage.lpStaking.deposit(strategyStorage.farmId, 0);

        __swapTokens(
            strategyStorage.stgToken.balanceOf(address(this)),
            strategyStorage.stgToken,
            depositToken
        );
    }

    function _getAssetBalances()
        internal
        view
        virtual
        override
        returns (Balance[] memory assetBalances)
    {
        StargateStorage storage strategyStorage = StargateStorageLib
            .getStorage();

        assetBalances = new Balance[](1);
        assetBalances[0] = Balance(
            address(strategyStorage.lpToken),
            getStargateLpBalance()
        );
    }

    function _getLiabilityBalances()
        internal
        view
        virtual
        override
        returns (Balance[] memory liabilityBalances)
    {}

    function _getAssetValuations(
        bool shouldMaximise,
        bool shouldIncludeAmmPrice
    )
        internal
        view
        virtual
        override
        returns (Valuation[] memory assetValuations)
    {
        StargateStorage storage strategyStorage = StargateStorageLib
            .getStorage();

        assetValuations = new Valuation[](1);
        assetValuations[0] = Valuation(
            address(strategyStorage.lpToken),
            (getStargateLpBalance() * strategyStorage.pool.totalLiquidity()) /
                strategyStorage.pool.totalSupply()
        );

        if (depositToken != strategyStorage.poolDepositToken) {
            assetValuations[0].valuation =
                (assetValuations[0].valuation *
                    priceOracle.getPrice(
                        strategyStorage.poolDepositToken,
                        shouldMaximise,
                        shouldIncludeAmmPrice
                    )) /
                InvestableLib.PRICE_PRECISION_FACTOR;
        }
    }

    function _getLiabilityValuations(bool, bool)
        internal
        view
        virtual
        override
        returns (Valuation[] memory liabilityValuations)
    {}

    function getStargateLpBalance() public view returns (uint256) {
        StargateStorage storage strategyStorage = StargateStorageLib
            .getStorage();

        return
            strategyStorage
                .lpStaking
                .userInfo(strategyStorage.farmId, address(this))
                .amount;
    }

    function setBinStep(
        IERC20Upgradeable tokenX,
        IERC20Upgradeable tokenY,
        uint256 binStep
    ) public onlyOwner {
        StargateStorage storage strategyStorage = StargateStorageLib
            .getStorage();

        strategyStorage.binSteps[tokenX][tokenY] = binStep;
        strategyStorage.binSteps[tokenY][tokenX] = binStep;
    }

    function __swapTokens(
        uint256 amountIn,
        IERC20Upgradeable tokenIn,
        IERC20Upgradeable tokenOut
    ) private returns (uint256 amountOut) {
        StargateStorage storage strategyStorage = StargateStorageLib
            .getStorage();

        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        uint256[] memory binStep = new uint256[](1);
        binStep[0] = strategyStorage.binSteps[tokenIn][tokenOut];

        SwapService memory _swapService;

        // We switched to TraderJoe V2 for swapping since Stargate USDT v1.1.2,
        // but $STG is not supported at the moment.
        // The `binStep[0] == 0` condition will enable us to use TraderJoe V2
        // for swapping $STG once it is supported without requiring an upgrade.
        if (tokenIn == strategyStorage.stgToken && binStep[0] == 0) {
            _swapService = strategyStorage.swapServiceForStgToken;
        } else {
            _swapService = swapService;
        }

        amountOut = SwapServiceLib.swapExactTokensForTokens(
            _swapService,
            amountIn,
            0,
            path,
            binStep
        );
    }

    function __switchSwapService(StargateArgs calldata stargateArgs) private {
        StargateStorage storage strategyStorage = StargateStorageLib
            .getStorage();

        // $STG token is not supported by TraderJoe V2 yet.
        strategyStorage.swapServiceForStgToken = swapService;

        setSwapService(
            SwapServiceProvider.TraderJoeV2,
            stargateArgs.traderjoeLBRouter
        );

        setBinStep(
            depositToken,
            strategyStorage.poolDepositToken,
            stargateArgs.binStep
        );
    }
}
