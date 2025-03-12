// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./utils/HasNoEther.sol";
import "./utils/DateTime.sol";

contract SuperfineDistribute is ReentrancyGuard, HasNoEther {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Store distributor status link to specific type of token
    mapping(address => mapping(address => bool)) private allowedDistributors;

    // Store latest day that distributored added reward for the user
    mapping(address => mapping(address => uint256)) private latestAddRewardDate;

    // Store rewards of user link to specific type of token
    mapping(address => mapping(address => uint256)) private rewards;

    // Total Amount of reward of a specific token,
    // just for the sake of no looping
    mapping(address => uint256) private totalRewards;

    // Mapping store state of supported distribute token in the contract
    mapping(address => bool) private supportedToken;

    /* ========== CONSTRUCTOR ========== */
    constructor(address _newOwner) {
        transferOwnership(_newOwner);
    }

    /* ======== Native Function ========= */
    function viewReward(
        address tokenAddr,
        address addr
    ) public view returns (uint256) {
        return rewards[tokenAddr][addr];
    }

    function addRewards(
        address tokenAddr,
        address[] memory addrs,
        uint256[] memory amount
    )
        external
        nonReentrant
        onlyDistributor(tokenAddr)
        enoughBalance(tokenAddr, amount)
        onlySupportedToken(tokenAddr)
    {
        require(
            addrs.length == amount.length,
            "SuperfineDistribute: addrs and amount does not same length"
        );
        uint256 addedRewardAmount = _calSumAmount(amount);
        uint256 today = DateTime.toDateUnit(block.timestamp);
        for (uint256 i = 0; i < addrs.length; i++) {
            rewards[tokenAddr][addrs[i]] = (rewards[tokenAddr][addrs[i]]).add(
                amount[i]
            );
            if (latestAddRewardDate[tokenAddr][addrs[i]] >= today) {
                revert("reward already added for today");
            }
            latestAddRewardDate[tokenAddr][addrs[i]] = today;
        }
        totalRewards[tokenAddr] = totalRewards[tokenAddr].add(
            addedRewardAmount
        );
    }

    function updateDistributors(
        address tokenAddr,
        address distributor,
        bool ok
    ) external onlyOwner onlySupportedToken(tokenAddr) {
        allowedDistributors[tokenAddr][distributor] = ok;
        if (ok) {
            emit AddDistributor(tokenAddr, distributor);
        } else {
            emit RemoveDistributor(tokenAddr, distributor);
        }
    }

    function updateSupportedToken(
        address tokenAddr,
        bool ok
    ) external onlyOwner {
        supportedToken[tokenAddr] = ok;
        if (ok) {
            emit AddToken(tokenAddr);
        } else {
            emit RemoveToken(tokenAddr);
        }
    }

    function getReward(
        address tokenAddr
    ) external haveReward(tokenAddr) onlySupportedToken(tokenAddr) {
        uint256 rewardAmount = rewards[tokenAddr][msg.sender];
        if (tokenAddr == address(0)) {
            (bool success, ) = payable(msg.sender).call{value: rewardAmount}(
                ""
            );
            require(success, "SuperfineDistribute: transfer failed.");
        } else {
            IERC20(tokenAddr).safeTransfer(msg.sender, rewardAmount);
        }
        rewards[tokenAddr][msg.sender] = rewards[tokenAddr][msg.sender].sub(
            rewardAmount
        );
        totalRewards[tokenAddr] = totalRewards[tokenAddr].sub(rewardAmount);
    }

    function _calSumAmount(
        uint256[] memory amount
    ) private pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < amount.length; i++) {
            total = total.add(amount[i]);
        }
        return total;
    }

    fallback() external payable {}

    receive() external payable {}

    /* ======== Modfier ========= */

    modifier onlyDistributor(address _token) {
        require(
            allowedDistributors[_token][msg.sender],
            "SuperfineDistribute: only distributor can take this action"
        );
        _;
    }

    modifier onlySupportedToken(address _token) {
        require(
            supportedToken[_token],
            "SuperfineDistribute: unsupported token"
        );
        _;
    }

    modifier enoughBalance(address tokenAddr, uint256[] memory amount) {
        uint256 total = _calSumAmount(amount);
        uint256 thisAccountBalance = 0;
        if (tokenAddr == address(0)) {
            thisAccountBalance = address(this).balance;
        } else {
            thisAccountBalance = IERC20(tokenAddr).balanceOf(address(this));
        }
        require(
            totalRewards[tokenAddr].add(total) <= thisAccountBalance,
            "SuperfineDistribute: balance not enough"
        );
        _;
    }

    modifier haveReward(address tokenAddr) {
        require(
            rewards[tokenAddr][msg.sender] > 0,
            "SuperfineDistribute: you don't have any reward"
        );
        _;
    }

    /* ======== Event ========= */
    event AddDistributor(
        address indexed tokenAddr,
        address indexed distributor
    );
    event RemoveDistributor(
        address indexed tokenAddr,
        address indexed distributor
    );
    event AddToken(address indexed tokenAddr);
    event RemoveToken(address indexed tokenAddr);
}
