// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";

import "./interfaces/IRewardDistributor.sol";
import "./interfaces/IRewardTracker.sol";
import "../access/Governable.sol";

contract StakedAlpRewardDistributor is IRewardDistributor, ReentrancyGuard, Governable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public override rewardToken;
    uint256 public tokensPerInterval1;
    uint256 public tokensPerInterval2;
    uint256 public tokensPerInterval3;
    uint256 public tokensPerInterval4;
    uint256 public lastDistributionTime;
    address public rewardTracker;

    uint256 public immutable stakedAlpPart1 = 1_000_000 * 10 ** 18;
    uint256 public immutable stakedAlpPart2 = 3_000_000 * 10 ** 18;
    uint256 public immutable stakedAlpPart3 = 6_000_000 * 10 ** 18;
    uint256 public immutable stakedAlpPart4 = 10_000_000 * 10 ** 18;

    address public admin;

    event Distribute(uint256 amount);
    event TokensPerIntervalChange(
        uint256 tokensPerInterval1,
        uint256 tokensPerInterval2,
        uint256 tokensPerInterval3,
        uint256 tokensPerInterval4
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "RewardDistributor: forbidden");
        _;
    }

    constructor(address _rewardToken, address _rewardTracker) public {
        rewardToken = _rewardToken;
        rewardTracker = _rewardTracker;
        admin = msg.sender;
    }

    function setAdmin(address _admin) external onlyGov {
        admin = _admin;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function updateLastDistributionTime() external onlyAdmin {
        lastDistributionTime = block.timestamp;
    }

    function tokensPerInterval() public view override returns (uint256) {
        uint256 supply = IERC20(rewardTracker).totalSupply();
        if (supply <= stakedAlpPart1) {
            return supply.mul(tokensPerInterval1).div(stakedAlpPart1);
        } else if (supply <= stakedAlpPart2) {
            return supply.mul(tokensPerInterval2).div(stakedAlpPart2);
        } else if (supply <= stakedAlpPart3) {
            return supply.mul(tokensPerInterval3).div(stakedAlpPart3);
        } else if (supply <= stakedAlpPart4) {
            return supply.mul(tokensPerInterval4).div(stakedAlpPart4);
        }
        return tokensPerInterval4;
    }

    function setTokensPerIntervals(
        uint256 _tokensPerInterval1,
        uint256 _tokensPerInterval2,
        uint256 _tokensPerInterval3,
        uint256 _tokensPerInterval4
    ) external onlyAdmin {
        require(lastDistributionTime != 0, "RewardDistributor: invalid lastDistributionTime");
        IRewardTracker(rewardTracker).updateRewards();
        tokensPerInterval1 = _tokensPerInterval1;
        tokensPerInterval2 = _tokensPerInterval2;
        tokensPerInterval3 = _tokensPerInterval3;
        tokensPerInterval4 = _tokensPerInterval4;
        emit TokensPerIntervalChange(
            _tokensPerInterval1,
            _tokensPerInterval2,
            _tokensPerInterval3,
            _tokensPerInterval4
        );
    }

    function pendingRewards() public view override returns (uint256) {
        if (block.timestamp == lastDistributionTime) {
            return 0;
        }

        uint256 timeDiff = block.timestamp.sub(lastDistributionTime);
        return tokensPerInterval().mul(timeDiff);
    }

    function distribute() external override returns (uint256) {
        require(msg.sender == rewardTracker, "RewardDistributor: invalid msg.sender");
        uint256 amount = pendingRewards();
        lastDistributionTime = block.timestamp;

        if (amount == 0) { return 0; }


        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        if (amount > balance) { amount = balance; }

        IERC20(rewardToken).safeTransfer(msg.sender, amount);

        emit Distribute(amount);
        return amount;
    }
}
