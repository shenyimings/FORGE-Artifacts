pragma solidity 0.5.16;

import "openzeppelin-solidity-2.3.0/contracts/token/ERC20/IERC20.sol";

// Making the original MasterChef as an interface leads to compilation fail.
// Use Contract instead of Interface here
contract IBakeMaster {
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        uint256 allocPoint; // How many allocation points assigned to this pool. Cakes to distribute per block.
        uint256 lastRewardBlock; // Last block number that Cakes distribution occurs.
        uint256 accBakePerShare; // Accumulated Cakes per share, times 1e12. See below.
        bool exists; // 
    }

    address public bake;

    // Info of each pool.
    mapping(address => PoolInfo) public poolInfoMap;
    // Info of each user that stakes LP tokens.
    mapping(address => mapping(address => UserInfo)) public poolUserInfoMap;

    // Deposit LP tokens to BakeryMaster for BAKE allocation.
    function deposit(address _pair, uint256 _amount) external {}

    // Withdraw LP tokens from BakeryMaster.
    function withdraw(address _pair, uint256 _amount) external {}
}
