// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../interfaces/tokenomics/ICNCToken.sol";
import "../../interfaces/tokenomics/ICNCVoteLocker.sol";

contract CNCVoteLocker is ICNCVoteLocker, Ownable {
    using SafeERC20 for ICNCToken;
    using SafeERC20 for IERC20;
    struct VoteLock {
        uint256 amount;
        uint256 unlockTime;
    }

    uint256 public constant UNLOCK_DELAY = 120 days;

    ICNCToken public immutable cncToken;

    mapping(address => uint256) public lockedBalance;
    mapping(address => VoteLock[]) public voteLocks;
    uint256 public totalLocked;
    bool public isShutdown;
    address public immutable treasury;

    constructor(address _cncToken, address _treasury) Ownable() {
        cncToken = ICNCToken(_cncToken);
        treasury = _treasury;
    }

    function lock(uint256 amount) external override {
        lock(amount, true);
    }

    function lock(uint256 amount, bool relock) public override {
        require(!isShutdown, "locker suspended");
        cncToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 unlockTime = block.timestamp + UNLOCK_DELAY;

        if (relock) {
            delete voteLocks[msg.sender];
            voteLocks[msg.sender].push(VoteLock(lockedBalance[msg.sender] + amount, unlockTime));
        } else {
            voteLocks[msg.sender].push(VoteLock(amount, unlockTime));
        }
        totalLocked += amount;
        lockedBalance[msg.sender] += amount;
        emit Locked(msg.sender, amount, unlockTime, relock);
    }

    function shutDown() external override onlyOwner {
        require(!isShutdown, "Locker already suspended");
        isShutdown = true;
    }

    function recoverToken(address token) external override {
        require(token != address(cncToken), "Cannot withdraw CNC token");
        IERC20 _token = IERC20(token);
        _token.safeTransfer(treasury, _token.balanceOf(address(this)));
    }

    function executeAvailableUnlocks() external override returns (uint256) {
        uint256 sumUnlockable = 0;
        VoteLock[] storage _pending = voteLocks[msg.sender];
        uint256 i = _pending.length;
        while (i > 0) {
            i = i - 1;
            if (_pending[i].unlockTime <= block.timestamp) {
                sumUnlockable += _pending[i].amount;

                _pending[i] = _pending[_pending.length - 1];

                _pending.pop();
            }
        }
        totalLocked -= sumUnlockable;
        lockedBalance[msg.sender] -= sumUnlockable;
        cncToken.safeTransfer(msg.sender, sumUnlockable);
        emit UnlockExecuted(msg.sender, sumUnlockable);
        return sumUnlockable;
    }

    function unlockableBalance(address user) public view override returns (uint256) {
        uint256 sumUnlockable = 0;
        VoteLock[] storage _pending = voteLocks[user];
        uint256 length = _pending.length;
        uint256 i = length;
        while (i > 0) {
            i = i - 1;
            if (_pending[i].unlockTime <= block.timestamp) {
                sumUnlockable += _pending[i].amount;
            }
        }
        return sumUnlockable;
    }

    function balanceOf(address user) external view override returns (uint256) {
        return lockedBalance[user] - unlockableBalance(user);
    }
}
