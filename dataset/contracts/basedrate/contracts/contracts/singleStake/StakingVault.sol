/**

// SPDX-License-Identifier: MIT
*/
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// import "hardhat/console.sol";

interface IStaking {
    function injectRewardsWithTime(uint256 rewardsSeconds) external payable;
}

contract StakingVault is Ownable, Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private callers;
    using Address for address payable;

    uint256 public stakingRoundDuration = 1 weeks;
    uint256 public lastStakingRound;
    uint256 public distributionPercentage = 2000; //20% per week
    IStaking public staking;

    uint256 public currentRewards;
    uint256 public totalRewards;

    modifier onlyCaller() {
        require(isCaller(_msgSender()), "STAKING VAULT: Wrong caller");
        _;
    }

    constructor(IStaking _staking) {
        lastStakingRound = block.timestamp;
        staking = _staking;
        addCaller(_msgSender());
        addCaller(address(this));
    }

    function checkRound() external whenNotPaused {
        if (block.timestamp > lastStakingRound + stakingRoundDuration) {
            _startStakingRound();
        }
    }

    function startStakingRoundWithoutChecking()
        public
        onlyCaller
        whenNotPaused
    {
        _startStakingRound();
    }

    function _startStakingRound() internal {
        uint256 roundRewards = (address(this).balance *
            distributionPercentage) / 10_000;
        currentRewards = roundRewards;
        totalRewards += roundRewards;
        lastStakingRound = block.timestamp;
        staking.injectRewardsWithTime{value: roundRewards}(
            stakingRoundDuration
        );
    }

    function getNextRoundRewards()
        external
        view
        returns (uint256 nextRoundRewards)
    {
        nextRoundRewards =
            (address(this).balance * distributionPercentage) /
            10_000;
    }

    function setStakingRoundDuration(
        uint256 _stakingRoundDuration
    ) external onlyOwner {
        stakingRoundDuration = _stakingRoundDuration;
    }

    function setDistributionPercentage(
        uint256 _distributionPercentage
    ) external onlyOwner {
        distributionPercentage = _distributionPercentage;
    }

    function isCaller(address account) public view returns (bool) {
        return callers.contains(account);
    }

    function addCaller(address caller) public onlyOwner returns (bool) {
        require(
            caller != address(0),
            "STAKING VAULT: caller is the zero address"
        );
        return callers.add(caller);
    }

    function delCaller(address caller) external onlyOwner returns (bool) {
        require(
            caller != address(0),
            "STAKING VAULT: caller is the zero address"
        );
        return callers.remove(caller);
    }

    function getCallersLength() external view returns (uint256) {
        return callers.length();
    }

    function getCaller(uint256 index) external view returns (address) {
        require(
            index <= callers.length() - 1,
            "STAKING VAULT: index out of bounds"
        );
        return callers.at(index);
    }

    function rescuePLS() external onlyCaller {
        payable(_msgSender()).sendValue(address(this).balance);
    }

    function pause() external onlyCaller {
        _pause();
    }

    function unpause() external onlyCaller {
        _unpause();
    }

    receive() external payable {}
}
