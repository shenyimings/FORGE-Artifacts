pragma solidity ^0.5.16;

import 'openzeppelin-solidity-2.3.0/contracts/token/ERC20/IERC20.sol';
import 'openzeppelin-solidity-2.3.0/contracts/ownership/Ownable.sol';
import 'openzeppelin-solidity-2.3.0/contracts/math/SafeMath.sol';

import './StakingRewards.sol';

contract StakingRewardsFactory is Ownable {
    using SafeMath for uint256;

    // the staking tokens for which the rewards contract has been deployed
    address[] public stakingTokens;

    // info about rewards for a particular staking token
    struct StakingRewardsInfo {
        address stakingRewards;
        uint256 rewardAmount;
        address rewardsToken;
        uint256 periodFinish;
        bool hidden;
    }

    // type of staking reward contract
    enum StakingType {
        POOL,
        FARM
    }

    // rewards info by staking token
    mapping(address => mapping(uint256 => StakingRewardsInfo)) public stakingRewardsInfoByStakingToken;

    // admins list
    mapping(address => bool) public admins;

    // rounds list
    mapping(address => uint256) public rounds;

    constructor() public Ownable() {
        admins[msg.sender] = true;
    }

    ///// permissioned functions

    // deploy a staking reward contract for the staking token, and store the reward amount
    // the reward will be distributed to the staking reward contract no sooner than the genesis
    function deploy(
        address stakingToken,
        uint256 rewardAmount,
        uint256 rewardsDuration,
        address rewardsToken,
        StakingType stakingType
    ) public onlyAdmins {
        require(rewardsDuration > 0, 'Rewards duration = 0');
        require(stakingToken != address(0), 'Staking token = ZERO address');
        require(rewardsToken != address(0), 'Rewards token = ZERO address');
        require(rewardAmount > 0, 'Insufficient amount');

        if (rounds[stakingToken] == 0) {
            rounds[stakingToken] = 1;
        } else {
            uint256 round = rounds[stakingToken];
            require(
                stakingRewardsInfoByStakingToken[stakingToken][round].periodFinish < block.timestamp,
                'deploy: already deployed and active'
            );
            rounds[stakingToken] += 1;
        }

        StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[stakingToken][rounds[stakingToken]];

        info.stakingRewards = address(
            new StakingRewards(
                /*_rewardsDistribution=*/
                address(this),
                rewardsToken,
                stakingToken,
                rewardsDuration,
                msg.sender
            )
        );
        info.rewardAmount = rewardAmount;
        info.rewardsToken = rewardsToken;
        info.periodFinish = block.timestamp.add(rewardsDuration);
        info.hidden = false;
        stakingTokens.push(stakingToken);

        require(
            IERC20(rewardsToken).transferFrom(msg.sender, info.stakingRewards, rewardAmount),
            'StakingRewardsFactory: transfer failed'
        );

        StakingRewards(info.stakingRewards).notifyRewardAmount(rewardAmount);

        emit Deployed(
            info.stakingRewards,
            stakingToken,
            rewardsToken,
            rewardAmount,
            rewardsDuration,
            rounds[stakingToken],
            stakingType
        );
    }

    function hide(address stakingToken) public onlyAdmins {
        StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[stakingToken][rounds[stakingToken]];

        if (info.hidden == false) {
            info.hidden = true;
        } else {
            info.hidden = false;
        }

        emit Hide(info.stakingRewards, info.hidden);
    }

    function addAdmin(address admin) public onlyOwner {
        require(admin != address(0), 'can not be a zero address');
        admins[admin] = true;

        emit AddAdmin(admin);
    }

    function removeAdmin(address admin) public onlyOwner {
        require(admin != address(0), 'can not be a zero address');
        admins[admin] = false;

        emit RemoveAdmin(admin);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyAdmins() {
        if (!admins[msg.sender]) revert('caller is not the admin');
        _;
    }

    /* ========== EVENTS ========== */

    event AddAdmin(address indexed admin);
    event RemoveAdmin(address indexed admin);
    event Deployed(
        address farm,
        address indexed stakingToken,
        address indexed rewardToken,
        uint256 rewardAmount,
        uint256 rewardsDuration,
        uint256 round,
        StakingType stakingType
    );
    event Hide(address indexed farm, bool hidden);
}
