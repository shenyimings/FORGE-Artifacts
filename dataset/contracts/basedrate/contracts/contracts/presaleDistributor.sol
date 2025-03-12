//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IBasedRateSale.sol";

contract presaleDistributor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IBasedRateSale public basedRateSale;
    IERC20 public brate;
    IERC20 public bshare;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public runtime = 3 days;
    uint256 public constant EXTRA_PERCENT_BRATE = 23;

    mapping(address => UserData) public users;

    struct UserData {
        uint256 brateBought;
        uint256 bshareBought;
        uint256 brateClaimed;
        uint256 bshareClaimed;
        uint256 lastClaimTime;
    }

    constructor(uint256 _startTime, address _brate, address _bshare) {
        basedRateSale = IBasedRateSale(
            0xf47567B9d6Ee249FcD60e8Ab9635B32F8ac87659
        );
        startTime = _startTime;
        endTime = startTime + runtime;
        brate = IERC20(_brate);
        bshare = IERC20(_bshare);
    }

    function getTotalValues()
        external
        view
        returns (
            uint256 totalBrateBought,
            uint256 totalBshareBought,
            uint256 totalBrateClaimed,
            uint256 totalBshareClaimed
        )
    {
        uint256 userCount = basedRateSale.userCount();
        for (uint256 i = 0; i < userCount; i++) {
            address currentUser = basedRateSale.userIndex(i);
            totalBrateBought += users[currentUser].brateBought;
            totalBshareBought += users[currentUser].bshareBought;
            totalBrateClaimed += users[currentUser].brateClaimed;
            totalBshareClaimed += users[currentUser].bshareClaimed;
        }
    }

    function Claim() public nonReentrant {
        address user = msg.sender;
        require(users[user].lastClaimTime != 0, "invalid lastClaimTime");
        uint256 brateClaimed = users[user].brateClaimed;
        uint256 brateBought = users[user].brateBought;
        uint256 bshareClaimed = users[user].bshareClaimed;
        uint256 bshareBought = users[user].bshareBought;
        require(
            (brateBought + bshareBought) > 0,
            "you have no tokens to claim!"
        );

        uint256 pendingRateAmount = pendingRate(user);
        if (brateClaimed == brateBought) {
            pendingRateAmount = 0;
        }
        if ((pendingRateAmount + brateClaimed) > brateBought) {
            pendingRateAmount = brateBought - brateClaimed;
        }

        uint256 pendingShareAmount = pendingShare(user);
        if (bshareClaimed == bshareBought) {
            pendingShareAmount = 0;
        }
        if ((pendingShareAmount + bshareClaimed) > bshareBought) {
            pendingShareAmount = bshareBought - bshareClaimed;
        }

        require(
            (pendingRateAmount + pendingShareAmount) > 0,
            "Nothing to claim!"
        );

        brate.safeTransfer(user, pendingRateAmount);
        bshare.safeTransfer(user, pendingShareAmount);

        users[user].brateClaimed += pendingRateAmount;
        users[user].bshareClaimed += pendingShareAmount;
        users[user].lastClaimTime = block.timestamp;
    }

    function rewardsPerSecondRate(address _user) public view returns (uint256) {
        uint256 totalBrate = users[_user].brateBought;
        return (totalBrate * 1e18) / runtime;
    }

    function rewardsPerSecondShare(
        address _user
    ) public view returns (uint256) {
        uint256 totalBshare = users[_user].bshareBought;
        return (totalBshare * 1e18) / runtime;
    }

    function pendingShare(address _user) public view returns (uint256) {
        uint256 lastRewardTime = users[_user].lastClaimTime;
        uint256 rewardsPerSecond = rewardsPerSecondShare(_user);
        if (block.timestamp > lastRewardTime) {
            uint256 multiplier = getMultiplier(lastRewardTime, block.timestamp);
            uint256 tokenReward = (multiplier * rewardsPerSecond) / 1e18;
            return tokenReward;
        } else {
            return 0;
        }
    }

    function pendingRate(address _user) public view returns (uint256) {
        uint256 lastRewardTime = users[_user].lastClaimTime;
        uint256 rewardsPerSecond = rewardsPerSecondRate(_user);
        if (block.timestamp > lastRewardTime) {
            uint256 multiplier = getMultiplier(lastRewardTime, block.timestamp);
            uint256 tokenReward = (multiplier * rewardsPerSecond) / 1e18;
            return tokenReward;
        } else {
            return 0;
        }
    }

    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) public view returns (uint256) {
        if (_to <= endTime) {
            return (_to - _from);
        } else if (_from >= endTime) {
            return 0;
        } else {
            return (endTime - _from);
        }
    }

    function fetchUserData(
        address _user
    ) external view returns (IBasedRateSale.UserData memory) {
        return basedRateSale.users(_user);
    }

    function fetchUserIndex(uint256 index) external view returns (address) {
        return basedRateSale.userIndex(index);
    }

    function fetchUserCount() external view returns (uint256) {
        return basedRateSale.userCount();
    }

    function updateSingleUser(address _user) external onlyOwner {
        IBasedRateSale.UserData memory userData = basedRateSale.users(_user);
        uint256 intermediateValue = userData.brateBought / 1000;
        uint256 percent = (intermediateValue * EXTRA_PERCENT_BRATE) / 100;
        users[_user].brateBought = intermediateValue + percent;
        users[_user].bshareBought = userData.bshareBought;
        users[_user].lastClaimTime = startTime;
    }

    function updateSingleUserMan(
        address _user,
        uint256 _brateBought,
        uint256 _bshareBought
    ) external onlyOwner {
        users[_user].brateBought = _brateBought;
        users[_user].bshareBought = _bshareBought;
        users[_user].lastClaimTime = startTime;
    }

    function updateUsers(uint _from, uint _to) external onlyOwner {
        for (uint256 i = _from; i < _to; i++) {
            address currentUser = basedRateSale.userIndex(i);
            IBasedRateSale.UserData memory userData = basedRateSale.users(
                currentUser
            );
            uint256 intermediateValue = userData.brateBought / 1000;
            uint256 percent = (intermediateValue * EXTRA_PERCENT_BRATE) / 100;
            users[currentUser].brateBought = intermediateValue + percent;
            users[currentUser].bshareBought = userData.bshareBought;
            users[currentUser].lastClaimTime = startTime;
        }
    }

    function updateAllUsers() external onlyOwner {
        uint256 totalUsers = basedRateSale.userCount();
        for (uint256 i = 0; i < totalUsers; i++) {
            address currentUser = basedRateSale.userIndex(i);
            IBasedRateSale.UserData memory userData = basedRateSale.users(
                currentUser
            );
            uint256 intermediateValue = userData.brateBought / 1000;
            uint256 percent = (intermediateValue * EXTRA_PERCENT_BRATE) / 100;
            users[currentUser].brateBought = intermediateValue + percent;
            users[currentUser].bshareBought = userData.bshareBought;
            users[currentUser].lastClaimTime = startTime;
        }
    }

    function recoverTokens(
        address tokenAddress,
        address to
    ) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(to, token.balanceOf(address(this)));
    }
}
