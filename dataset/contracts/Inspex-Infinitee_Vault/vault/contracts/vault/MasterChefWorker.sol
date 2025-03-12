// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interface/Vault.sol";
import "../interface/YieldWorker.sol";
import "../interface/IMasterChef.sol";
import "../interface/IUniswapRouterETH.sol";
import "hardhat/console.sol";

contract MasterChefWorker is YieldWorker, Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Tokens used
    IERC20 public farm;
    IERC20 public farmReward;
    IERC20 public userReward;

    // Contract dependencies
    Vault public vault;
    IMasterChef public masterChef;
    IUniswapRouterETH public router;

    // Current pending reward amount
    uint256 public pending;
    // MasterChef poolId
    uint256 public poolId;
    // Reward token route
    address[] public rewardRoute;

    modifier onlyVault {
        require(msg.sender == address(vault), "permission: not vault!");
        _;
    }

    constructor(
        IERC20 _farmToken,
        IERC20 _farmRewardToken,
        IERC20 _userRewardToken, 
        IUniswapRouterETH _router,
        IMasterChef _masterChef,
        uint256 _poolId,
        address[] memory _rewardRoute
    ) public {
        farm = _farmToken;
        farmReward = _farmRewardToken;
        userReward = _userRewardToken;
        router = _router;
        masterChef = _masterChef;
        poolId = _poolId;
        rewardRoute = _rewardRoute;

        _giveAllowances();
    }

    // View

    function farmToken() external view override returns (address) {
        return address(farm);
    }

    function farmRewardToken() external view override returns (address) {
        return address(farmReward);
    }

    function userRewardToken() external view override returns (address) {
        return address(userReward);
    }

    function pendingReward() external view override returns (uint256) {
        return pending;
    }

    // Mutation

    function deposit() external override onlyVault {
        uint256 balance = farm.balanceOf(address(this));

        if (balance > 0) {
            masterChef.deposit(poolId, balance);
        }
    }

    function withdraw(uint256 _amount) external override onlyVault {
        uint256 wantBalance = farm.balanceOf(address(this));

        if (wantBalance < _amount) {
            masterChef.withdraw(poolId, _amount.sub(wantBalance));
            wantBalance = farm.balanceOf(address(this));
        }

        if (wantBalance > _amount) {
          wantBalance = _amount;
        }

        farm.safeTransfer(address(vault), wantBalance);
    }

    function work() external override onlyVault {
        masterChef.deposit(poolId, 0);

        uint256 farmRewardBalance = farmReward.balanceOf(address(this));

        if (farmRewardBalance > 0) {
            uint256 beforeRewardBalance = userReward.balanceOf(address(this));
            router.swapExactTokensForTokens(farmRewardBalance, 0, rewardRoute, address(this), now);
            uint256 rewardBalance = userReward.balanceOf(address(this)).sub(beforeRewardBalance);
            pending = rewardBalance;
            vault.updateVault();
            pending = 0;
        }
    }

    function claimReward(uint256 _amount) external override onlyVault {
        userReward.safeTransfer(msg.sender, _amount);
    }

    function setVault(address _vault) external onlyOwner {
        vault = Vault(_vault);
    }

    function emergencyWithdraw() external override onlyOwner {
        masterChef.emergencyWithdraw(poolId);
    }

    function _giveAllowances() internal {
        IERC20(farm).safeApprove(address(masterChef), uint256(-1));
        IERC20(farmReward).safeApprove(address(router), uint256(-1));
    }

    function _removeAllowances() internal {
        IERC20(farm).safeApprove(address(masterChef), 0);
        IERC20(farmReward).safeApprove(address(router), 0);
    }

}
