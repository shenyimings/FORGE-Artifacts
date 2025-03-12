// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../access/Governable.sol";
import "../perp/IPikaPerp.sol";
import "./IVaultReward.sol";

contract PikaStaking is Governable, ReentrancyGuard, Pausable {

    using SafeERC20 for IERC20;
    using Address for address payable;

    address public owner;
    address public stakingToken;

    uint256 public stakingPeriod;
    uint256 private _totalSupply;

    address[] public rewardPools;

    mapping(address => uint256) private _balances;
    mapping(address => uint256) public stakeTimestamp;

    uint256 public constant PRECISION = 10**18;
    event OwnerSet(address owner);
    event StakingPeriodSet(uint256 stakingPeriodSet);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(address _stakingToken, uint256 _stakingPeriod) {
        owner = msg.sender;
        stakingToken = _stakingToken;
        stakingPeriod = _stakingPeriod;
    }

    // Views methods

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    // Governance methods

    function setOwner(address _owner) external onlyGov {
        owner = _owner;
        emit OwnerSet(owner);
    }

    function setStakingPeriod(uint256 _stakingPeriod) external onlyOwner {
        stakingPeriod = _stakingPeriod;
        emit StakingPeriodSet(stakingPeriod);
    }

    function setRewardPools(address[] memory _rewardPools) external onlyOwner {
        rewardPools = _rewardPools;
    }

    // Methods

    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Cannot stake 0");
        updateReward(msg.sender);
        _totalSupply += amount;
        _balances[msg.sender] += amount;
        IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), amount);
        stakeTimestamp[msg.sender] = block.timestamp;
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant {
        require(amount > 0, "Cannot withdraw 0");
        uint256 timeDiff = block.timestamp - stakeTimestamp[msg.sender];
        require(timeDiff > uint256(stakingPeriod), "!period");
        updateReward(msg.sender);
        stakeTimestamp[msg.sender] = 0;
        _totalSupply -= amount;
        _balances[msg.sender] -= amount;
        IERC20(stakingToken).safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function withdrawAll() external {
        withdraw(_balances[msg.sender]);
    }

    function updateReward(address account) public {
        for (uint256 i = 0; i < rewardPools.length; i++) {
            IVaultReward(rewardPools[i]).updateReward(msg.sender);
        }
    }

    fallback() external payable {}
    receive() external payable {}

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }
}
