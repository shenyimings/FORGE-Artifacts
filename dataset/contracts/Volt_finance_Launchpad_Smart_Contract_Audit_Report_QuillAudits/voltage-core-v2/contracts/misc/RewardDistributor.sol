// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RewardDistributor is ReentrancyGuard {
    struct Reward {
        uint256 id;
        string title;
        string description;
        address token;
        uint256 amount;
        bool isActive;
        bool isVariableReward;
        bool isNative;
    }

    struct Distribution {
        address user;
        uint256 rewardId;
        address rewardToken;
        uint256 rewardAmount;
        bool isClaimed;
        bool isActive;
    }

    uint256 public totalRewardCount;

    address public owner;

    address public distributor;

    mapping(uint256 => Reward) public rewards;

    mapping(uint256 => mapping(address => Distribution))
        public userDistribution;

    mapping(address => uint256[]) public userRewards;

    modifier onlyOwner() {
        require(owner == msg.sender);
        _;
    }

    modifier onlyDistributor() {
        require(distributor == msg.sender);
        _;
    }

    constructor(address _owner, address _distributor) {
        owner = _owner;
        distributor = _distributor;
    }

    function getUserDistributions(
        address _user
    ) public view returns (Distribution[] memory) {        
        Distribution[] memory distributions = new Distribution[](userRewards[_user].length);

        for (uint256 i = 0; i < userRewards[_user].length; i++) {
            uint256 rewardId = userRewards[_user][i];
            distributions[i] = userDistribution[rewardId][_user];
        }

        return distributions;
    }

    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    function changeDistributor(address _newDistributor) public onlyOwner {
        distributor = _newDistributor;
    }

    function addReward(
        string memory _title,
        string memory _description,
        address _token,
        uint256 _amount,
        bool _isVariableReward,
        bool _isNative
    ) public onlyOwner {
        Reward memory _reward = Reward({
            id: totalRewardCount,
            title: _title,
            description: _description,
            token: _token,
            amount: _amount,
            isActive: true,
            isVariableReward: _isVariableReward,
            isNative: _isNative
        });

        rewards[totalRewardCount] = _reward;

        totalRewardCount++;
    }

    function addDistribution(
        uint256 _rewardId,
        address _user,
        uint256 _amount
    ) public onlyDistributor {
        Reward memory reward = rewards[_rewardId];

        require(reward.isActive, "addDistribution: reward not found");
        require(
            !userDistribution[_rewardId][_user].isActive,
            "addDistribution: distribution already added"
        );

        if (reward.isVariableReward) {
            require(
                _amount > 0,
                "addDistribution: amount should be greater than 0"
            );
        }

        uint256 rewardAmount = reward.isVariableReward
            ? _amount
            : reward.amount;

        Distribution memory distribution = Distribution({
            user: _user,
            rewardId: _rewardId,
            rewardToken: reward.token,
            rewardAmount: rewardAmount,
            isClaimed: false,
            isActive: true
        });

        userDistribution[_rewardId][_user] = distribution;
        userRewards[_user].push(_rewardId);
    }

    function claimDistribution(uint256 _rewardId) public nonReentrant {
        Distribution storage distribution = userDistribution[_rewardId][
            msg.sender
        ];

        require(
            distribution.isActive,
            "claimDistribution: user has no distribution"
        );

        require(
            !distribution.isClaimed,
            "claimDistribution: reward already claimed"
        );

        Reward memory reward = rewards[_rewardId];

        distribution.isClaimed = true;

        if (reward.isNative) {
            address payable _user = payable(distribution.user);
            (bool sent, ) = _user.call{value: distribution.rewardAmount}("");
            require(sent, "Failed to send FUSE");
        } else {
            IERC20(reward.token).transfer(
                msg.sender,
                distribution.rewardAmount
            );
        }
    }

    function withdrawRewardToken(address _rewardToken) public onlyOwner {
        IERC20(_rewardToken).transfer(
            owner,
            IERC20(_rewardToken).balanceOf(address(this))
        );
    }

    function withdrawFUSE() public onlyOwner {
        (bool sent, ) = owner.call{value: address(this).balance}("");
        require(sent, "Failed to send FUSE");
    }

    receive() external payable {}
}
