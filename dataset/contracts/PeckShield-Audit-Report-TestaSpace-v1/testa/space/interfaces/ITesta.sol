pragma solidity 0.5.16;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "openzeppelin-solidity-2.3.0/contracts/token/ERC20/IERC20.sol";

// Making the original Testa as an interface leads to compilation fail.
// Use Contract instead of Interface here
contract ITesta {
    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        mapping (uint256 => uint256) pendingTesta;
        mapping (uint256 => uint256) rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        IUniswapV2Pair uniswap;
        uint112 startLiquidity;
        uint256 allocPoint;       // How many allocation points assigned to this pool. Testa to distribute per block.
        uint256 lastRewardBlock;  // Last block number that Testa distribution occurs.
        uint256 accTestaPerShare; // Accumulated Testa per share, times 1e18. See below.
        uint256 debtIndexKey;
        uint256 startBlock;
        uint256 initStartBlock;
    }

    // The Testa TOKEN!
    address public testa;
    
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    function harvestAndWithdraw(uint256 _pid, uint256 _amount) external {}

    function harvest(uint256 _pid) external {}

    // Deposit LP tokens to Testa for SUSHI allocation.
    function deposit(uint256 _pid, uint256 _amount) external {}

    // Withdraw LP tokens from Testa.
    function withdraw(uint256 _pid, uint256 _amount) external {}
}
