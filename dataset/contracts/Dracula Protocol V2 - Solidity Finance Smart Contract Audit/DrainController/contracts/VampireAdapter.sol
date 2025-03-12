// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Victim {}

library VampireAdapter {
    // Victim info
    function rewardToken(Victim victim, uint256 poolId) external view returns (IERC20) {
        (bool success, bytes memory result) = address(victim).staticcall(abi.encodeWithSignature("rewardToken(uint256)", poolId));
        require(success, "rewardToken(uint256) staticcall failed.");
        return abi.decode(result, (IERC20));
    }

    function rewardValue(Victim victim, uint256 poolId, uint256 amount) external view returns (uint256) {
        (bool success, bytes memory result) = address(victim).staticcall(abi.encodeWithSignature("rewardValue(uint256,uint256)", poolId, amount));
        require(success, "rewardValue(uint256,uint256) staticcall failed.");
        return abi.decode(result, (uint256));
    }

    function poolCount(Victim victim) external view returns (uint256) {
        (bool success, bytes memory result) = address(victim).staticcall(abi.encodeWithSignature("poolCount()"));
        require(success, "poolCount() staticcall failed.");
        return abi.decode(result, (uint256));
    }

    function sellableRewardAmount(Victim victim, uint256 poolId) external view returns (uint256) {
        (bool success, bytes memory result) = address(victim).staticcall(abi.encodeWithSignature("sellableRewardAmount(uint256)", poolId));
        require(success, "sellableRewardAmount(uint256) staticcall failed.");
        return abi.decode(result, (uint256));
    }

    // Victim actions
    function sellRewardForWeth(Victim victim, uint256 poolId, uint256 rewardAmount, address to) external returns(uint256) {
        (bool success, bytes memory result) = address(victim).delegatecall(abi.encodeWithSignature("sellRewardForWeth(address,uint256,uint256,address)", address(victim), poolId, rewardAmount, to));
        require(success, "sellRewardForWeth(uint256,address) delegatecall failed.");
        return abi.decode(result, (uint256));
    }

    // Pool info
    function lockableToken(Victim victim, uint256 poolId) external view returns (IERC20) {
        (bool success, bytes memory result) = address(victim).staticcall(abi.encodeWithSignature("lockableToken(uint256)", poolId));
        require(success, "lockableToken(uint256) staticcall failed.");
        return abi.decode(result, (IERC20));
    }

    function lockedAmount(Victim victim, uint256 poolId) external view returns (uint256) {
        // note the impersonation
        (bool success, bytes memory result) = address(victim).staticcall(abi.encodeWithSignature("lockedAmount(address,uint256)", address(this), poolId));
        require(success, "lockedAmount(uint256) staticcall failed.");
        return abi.decode(result, (uint256));
    }

    function pendingReward(Victim victim, uint256 poolId, uint256 victimPoolId) external view returns (uint256) {
        // note the impersonation
        (bool success, bytes memory result) = address(victim).staticcall(abi.encodeWithSignature("pendingReward(address,uint256,uint256)", address(victim), poolId, victimPoolId));
        require(success, "pendingReward(address,uint256,uint256) staticcall failed.");
        return abi.decode(result, (uint256));
    }

    // Pool actions
    function deposit(Victim victim, uint256 poolId, uint256 amount) external returns (uint256) {
        (bool success, bytes memory result) = address(victim).delegatecall(abi.encodeWithSignature("deposit(address,uint256,uint256)", address(victim), poolId, amount));
        require(success, "deposit(uint256,uint256) delegatecall failed.");
        return abi.decode(result, (uint256));
    }

    function withdraw(Victim victim, uint256 poolId, uint256 amount) external returns (uint256) {
        (bool success, bytes memory result) = address(victim).delegatecall(abi.encodeWithSignature("withdraw(address,uint256,uint256)", address(victim), poolId, amount));
        require(success, "withdraw(uint256,uint256) delegatecall failed.");
        return abi.decode(result, (uint256));
    }

    function claimReward(Victim victim, uint256 poolId, uint256 victimPoolId) external {
        (bool success,) = address(victim).delegatecall(abi.encodeWithSignature("claimReward(address,uint256,uint256)", address(victim), poolId, victimPoolId));
        require(success, "claimReward(uint256,uint256) delegatecall failed.");
    }

    function emergencyWithdraw(Victim victim, uint256 poolId) external {
        (bool success,) = address(victim).delegatecall(abi.encodeWithSignature("emergencyWithdraw(address,uint256)", address(victim), poolId));
        require(success, "emergencyWithdraw(uint256) delegatecall failed.");
    }

    // Service methods
    function poolAddress(Victim victim, uint256 poolId) external view returns (address) {
        (bool success, bytes memory result) = address(victim).staticcall(abi.encodeWithSignature("poolAddress(uint256)", poolId));
        require(success, "poolAddress(uint256) staticcall failed.");
        return abi.decode(result, (address));
    }

    function rewardToWethPool(Victim victim) external view returns (address) {
        (bool success, bytes memory result) = address(victim).staticcall(abi.encodeWithSignature("rewardToWethPool()"));
        require(success, "rewardToWethPool() staticcall failed.");
        return abi.decode(result, (address));
    }
}