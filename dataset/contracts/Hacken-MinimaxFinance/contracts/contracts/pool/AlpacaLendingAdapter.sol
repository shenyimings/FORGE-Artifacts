// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPoolAdapter.sol";

interface IAlpacaLendingVault {
    function deposit(uint256 amountToken) external payable;

    function withdraw(uint256 share) external;

    function fairLaunchPoolId() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function totalToken() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function token() external view returns (address);
}

struct UserInfo {
    uint256 amount; // How many Staking tokens the user has provided.
    uint256 rewardDebt; // Reward debt. See explanation below.
    uint256 bonusDebt; // Last block that user exec something to the pool.
    address fundedBy; // Funded by who?
    //
    // We do some fancy math here. Basically, any point in time, the amount of ALPACAs
    // entitled to a user but is pending to be distributed is:
    //
    //   pending reward = (user.amount * pool.accAlpacaPerShare) - user.rewardDebt
    //
    // Whenever a user deposits or withdraws Staking tokens to a pool. Here's what happens:
    //   1. The pool's `accAlpacaPerShare` (and `lastRewardBlock`) gets updated.
    //   2. User receives the pending reward sent to his/her address.
    //   3. User's `amount` gets updated.
    //   4. User's `rewardDebt` gets updated.
}

// Info of each pool.
struct PoolInfo {
    address stakeToken; // Address of Staking token contract.
    uint256 allocPoint; // How many allocation points assigned to this pool. ALPACAs to distribute per block.
    uint256 lastRewardBlock; // Last block number that ALPACAs distribution occurs.
    uint256 accAlpacaPerShare; // Accumulated ALPACAs per share, times 1e12. See below.
    uint256 accAlpacaPerShareTilBonusEnd; // Accumated ALPACAs per share until Bonus End.
}

interface IFairLaunch {
    function pendingAlpaca(uint256 _pid, address _user) external view returns (uint256);

    function deposit(
        address _for,
        uint256 _pid,
        uint256 _amount
    ) external;

    function withdraw(
        address _for,
        uint256 _pid,
        uint256 _amount
    ) external;

    function withdrawAll(address _for, uint256 _pid) external;

    function userInfo(uint256 _pid, address _user) external view returns (UserInfo memory);

    function poolLength() external view returns (uint256);

    function poolInfo(uint256 pid) external view returns (PoolInfo memory);
}

contract AlpacaLendingAdapter is IPoolAdapter {
    address public immutable fairLaunch;
    address public immutable alpacaToken;

    constructor(address _fairLaunch, address _alpacaToken) {
        fairLaunch = _fairLaunch;
        alpacaToken = _alpacaToken;
    }

    function getPoolIdByAddress(address pool) private returns (uint256) {
        uint256 poolLength = IFairLaunch(fairLaunch).poolLength();
        for (uint256 pid = 0; pid < poolLength; pid++) {
            PoolInfo memory info = IFairLaunch(fairLaunch).poolInfo(pid);
            if (info.stakeToken == pool) {
                return pid;
            }
        }
        return poolLength;
    }

    function stakingBalance(address pool, bytes memory) external returns (uint256) {
        // args should contain staked token address
        IAlpacaLendingVault vault = IAlpacaLendingVault(pool);

        uint256 pid = getPoolIdByAddress(pool);

        UserInfo memory info = IFairLaunch(fairLaunch).userInfo(pid, address(this));
        uint256 ibTokenAmount = info.amount;

        uint256 underlyingTokenAmount = (vault.totalToken() * ibTokenAmount) / vault.totalSupply();
        return underlyingTokenAmount;
    }

    function rewardBalance(address, bytes memory) external returns (uint256) {
        return 0;
    }

    function deposit(
        address pool,
        uint256 amount,
        bytes memory
    ) external {
        IAlpacaLendingVault vault = IAlpacaLendingVault(pool);
        vault.deposit(amount);
        uint256 pid = getPoolIdByAddress(pool);
        uint256 ibTokenAmount = IERC20(pool).balanceOf(address(this));

        IERC20(pool).approve(fairLaunch, ibTokenAmount);
        IFairLaunch(fairLaunch).deposit(address(this), pid, ibTokenAmount);
    }

    function withdraw(
        address pool,
        uint256 amount,
        bytes memory
    ) external {
        IAlpacaLendingVault vault = IAlpacaLendingVault(pool);
        uint256 ibTokenAmount = (amount * vault.totalSupply()) / vault.totalToken();
        uint256 pid = getPoolIdByAddress(pool);

        IFairLaunch(fairLaunch).withdraw(address(this), pid, ibTokenAmount);
        IAlpacaLendingVault(pool).withdraw(ibTokenAmount);
    }

    function withdrawAll(address pool, bytes memory) external {
        IAlpacaLendingVault vault = IAlpacaLendingVault(pool);
        uint256 pid = getPoolIdByAddress(pool);
        IFairLaunch(fairLaunch).withdrawAll(address(this), pid);

        uint256 ibTokenAmount = vault.balanceOf(address(this));
        vault.withdraw(ibTokenAmount);
        // TODO: convert alpaca or show it as a reward token
    }

    function stakedToken(address pool, bytes memory) external returns (address) {
        return IAlpacaLendingVault(pool).token();
    }

    function rewardToken(address pool, bytes memory) external returns (address) {
        return IAlpacaLendingVault(pool).token();
    }
}
