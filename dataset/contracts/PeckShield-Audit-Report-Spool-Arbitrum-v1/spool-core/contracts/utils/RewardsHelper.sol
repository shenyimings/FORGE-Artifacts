// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../external/@openzeppelin/token/ERC20/IERC20.sol";
import "../interfaces/ISwapData.sol";
import "../shared/BaseStorage.sol";
import "../shared/SwapHelper.sol";
import "../strategies/aave/AaveStrategy.sol";
import "../strategies/compound/CompoundStrategy.sol";
import "../external/interfaces/convex/IBaseRewardPool.sol";
import "../strategies/convex/ConvexSharedStrategy.sol";
import "../strategies/curve/Curve3poolStrategy.sol";
import "../strategies/harvest/HarvestStrategy.sol";
import "../strategies/idle/IdleStrategy.sol";

struct RewardData {
    IERC20 from;
    IERC20 to;
    uint256 amount;
    SwapData swapData;
    bool atRouter;
}

contract RewardsHelper is BaseStorage, SwapHelper {

    constructor()
        SwapHelper(ISwapRouter02(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) 
    {}

    // Helpers for getting rewards. results from here are passed to the Uniswap router to calculate the best path for selling in DHW.
    function claimRewardsAave(AaveStrategy strategy, address[] memory) external returns(RewardData[] memory rewardData){
        rewardData = new RewardData[](1);

        IAaveIncentivesController incentive = IAaveIncentivesController(strategy.incentive());
        address[] memory tokens = new address[](1);
        tokens[0] = address(strategy.aToken());
        uint256 pendingReward = incentive.getRewardsBalance(tokens, address(this));
        if (pendingReward > 0) {
            // we claim directly to uniswap router
            uint256 claimedAmount = incentive.claimRewards(
                tokens,
                pendingReward,
                address( uniswapRouter )
            );
            // we want to keep the amount for getting the swap path, but also need to tell the sellRewards function that 
            // the claimed amount is at the uniswap router.
            rewardData[0].atRouter = true;
            rewardData[0].amount = claimedAmount;
        }
        rewardData[0].from = IERC20( strategy.stkAave() );
        rewardData[0].to = IERC20( strategy.underlying() );
    }

    function claimRewardsCompound(CompoundStrategy strategy, address[] memory rewardToken) external returns(RewardData[] memory rewardData){
        rewardData = new RewardData[](1);

        ICompoundStrategyContractHelper strategyHelper = ICompoundStrategyContractHelper(strategy.strategyHelper());
        uint256 rewardAmount = strategyHelper.claimRewards(true);

        // add already claimed rewards
        rewardAmount += strategies[address(strategy)].pendingRewards[rewardToken[0]];

        RewardData memory _rewardData;
        _rewardData.from = IERC20( rewardToken[0] );
        _rewardData.to = IERC20( strategy.underlying() );
        _rewardData.amount = rewardAmount;
        rewardData[0] = _rewardData;
    }

    function claimRewardsConvex(ConvexSharedStrategy strategy, address[] memory) external returns(RewardData[] memory rewardData){
        IBaseRewardPool crvRewards = IBaseRewardPool(strategy.crvRewards());
        uint256 BASE_REWARDS_COUNT = 2; 
        uint256 extraRewardCount = crvRewards.extraRewardsLength();
        address[] memory rewardTokens = new address[](extraRewardCount + BASE_REWARDS_COUNT);
        rewardTokens[0] = address(strategy.rewardToken());
        rewardTokens[1] = address(strategy.cvxToken());
        for (uint256 i = 0; i < extraRewardCount; i++) {
            rewardTokens[i + BASE_REWARDS_COUNT] = address(IBaseRewardPool(crvRewards.extraRewards(i)).rewardToken());
        }
        rewardData = new RewardData[](rewardTokens.length);

        bytes32 sharedKey = keccak256(abi.encodePacked(address(strategy.booster()), strategy.pid()));
        if (strategiesShared[sharedKey].lastClaimBlock < block.number) {

            IStrategyContractHelper boosterHelper = IStrategyContractHelper(strategy.boosterHelper());
            (
                uint256[] memory rewardTokenAmounts,
                bool didClaimNewRewards
            ) = boosterHelper.claimRewards(rewardTokens, true);

            if (didClaimNewRewards) {
                _spreadRewardsToSharedStrats(rewardTokens, rewardTokenAmounts, sharedKey);
            }
            
            strategiesShared[sharedKey].lastClaimBlock = uint32(block.number);
        }
        
        for(uint i=0; i<rewardTokens.length; i++) {
            RewardData memory _rewardData;
            _rewardData.from = IERC20(rewardTokens[i]);
            _rewardData.to = IERC20( strategy.underlying() );
            _rewardData.amount = strategies[address(strategy)].pendingRewards[address(rewardTokens[i])];
            rewardData[i] = _rewardData;
        }
    }

    function claimRewardsCurve(Curve3poolStrategy strategy, address[] memory rewardToken) external returns(RewardData[] memory rewardData){
        rewardData = new RewardData[](1);

        address liquidityGauge = address( strategy.liquidityGauge() );
        bytes32 sharedKey = keccak256(abi.encodePacked(address(strategy.pool()), liquidityGauge ));
        if (strategiesShared[sharedKey].lastClaimBlock < block.number) {
            // claim
            uint256 rewardBefore = IERC20(rewardToken[0]).balanceOf(address(this));
            IMinter(strategy.minter()).mint(liquidityGauge);
            uint256 _rewardAmount = IERC20(rewardToken[0]).balanceOf(address(this)) - rewardBefore;

            if (_rewardAmount > 0) {
                uint256[] memory rewardAmount = new uint[](1);
                rewardAmount[0] = _rewardAmount;
                _spreadRewardsToSharedStrats(rewardToken, rewardAmount, sharedKey);
            }

            strategiesShared[sharedKey].lastClaimBlock = uint32(block.number);
        }

        RewardData memory _rewardData;
        _rewardData.from = IERC20(rewardToken[0]);
        _rewardData.to = IERC20( strategy.underlying() );
        _rewardData.amount = strategies[address(strategy)].pendingRewards[address(rewardToken[0])];
        rewardData[0] = _rewardData;
    }

    function claimRewardsHarvest(HarvestStrategy strategy, address[] memory) external returns(RewardData[] memory rewardData){}

    function claimRewardsIdle(IdleStrategy strategy, address[] memory) external returns(RewardData[] memory rewardData){
        IIdleToken idleToken = IIdleToken(strategy.idleToken());
        address[] memory rewardTokens = idleToken.getGovTokens();
        rewardData = new RewardData[](rewardTokens.length);
        uint256[] memory rewardTokenAmountsBefore = new uint[](rewardTokens.length);
        // get balances before
        for (uint256 i = 0; i < rewardTokenAmountsBefore.length; i++) {
            rewardTokenAmountsBefore[i] = IERC20(rewardTokens[i]).balanceOf(address(this));
        }
        
        // redeem, updates balances
        idleToken.redeemIdleToken(0);
        
        // get balances after, create reward data
        for (uint256 i = 0; i < rewardTokenAmountsBefore.length; i++) {
            RewardData memory _rewardData;
            _rewardData.from = IERC20(rewardTokens[i]);
            _rewardData.to = IERC20( strategy.underlying() );
            _rewardData.amount = IERC20(rewardTokens[i]).balanceOf(address(this)) - rewardTokenAmountsBefore[i];
            _rewardData.amount += strategies[address(strategy)].pendingRewards[rewardTokens[i]];
            rewardData[i] = _rewardData;
        }
    }

    function claimRewardsYearn(address, address[] memory) external returns(RewardData[] memory rewardData){}

    function sellRewards(address _strategy, RewardData[] calldata rewardData) external returns(uint256[] memory pendingDeposits) {
        Strategy storage strategy = strategies[_strategy];
        pendingDeposits = new uint256[](rewardData.length);
        for (uint256 i = 0; i < rewardData.length; i++) {
            // add compound amount from current batch to the fast withdraw
            if (rewardData[i].amount > 0) {
                uint256 amount = rewardData[i].atRouter ? type(uint256).max : rewardData[i].amount;
                uint128 compoundAmount = SafeCast.toUint128(
                    _approveAndSwap(
                        rewardData[i].from,
                        rewardData[i].to,
                        amount,
                        rewardData[i].swapData
                    )
                );

                // add to pending reward
                pendingDeposits[i] = compoundAmount;
                strategy.pendingDepositReward += compoundAmount;
            }
        }
    }

    // Internal functions to help with processing.
    function _spreadRewardsToSharedStrats(address[] memory rewardTokens, uint256[] memory rewardTokenAmounts, bytes32 sharedKey) private {

        StrategiesShared storage stratsShared = strategiesShared[sharedKey];

        uint256 sharedStratsCount = stratsShared.stratsCount;
        address[] memory stratAddresses = new address[](sharedStratsCount);
        uint256[] memory stratLpTokens = new uint256[](sharedStratsCount);

        uint256 totalLpTokens;
        for(uint256 i = 0; i < sharedStratsCount; i++) {
            stratAddresses[i] = stratsShared.stratAddresses[i];
            stratLpTokens[i] = strategies[stratAddresses[i]].lpTokens;
            totalLpTokens += stratLpTokens[i];
        }
        
        for(uint256 j = 0; j < sharedStratsCount; j++) {
            for(uint256 i = 0; i < rewardTokens.length; i++) {
                if (rewardTokenAmounts[i] > 0) {
                        strategies[stratAddresses[j]].pendingRewards[rewardTokens[i]] += 
                            (rewardTokenAmounts[i] * stratLpTokens[j]) / totalLpTokens;
                }
            }
        }
    }
}
