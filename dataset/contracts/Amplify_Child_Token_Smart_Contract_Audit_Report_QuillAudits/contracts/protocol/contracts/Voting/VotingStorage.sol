// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import { IERC20 } from "../ERC20/IERC20.sol";
import { SmartWalletChecker } from "../utils/SmartWalletWhitelist.sol";

abstract contract VotingStorage {

     /// @notice EIP-20 token name for this token
    string public name;

    /// @notice EIP-20 token symbol for this token
    string public symbol;

    /**
     * @dev Returns the amount of locked tokens in existence.
    */
    uint256 public totalLocked;
    uint256 public rewardLocked;

    
    struct Point {
        int256 bias;
        int256 slope;
        uint256 ts;
        uint256 block;
    }

    uint256 public epoch;
    mapping(uint256 => Point) public pointHistory;
    mapping(uint256 => int256) public slopeChanges; // timestamp => slope change

    mapping(address => mapping(uint256 => Point)) public userPointHistory;
    mapping(address => uint256) public userPointEpoch;

    struct RewardEntry {
        uint256 start;
        uint256 end;
        uint256 amount;
        uint16 rate;
    }

    struct Lock {
        uint256 amount;
        uint256 end;
        address owner;
        address delegator;
        RewardEntry[] rewardEntries;
    }

    mapping(address => Lock) public locks;
    
    /**
     * Minimum staking period for specific rate
     * schedules should set from longest to shortest period
     * to meet getRateByPeriod method looping
     */
    struct RateSchedule {
        uint256 period;
        uint16 rate;
    }
    RateSchedule[] public rateSchedules;

    mapping(address => address[]) public delegations;
    mapping(address => mapping(address => uint256)) internal delegationIndexInMap;

    uint256 internal constant WEEK = 604800; // 7 * 24 * 3600;
    uint256 internal constant MAXCAP = 126144000; // 4 * 365 * 24 * 3600;

    /// @notice A record of states for signing / validating signatures
    mapping (address => uint256) public nonces;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    IERC20 public amptToken;
    SmartWalletChecker public smartWalletChecker;
}
