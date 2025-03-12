// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IPool} from "aave-v3/interfaces/IPool.sol";

import {IAdapter} from "../../../src/steth/IAdapter.sol";
import {Constants as C} from "../../../src/lib/Constants.sol";

// Adapter to test claimRewards method
contract MockAdapter is IAdapter {
    using SafeTransferLib for ERC20;

    address public immutable rewardsHolder;

    constructor(ERC20 _rewardToken) {
        rewardsHolder = address(new RewardsHolder(_rewardToken));
    }

    uint256 public constant id = 69;

    function claimRewards(bytes calldata data) external override {
        uint256 amount = abi.decode(data, (uint256));
        RewardsHolder(rewardsHolder).claim(amount);
    }

    function setApprovals() external override {}
    function revokeApprovals() external override {}
    function supply(uint256 _amount) external override {}
    function borrow(uint256 _amount) external override {}
    function repay(uint256 _amount) external override {}
    function withdraw(uint256 _amount) external override {}
    function getCollateral(address _account) external view override returns (uint256) {}
    function getDebt(address _account) external view override returns (uint256) {}
    function getMaxLtv() external view override returns (uint256) {}
}

contract RewardsHolder {
    using SafeTransferLib for ERC20;

    ERC20 public rewardToken;

    constructor(ERC20 _rewardToken) {
        rewardToken = _rewardToken;
    }

    function claim(uint256 _amount) public {
        rewardToken.safeTransfer(msg.sender, _amount);
    }
}
