// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./StakingRewardsLock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interface/ISatellitePool.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interface/IStakingRewardsFactory.sol";

contract StakingRewardsLockFactory is Ownable{
    using SafeMath for uint256;

    // immutables
    address public rewardsToken;
    uint256 public stakingRewardsGenesis;

    // the staking tokens for which the rewards contract has been deployed
    address[] public stakingTokens;

    // info about rewards for a particular staking token
    struct StakingRewardsInfo {
        address stakingRewards;
        // uint rewardAmount;
    }

    // rewards info by staking token
    mapping(address => StakingRewardsInfo)
        public stakingRewardsInfoByStakingToken;

    constructor(address _rewardsToken, uint256 _stakingRewardsGenesis)
        public
        Ownable()
    {
        require(
            _stakingRewardsGenesis >= block.timestamp,
            "StakingRewardsFactory::constructor: genesis too soon"
        );

        rewardsToken = _rewardsToken;
        stakingRewardsGenesis = _stakingRewardsGenesis;
    }

   

    ///// permissioned functions

    // deploy a staking reward contract for the staking token, and store the reward amount
    // the reward will be distributed to the staking reward contract no sooner than the genesis
    function deploy(address stakingToken, uint _lockDuration, uint _unlockPercent, uint _lockPercent) public onlyOwner {

            StakingRewardsInfo storage info
         = stakingRewardsInfoByStakingToken[stakingToken];
        require(
            info.stakingRewards == address(0),
            "StakingRewardsFactory::deploy: already deployed"
        );

        info.stakingRewards = address(
            new StakingRewardsLock(
                /*_rewardsDistribution=*/
                address(this),
                rewardsToken,
                stakingToken,
                _lockDuration,
                _unlockPercent,
                _lockPercent
            )
        );
        stakingTokens.push(stakingToken);

        // info.rewardAmount = rewardAmount;
    }

    ///// permissionless functions

    // call notifyRewardAmount for all staking tokens.
    // function notifyRewardAmounts() public {
    //     require(stakingTokens.length > 0, 'StakingRewardsFactory::notifyRewardAmounts: called before any deploys');
    //     for (uint i = 0; i < stakingTokens.length; i++) {
    //         notifyRewardAmount(stakingTokens[i]);
    //     }
    // }

    // notify reward amount for an individual staking token.
    // this is a fallback in case the notifyRewardAmounts costs too much gas to call for all contracts
    function notifyRewardAmount(
        address stakingToken,
        uint256 duration,
        uint256 rewardAmount
    ) public onlyOwner {
        require(
            block.timestamp >= stakingRewardsGenesis,
            "StakingRewardsFactory::notifyRewardAmount: not ready"
        );


            StakingRewardsInfo storage info
         = stakingRewardsInfoByStakingToken[stakingToken];
        require(
            info.stakingRewards != address(0),
            "StakingRewardsFactory::notifyRewardAmount: not deployed"
        );

        require(
            IERC20(rewardsToken).transfer(info.stakingRewards, rewardAmount),
            "StakingRewardsFactory::notifyRewardAmount: transfer failed"
        );
        StakingRewardsLock(info.stakingRewards).notifyRewardAmount(
            rewardAmount,
            duration
        );
    }
}
