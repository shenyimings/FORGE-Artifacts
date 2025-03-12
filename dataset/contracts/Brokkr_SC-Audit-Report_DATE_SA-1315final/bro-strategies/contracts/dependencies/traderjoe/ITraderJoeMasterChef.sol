// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITraderJoeMasterChef {
    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardTimestamp;
        uint256 accJoePerShare;
    }

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    function poolLength() external view returns (uint256);

    function poolInfo(uint256 pid)
        external
        view
        returns (ITraderJoeMasterChef.PoolInfo memory);

    function userInfo(uint256 _poolId, address _user)
        external
        view
        returns (UserInfo memory);

    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 pid, uint256 amount) external;
}
