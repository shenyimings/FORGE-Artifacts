// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./interfaces/IGovernance.sol";
import "./interfaces/IGovernanceRegistry.sol";
import "./Delegator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TimeLock is Delegator {
    using SafeERC20 for IERC20;

    uint256 public lockPeriod = 2 weeks; // fixed lock period

    struct LockAgreement {
        uint256 amount;
        uint256 start;
        bool collected;
    }

    IERC20 public immutable asset; // KAP
    IGovernanceRegistry public immutable governanceRegistry;

    mapping(address => LockAgreement[]) public locks;
    mapping(address => uint256) public totalLocked;

    event Lock(address indexed user, uint256 depositId, uint256 amount);
    event Unlock(address indexed user, uint256 depositId, uint256 amount);

    constructor(address _asset, address _governanceRegistry) {
        require(_asset != address(0), "TimeLock: Zero address");
        require(_governanceRegistry != address(0), "TimeLock: Zero address");

        asset = IERC20(_asset);
        governanceRegistry = IGovernanceRegistry(_governanceRegistry);
    }

    function lock(uint256 amount) external {
        require(amount > 0, "TimeLock: zero amount");

        _undelegateAlways(msg.sender);

        locks[msg.sender].push(
            LockAgreement({
                amount: amount,
                start: block.timestamp,
                collected: false
            })
        );
        totalLocked[msg.sender] += amount;
        emit Lock(msg.sender, locks[msg.sender].length - 1, amount);

        asset.safeTransferFrom(msg.sender, address(this), amount);
    }

    function unlock(uint256 depositId) external {
        LockAgreement storage lockAgreement = locks[msg.sender][depositId];
        uint256 amount = lockAgreement.amount;

        require(!lockAgreement.collected, "TimeLock: already collected");
        require(
            block.timestamp > lockAgreement.start + lockPeriod,
            "TimeLock: early collect"
        );

        if (delegates[msg.sender] != address(0)) {
            _undelegate(msg.sender);
        }

        totalLocked[msg.sender] -= amount;
        lockAgreement.collected = true;
        emit Unlock(msg.sender, depositId, amount);

        asset.safeTransfer(msg.sender, amount);
    }

    function _balances(address account)
        internal
        view
        override
        returns (uint256)
    {
        return totalLocked[account];
    }

    function appointDelegate(address delegate) external {
        uint256 votingPeriod = IGovernance(governanceRegistry.governance())
            .votingPeriod();
        _appointDelegate(msg.sender, delegate, votingPeriod);
    }

    function undelegate() external {
        _undelegate(msg.sender);
    }

    function updateLockPeriod(uint256 newLockPeriod) external {
        require(newLockPeriod > 0, "TimeLock: invalid lock period");
        require(
            msg.sender == governanceRegistry.governance(),
            "TimeLock: Only governance"
        );
        lockPeriod = newLockPeriod;
    }
}
