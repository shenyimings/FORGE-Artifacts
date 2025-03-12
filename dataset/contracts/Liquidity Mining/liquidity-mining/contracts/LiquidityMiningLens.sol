// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./LiquidityMining.sol";

/**
 * @notice LiquidityMiningLens
 * This contract is mostly used by front-end to get LM contract information.
 */
contract LiquidityMiningLens {
    LiquidityMining public liquidityMining;

    constructor(LiquidityMining _liquidityMining) {
        liquidityMining = _liquidityMining;
    }

    struct RewardTokenInfo {
        address rewardTokenAddress;
        string rewardTokenSymbol;
        uint8 rewardTokenDecimals;
    }

    struct RewardAvailable {
        RewardTokenInfo rewardToken;
        uint amount;
    }

    /**
     * @notice Get user all available rewards.
     * @dev This function is normally used by staticcall.
     * @param account The user address
     * @return The list of user available rewards
     */
    function getRewardsAvailable(address account) public returns (RewardAvailable[] memory) {
        address[] memory rewardTokens = liquidityMining.getRewardTokenList();
        uint[] memory beforeBalances = new uint[](rewardTokens.length);
        RewardAvailable[] memory rewardAvailables = new RewardAvailable[](rewardTokens.length);

        for (uint i = 0; i < rewardTokens.length; i++) {
            beforeBalances[i] = IERC20Metadata(rewardTokens[i]).balanceOf(account);
        }

        liquidityMining.claimAllRewards(account);

        for (uint i = 0; i < rewardTokens.length; i++) {
            uint newBalance = IERC20Metadata(rewardTokens[i]).balanceOf(account);
            rewardAvailables[i] = RewardAvailable({
                rewardToken: getRewardTokenInfo(rewardTokens[i]),
                amount: newBalance - beforeBalances[i]
            });
        }
        return rewardAvailables;
    }

    /**
     * @notice Get reward token info.
     * @param rewardToken The reward token address
     * @return The reward token info
     */
    function getRewardTokenInfo(address rewardToken) public view returns (RewardTokenInfo memory) {
        if (rewardToken == liquidityMining.ethAddress()) {
            string memory rewardTokenSymbol = "ETH";
            if (block.chainid == 56) {
                rewardTokenSymbol = "BNB"; // bsc
            } else if (block.chainid == 137) {
                rewardTokenSymbol = "MATIC"; // polygon
            } else if (block.chainid == 250) {
                rewardTokenSymbol = "FTM"; // fantom
            }
            return RewardTokenInfo({
                rewardTokenAddress: liquidityMining.ethAddress(),
                rewardTokenSymbol: rewardTokenSymbol,
                rewardTokenDecimals: uint8(18)
            });
        } else {
            return RewardTokenInfo({
                rewardTokenAddress: rewardToken,
                rewardTokenSymbol: IERC20Metadata(rewardToken).symbol(),
                rewardTokenDecimals: IERC20Metadata(rewardToken).decimals()
            });
        }
    }

    struct RewardSpeed {
        uint speed;
        uint start;
        uint end;
    }

    struct RewardSpeedInfo {
        RewardTokenInfo rewardToken;
        RewardSpeed supplySpeed;
        RewardSpeed borrowSpeed;
    }

    struct MarketRewardSpeed {
        address cToken;
        RewardSpeedInfo[] rewardSpeeds;
    }

    /**
     * @notice Get reward speed info by market.
     * @param cToken The market address
     * @return The market reward speed info
     */
    function getMarketRewardSpeeds(address cToken) public view returns (MarketRewardSpeed memory) {
        address[] memory rewardTokens = liquidityMining.getRewardTokenList();
        RewardSpeedInfo[] memory rewardSpeeds = new RewardSpeedInfo[](rewardTokens.length);
        for (uint i = 0; i < rewardTokens.length; i++) {
            (uint supplySpeed, uint supplyStart, uint supplyEnd) = liquidityMining.rewardSupplySpeeds(rewardTokens[i], cToken);
            (uint borrowSpeed, uint borrowStart, uint borrowEnd) = liquidityMining.rewardBorrowSpeeds(rewardTokens[i], cToken);
            rewardSpeeds[i] = RewardSpeedInfo({
                rewardToken: getRewardTokenInfo(rewardTokens[i]),
                supplySpeed: RewardSpeed({
                    speed: supplySpeed,
                    start: supplyStart,
                    end: supplyEnd
                }),
                borrowSpeed: RewardSpeed({
                    speed: borrowSpeed,
                    start: borrowStart,
                    end: borrowEnd
                })
            });
        }
        return MarketRewardSpeed({
            cToken: cToken,
            rewardSpeeds: rewardSpeeds
        });
    }

    /**
     * @notice Get all market reward speed info.
     * @param cTokens The market addresses
     * @return The list of reward speed info
     */
    function getAllMarketRewardSpeeds(address[] memory cTokens) public view returns (MarketRewardSpeed[] memory) {
        MarketRewardSpeed[] memory allRewardSpeeds = new MarketRewardSpeed[](cTokens.length);
        for (uint i = 0; i < cTokens.length; i++) {
            allRewardSpeeds[i] = getMarketRewardSpeeds(cTokens[i]);
        }
        return allRewardSpeeds;
    }
}
