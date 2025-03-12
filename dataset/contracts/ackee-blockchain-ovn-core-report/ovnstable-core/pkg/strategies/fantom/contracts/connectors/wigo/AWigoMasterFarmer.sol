// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

abstract contract AWigoMasterFarmer {

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of WIGOs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accWigoPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accWigoPerShare` (and `lastRewardBlockTime`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool.
        uint256 lastRewardBlockTime; // Last block time that WIGOs distribution occurs.
        uint256 accWigoPerShare; // Accumulated WIGOs per share, times 1e12. See below.
    }

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    
    
    function poolLength() external view virtual returns (uint256);

    // View function to see pending WIGOs on frontend.
    function pendingWigo(uint256 _pid, address _user) external view virtual returns (uint256);

    // Deposit LP tokens to MasterFarmer for WIGO allocation.
    function deposit(uint256 _pid, uint256 _amount) public virtual;

    // Withdraw LP tokens from MasterFarmer.
    function withdraw(uint256 _pid, uint256 _amount) public virtual;

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public virtual;
}