// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interface/Vault.sol";
import "../interface/YieldWorker.sol";
import "../interface/IAlpacaVault.sol";
import "../interface/IFairLaunch.sol";
import "../interface/IMasterChef.sol";
import "../interface/IUniswapRouterETH.sol";
import "hardhat/console.sol";

contract MasterChefWithVaultWorker is YieldWorker, Ownable, Pausable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Tokens used
    IERC20 public farm;
    IERC20 public farmReward;
    IERC20 public userReward;
    IERC20 public fairLaunchReward;

    // Contract dependencies
    Vault public vault;
    IAlpacaVault public alpacaVault;
    IFairLaunch public fairLaunch;
    IUniswapRouterETH public router;
    IMasterChef public masterChef;

    // Current pending reward amount
    uint256 public pending;
    // Current reward amount
    uint256 public currentReward;
    // MasterChef poolId
    uint256 public poolId;
    // Alpaca FairLaunch poolId
    uint256 public fairLaunchPoolId;
    // Reward token route
    address[] public rewardRoute;
    address[] public fairLaunchRewardRoute;

    modifier onlyVault {
        require(msg.sender == address(vault), "permission: not vault!");
        _;
    }

    constructor(
        IERC20 _farmToken,
        IERC20 _farmRewardToken,
        IERC20 _userRewardToken, 
        IERC20 _fairLaunchRewardToken, 
        IAlpacaVault _alpacaVault,
        IFairLaunch _fairLaunch,
        IUniswapRouterETH _router,
        IMasterChef _masterChef,
        uint256 _poolId,
        uint256 _fairLaunchPoolId,
        address[] memory _rewardRoute,
        address[] memory _fairLaunchRewardRoute
    ) public {
        farm = _farmToken;
        farmReward = _farmRewardToken;
        userReward = _userRewardToken;
        fairLaunchReward = _fairLaunchRewardToken;
        alpacaVault = _alpacaVault;
        fairLaunch = _fairLaunch;
        router = _router;
        masterChef = _masterChef;
        poolId = _poolId;
        fairLaunchPoolId = _fairLaunchPoolId;
        rewardRoute = _rewardRoute;
        fairLaunchRewardRoute = _fairLaunchRewardRoute;

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

    function vaultPendingUpdateAccrueReward() public view returns (uint256) {
        uint256 share = alpacaVault.balanceOf(address(this));

        if (share > 0) {
          uint256 accrueReward = vaultShareToTokenAmount(share);
          return accrueReward.sub(currentReward);
        } else {
          return 0;
        }
    }

    function vaultShareToTokenAmount(uint256 share) internal view returns (uint256) {
        return share.mul(alpacaVault.totalToken()).div(alpacaVault.totalSupply());
    }

    function vaultTokenAmountToShare(uint256 amountToken) internal view returns (uint256) {
      return amountToken.mul(alpacaVault.totalSupply()).div(alpacaVault.totalToken());
    }

    // Mutation

    function deposit() external override onlyVault whenNotPaused {
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

    function work() external override onlyVault whenNotPaused {
        masterChef.deposit(poolId, 0);
        fairLaunch.withdrawAll(address(this), fairLaunchPoolId);

        uint256 farmRewardBalance = farmReward.balanceOf(address(this));
        uint256 fairLaunchRewardBalance = fairLaunchReward.balanceOf(address(this));

        // Work on selling reward
        if (farmRewardBalance > 0) {
            router.swapExactTokensForTokens(farmRewardBalance, 0, rewardRoute, address(this), now);
        }

        // Work on selling extra reward from fair launch
        if (fairLaunchRewardBalance > 0) {
            router.swapExactTokensForTokens(fairLaunchRewardBalance, 0, fairLaunchRewardRoute, address(this), now);
        }
        
        uint256 rewardBalance = userReward.balanceOf(address(this));

        if (rewardBalance > 0) {
            alpacaVault.deposit(rewardBalance);

            uint256 pendingAccrueReward = vaultPendingUpdateAccrueReward();
            pending = pendingAccrueReward;
            currentReward = currentReward.add(pendingAccrueReward);

            // Update vault reward value and reset pending for the next work
            vault.updateVault();
            pending = 0;

            // Work on deposit to vault
        }

        fairLaunch.deposit(address(this), fairLaunchPoolId, alpacaVault.balanceOf(address(this)));
    }

    function claimReward(uint256 _amount) external override onlyVault whenNotPaused {
        if (_amount > 0) {
          uint256 workerBalance = userReward.balanceOf(address(this));
          uint256 share = vaultTokenAmountToShare(_amount.sub(workerBalance));
          fairLaunch.withdraw(address(this), fairLaunchPoolId, share);
          alpacaVault.withdraw(share);
          currentReward = currentReward.sub(_amount);

          userReward.safeTransfer(msg.sender, _amount);
        }
    }

    function emergencyWithdraw() external override onlyVault {
        masterChef.emergencyWithdraw(poolId);
        farm.safeTransfer(address(vault), farm.balanceOf(address(this)));
    }

    function setVault(address _vault) external onlyOwner {
        vault = Vault(_vault);
    }

    function pause() public onlyOwner {
        _pause();

        _removeAllowances();
    }

    function unpause() external onlyOwner {
        _unpause();

        _giveAllowances();
    }

    function _giveAllowances() internal {
        IERC20(farm).safeApprove(address(masterChef), uint256(-1));
        IERC20(farmReward).safeApprove(address(router), uint256(-1));
        IERC20(fairLaunchReward).safeApprove(address(router), uint256(-1));
        IERC20(userReward).safeApprove(address(alpacaVault), uint256(-1));
        IERC20(alpacaVault).safeApprove(address(alpacaVault), uint256(-1));
        IERC20(alpacaVault).safeApprove(address(fairLaunch), uint256(-1));
    }

    function _removeAllowances() internal {
        IERC20(farm).safeApprove(address(masterChef), 0);
        IERC20(farmReward).safeApprove(address(router), 0);
        IERC20(fairLaunchReward).safeApprove(address(router), uint256(0));
        IERC20(userReward).safeApprove(address(alpacaVault), 0);
        IERC20(alpacaVault).safeApprove(address(alpacaVault), 0);
        IERC20(alpacaVault).safeApprove(address(fairLaunch), 0);
    }

}
