// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
pragma abicoder v2;

import "../../../interfaces/ILendBorrowFarmingPair.sol";
import "../../../interfaces/IStrategyContract.sol";
import "./VenusStatistics.sol";

contract VenusLbfStatistics is VenusStatistics {
    // Swap information
    address public pancakeSwapRouter;
    address public pancakeSwapMaster;
    address[] public pathToSwapCAKEToStableCoin;

    address public apeSwapRouter;
    address public apeSwapMaster;
    address[] public pathToSwapBANANAToStableCoin;

    address public biSwapRouter;
    address public biSwapMaster;
    address[] public pathToSwapBSWToStableCoin;

    /*** Public Set function ***/

    /**
     * @notice Set PancakeSwap information
     */
    function setPancakeSwapInfo(
        address _pancakeSwapRouter,
        address _pancakeSwapMaster,
        address[] calldata _pathToSwapCAKEToStableCoin
    ) external onlyOwnerAndAdmin {
        pancakeSwapRouter = _pancakeSwapRouter;
        pancakeSwapMaster = _pancakeSwapMaster;
        pathToSwapCAKEToStableCoin = _pathToSwapCAKEToStableCoin;
    }

    /**
     * @notice Set ApeSwap information
     */
    function setApeSwapInfo(
        address _apeSwapRouter,
        address _apeSwapMaster,
        address[] calldata _pathToSwapBANANAToStableCoin
    ) external onlyOwnerAndAdmin {
        apeSwapRouter = _apeSwapRouter;
        apeSwapMaster = _apeSwapMaster;
        pathToSwapBANANAToStableCoin = _pathToSwapBANANAToStableCoin;
    }

    /**
     * @notice Set BiSwap information
     */
    function setBiSwapInfo(
        address _biSwapRouter,
        address _biSwapMaster,
        address[] calldata _pathToSwapBSWToStableCoin
    ) external onlyOwnerAndAdmin {
        biSwapRouter = _biSwapRouter;
        biSwapMaster = _biSwapMaster;
        pathToSwapBSWToStableCoin = _pathToSwapBSWToStableCoin;
    }

    /*** Public override function ***/

    /**
     * @notice Get Strategy balance information
     * check all xTokens in market
     * @param logic Logic contract address
     */
    function getStrategyStatistics(address logic)
        public
        view
        override
        returns (StrategyStatistics memory statistics)
    {
        statistics = StatisticsBase.getStrategyStatistics(logic);
        uint256 stakedAmountTotalUSD;

        // Todo Get Farming Pair Statistics

        // Staked
        statistics.totalAmountUSD += int256(stakedAmountTotalUSD);
    }

    /**
     * @notice Get Wallet statistics
     * Tokens in Storage, CAKE, BANANA, BSW, BLID
     * @param logic Logic contract address
     * @param comptroller address of comptroller
     * @return walletStatistics Array of WalletInfo
     */
    function _getWalletStatistics(
        address logic,
        address comptroller,
        XTokenInfo[] memory arrTokenInfo
    ) internal view override returns (WalletInfo[] memory walletStatistics) {
        WalletInfo[] memory walletStatisticsBase = StatisticsBase
            ._getWalletStatistics(logic, comptroller, arrTokenInfo);

        uint256 countWalletBase = walletStatisticsBase.length;
        walletStatistics = new WalletInfo[](countWalletBase + 3);

        // Get wallet info from base
        for (uint256 index = 0; index < countWalletBase; ) {
            walletStatistics[index] = walletStatisticsBase[index];
            unchecked {
                ++index;
            }
        }

        // PancakeSwap - CAKE
        walletStatistics[countWalletBase] = _getFarmingRewardsInfo(
            logic,
            pancakeSwapRouter,
            pancakeSwapMaster,
            0,
            true
        );

        // ApeSwap - BANANA
        walletStatistics[countWalletBase + 1] = _getFarmingRewardsInfo(
            logic,
            apeSwapRouter,
            apeSwapMaster,
            0,
            true
        );

        // BiSwap - BSW
        walletStatistics[countWalletBase + 2] = _getFarmingRewardsInfo(
            logic,
            biSwapRouter,
            biSwapMaster,
            0,
            true
        );
    }

    /**
     * @notice Get information for Farming Rewards
     * @param logic logic address
     * @param swapRouter swap router address
     * @param swapMaster swap masterchef address
     * @param poolID poolId of pair
     * @param isBalance true : get rewards balance, false : get pending rewards
     * @return walletInfo WalletInfo
     */
    function _getFarmingRewardsInfo(
        address logic,
        address swapRouter,
        address swapMaster,
        uint256 poolID,
        bool isBalance
    ) private view returns (WalletInfo memory walletInfo) {
        address rewardsToken;
        uint256 rewardsAmount;
        uint256 rewardsAmountUSD;

        // PancakeSwap
        if (swapMaster == pancakeSwapMaster) {
            rewardsToken = IMasterChefPancakeswap(swapMaster).CAKE();

            if (isBalance) {
                rewardsAmount = IERC20Upgradeable(rewardsToken).balanceOf(
                    logic
                );
            } else {
                rewardsAmount = IMasterChefPancakeswap(swapMaster).pendingCake(
                    poolID,
                    logic
                );
            }

            rewardsAmountUSD = _getAmountUSDByOracle(
                rewardsToken,
                ISwapGateway(swapGateway).quoteExactInput(
                    swapRouter,
                    rewardsAmount,
                    pathToSwapCAKEToStableCoin
                )
            );
        }

        // ApeSwap
        if (swapMaster == apeSwapMaster) {
            rewardsToken = IMasterChefApeswap(swapMaster).cake();

            if (isBalance) {
                rewardsAmount = IERC20Upgradeable(rewardsToken).balanceOf(
                    logic
                );
            } else {
                rewardsAmount = IMasterChefApeswap(swapMaster).pendingCake(
                    poolID,
                    logic
                );
            }

            rewardsAmountUSD = _getAmountUSDByOracle(
                rewardsToken,
                ISwapGateway(swapGateway).quoteExactInput(
                    swapRouter,
                    rewardsAmount,
                    pathToSwapBANANAToStableCoin
                )
            );
        }

        // BiSwap
        if (swapMaster == biSwapMaster) {
            rewardsToken = IMasterChefBiswap(swapMaster).BSW();

            if (isBalance) {
                rewardsAmount = IERC20Upgradeable(rewardsToken).balanceOf(
                    logic
                );
            } else {
                rewardsAmount = IMasterChefBiswap(swapMaster).pendingBSW(
                    poolID,
                    logic
                );
            }

            rewardsAmountUSD = _getAmountUSDByOracle(
                rewardsToken,
                ISwapGateway(swapGateway).quoteExactInput(
                    swapRouter,
                    rewardsAmount,
                    pathToSwapBSWToStableCoin
                )
            );
        }

        walletInfo = WalletInfo(
            IERC20MetadataUpgradeable(rewardsToken).symbol(),
            rewardsToken,
            rewardsAmount,
            rewardsAmountUSD
        );
    }

    /*** Private function ***/

    /**
     * @notice Get Venus FarmingPair address from venus Logic via MultiLogicProxy
     * @param logic Address of venusLogic
     * @return farmingPair Address of Farmingpair
     */
    function _getFarmingPairAddress(address logic)
        private
        view
        returns (address farmingPair)
    {
        address _multiLogicProxy = ILogic(logic).multiLogicProxy();
        uint256 multiStrategyLength = IMultiLogicProxy(_multiLogicProxy)
            .multiStrategyLength();

        address strategy = address(0);

        for (uint256 i = 0; i < multiStrategyLength; ) {
            string memory multiStrategyName = IMultiLogicProxy(_multiLogicProxy)
                .multiStrategyName(i);

            (
                address logicContract,
                address strategyContract
            ) = IMultiLogicProxy(_multiLogicProxy).strategyInfo(
                    multiStrategyName
                );

            if (logicContract == logic) {
                strategy = strategyContract;
                break;
            }

            unchecked {
                ++i;
            }
        }

        require(strategy != address(0), "SH4");

        farmingPair = IStrategyVenus(strategy).farmingPair();
    }
}
