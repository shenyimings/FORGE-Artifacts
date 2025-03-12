// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IDistributable.sol";

import "@openzeppelin/contracts/governance/TimelockController.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

/**
 * @dev Strategy functions that do not require timelock or have a timelock less than the min timelock
 */
interface IStrategy {
    function pause() external;

    function unpause() external;

    function rebalance(uint256 _borrowRate, uint256 _borrowDepth) external;

    function deleverageOnce() external;

    function leverageOnce() external;

    function wrapETH() external;

    // In case new vaults require functions without a timelock as well, hoping to avoid having multiple timelock contracts
    function noTimeLockFunc1() external;

    function noTimeLockFunc2() external;

    function noTimeLockFunc3() external;


    function setIsEarnable(bool _isEarnable) external;

}


contract RewardsDistributorTimelock is
    TimelockController,
    ReentrancyGuard,
    IDistributable
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address payable public treasuryAddress;
    address payable public AVAStakingAddress;
    address public rewardToken = 0x0f933Dc137D21cA519ae4C7E93f87a4C8EF365Ef;    //ava-sdn LP

    uint256 public AVAStakingRewardsFactor; // X/10,000 of rewards go to AVA staking vault. The rest goes to treasury.

    event AVAStakingRewardsFactorChange(
        uint256 oldAVAStakingRewardsFactor,
        uint256 newAVAStakingRewardsFactor
    );

    /**
     * @dev Initializes the contract with a given `minDelay`.
     */
    constructor(
        uint256 _minDelay,
        address[] memory _proposers,
        address[] memory _executors,
        address payable _treasuryAddress,
        address payable _AVAStakingAddress,
        uint256 _AVAStakingRewardsFactor
    ) TimelockController(_minDelay, _proposers, _executors) {
        treasuryAddress = _treasuryAddress;
        AVAStakingAddress = _AVAStakingAddress;
        AVAStakingRewardsFactor = _AVAStakingRewardsFactor;
    }

    function setAVAStakingRewardsFactor(uint256 newAVAStakingRewardsFactor)
        external
        virtual
    {
        require(
            msg.sender == address(this),
            "TimelockController: caller must be timelock"
        );
        require(newAVAStakingRewardsFactor <= 1000, "Factor > 1000");
        emit AVAStakingRewardsFactorChange(
            AVAStakingRewardsFactor,
            newAVAStakingRewardsFactor
        );
        AVAStakingRewardsFactor = newAVAStakingRewardsFactor;
    }

    function pause(address _stratAddress) external onlyRole(EXECUTOR_ROLE) {
        IStrategy(_stratAddress).pause();
    }

    function unpause(address _stratAddress) external onlyRole(EXECUTOR_ROLE) {
        IStrategy(_stratAddress).unpause();
    }

    function rebalance(
        address _stratAddress,
        uint256 _borrowRate,
        uint256 _borrowDepth
    ) external onlyRole(EXECUTOR_ROLE) {
        IStrategy(_stratAddress).rebalance(_borrowRate, _borrowDepth);
    }

    function deleverageOnce(address _stratAddress)
        external
        onlyRole(EXECUTOR_ROLE)
    {
        IStrategy(_stratAddress).deleverageOnce();
    }

    function leverageOnce(address _stratAddress)
        external
        onlyRole(EXECUTOR_ROLE)
    {
        IStrategy(_stratAddress).leverageOnce();
    }

    function wrapETH(address _stratAddress) external onlyRole(EXECUTOR_ROLE) {
        IStrategy(_stratAddress).wrapETH();
    }

    // // In case new vaults require functions without a timelock as well, hoping to avoid having multiple timelock contracts
    function noTimeLockFunc1(address _stratAddress)
        external
        onlyRole(EXECUTOR_ROLE)
    {
        IStrategy(_stratAddress).noTimeLockFunc1();
    }

    function noTimeLockFunc2(address _stratAddress)
        external
        onlyRole(EXECUTOR_ROLE)
    {
        IStrategy(_stratAddress).noTimeLockFunc2();
    }

    function noTimeLockFunc3(address _stratAddress)
        external
        onlyRole(EXECUTOR_ROLE)
    {
        IStrategy(_stratAddress).noTimeLockFunc3();
    }

    function setIsEarnable(address _stratAddress, bool _isEarnable) external onlyRole(EXECUTOR_ROLE){
        IStrategy(_stratAddress).setIsEarnable(_isEarnable);
    }


    function distributeRewards() external override
    {
        uint256 rewardsAmt = IERC20(rewardToken).balanceOf(address(this));

        if (AVAStakingRewardsFactor > 0) {
            uint256 AVAStakingRewards =
                rewardsAmt.mul(AVAStakingRewardsFactor).div(1000);
            IERC20(rewardToken).safeTransfer(
                AVAStakingAddress,
                AVAStakingRewards
            );
            rewardsAmt = rewardsAmt.sub(AVAStakingRewards);
        }

        IERC20(rewardToken).safeTransfer(treasuryAddress, rewardsAmt);
    }
}
