pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract Account {
    struct State {
        uint256 staked; //LP or cook
        uint256 phantom;
        Vesting[] vestings;
        Vesting[] stakings;
        uint256 claimed; //cook
        // blacklisted beneficiary,
        // 1. the address won't be able to claim/harvest/zap rewarded cook,
        // 2. blacklisted address can withdraw their LP token immmediately
        // 3. blacklisted address won't receive anymore rewarded cook
        bool isBlacklisted;
    }
}

struct Vesting {
    uint256 start;
    uint256 amount; //cook
}

contract Storage {
    struct Provider {
        IERC20 cook;
        IERC20 univ2;
    }

    struct Balance {
        uint256 staked; //LP
        uint256 rewarded; //cook
        uint256 claimed; //cook
        uint256 vesting; //cook
        uint256 phantom;
    }

    struct State {
        Balance balance;
        Provider provider;
        uint256 lastRewardBlock;
        mapping(address => Account.State) accounts;
        // Fields for Admin

        // stop everyone from
        // 1. stop accepting more LP token into pool,
        // 2. stop take any zapping
        // 3. stop claim/harvest/zap rewarded cook
        // 4. stop distributing cook reward
        bool pauseMinig;

        // Mining cook reward per block
        uint256 REWARD_PER_BLOCK;
        // pool cap limit, 0 will be unlimited
        uint256 totalPoolCapLimit;
        // stake limit per address, 0 will be unlimited
        uint256 stakeLimitPerAddress;
    }
}

contract PoolState is Ownable, AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    Storage.State _state;
}
