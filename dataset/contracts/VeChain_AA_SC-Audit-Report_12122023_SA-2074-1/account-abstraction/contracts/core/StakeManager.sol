// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.12;

import "../interfaces/IStakeManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/* solhint-disable avoid-low-level-calls */
/* solhint-disable not-rely-on-time */
/**
 * manage deposits and stakes.
 * deposit is just a balance used to pay for UserOperations (either by a paymaster or an account)
 * stake is value locked for at least "unstakeDelay" by a paymaster.
 */
abstract contract StakeManager is IStakeManager {
    address public constant VTHO_TOKEN_ADDRESS = 0x0000000000000000000000000000456E65726779;
    IERC20 public constant VTHO_TOKEN_CONTRACT = IERC20(VTHO_TOKEN_ADDRESS);

    /// maps paymaster to their deposits and stakes
    mapping(address => DepositInfo) public deposits;

    /// @inheritdoc IStakeManager
    function getDepositInfo(address account) public view returns (DepositInfo memory info) {
        return deposits[account];
    }

    // internal method to return just the stake info
    function _getStakeInfo(address addr) internal view returns (StakeInfo memory info) {
        DepositInfo storage depositInfo = deposits[addr];
        info.stake = depositInfo.stake;
        info.unstakeDelaySec = depositInfo.unstakeDelaySec;
    }

    /// return the deposit (for gas payment) of the account
    function balanceOf(address account) public view returns (uint256) {
        return deposits[account].deposit;
    }
            
    /// Disable transfers into EntryPoint
    receive() external payable {
        revert("entrypoint cannot receive VET");
    }

    /// Disable transfers into EntryPoint
    fallback() external payable {
        revert("entrypoint fallback with VET");
    }

    function _incrementDeposit(address account, uint256 amount) internal {
        DepositInfo storage info = deposits[account];
        uint256 newAmount = info.deposit + amount;
        require(newAmount <= type(uint112).max, "deposit overflow");
        info.deposit = uint112(newAmount);
    }

    /// Stake the full amount of VTHO approved by the sender
    function addStake(uint32 _unstakeDelaySec) external {
        uint256 allowance = VTHO_TOKEN_CONTRACT.allowance(msg.sender, address(this));
        _addStakeAmount(_unstakeDelaySec, allowance); 
    }

    /// Stake a fixed amount of VTHO approved by the sender
    function addStakeAmount(uint32 _unstakeDelaySec, uint256 amount) external {
        uint256 allowance = VTHO_TOKEN_CONTRACT.allowance(msg.sender, address(this));
        require(amount <= allowance, "amount to stake > allowance");
        _addStakeAmount(_unstakeDelaySec, amount); 
    }

    function _addStakeAmount(uint32 _unstakeDelaySec, uint256 amount) internal {
        // Check `amount`
        require(amount > 0, "amount to stake == 0");

        // Check `_unstakeDelaySec`
        require(_unstakeDelaySec > 0, "must specify unstake delay");
        DepositInfo storage info = deposits[msg.sender];
        require(_unstakeDelaySec >= info.unstakeDelaySec, "cannot decrease unstake time");

        // Check for overflow
        uint256 stake = info.stake + amount;
        require(stake <= type(uint112).max, "stake overflow");

        // Check successfull transfer
        require(VTHO_TOKEN_CONTRACT.transferFrom(msg.sender, address(this), amount), "stake token transfer failed");
        
        // Update `deposits` and emit
        deposits[msg.sender] = DepositInfo(
            info.deposit,
            true,
            uint112(stake),
            _unstakeDelaySec,
            0
        );
        emit StakeLocked(msg.sender, stake, _unstakeDelaySec);
    }

    /// Deposit the full amount of VTHO approved by the sender, to the specified account
    function depositTo(address account) external {
        uint256 allowance = VTHO_TOKEN_CONTRACT.allowance(msg.sender, address(this));
        _depositAmountTo(account, allowance);
    }

    /// Deposit a fixed amount of VTHO approved by the sender, to the specified account
    function depositAmountTo(address account, uint256 amount) external {
        uint256 allowance = VTHO_TOKEN_CONTRACT.allowance(msg.sender, address(this));
        require(amount <= allowance, "amount to deposit > allowance");
        _depositAmountTo(account, amount);
    }

    function _depositAmountTo(address account, uint256 amount) internal {
        // Check amout
        require(amount > 0, "amount to deposit == 0");

        // Check overflow
        DepositInfo storage info = deposits[account];
        uint256 newAmount = info.deposit + amount;
        require(newAmount <= type(uint112).max, "deposit overflow");

        // Check successfull transfer
        require(VTHO_TOKEN_CONTRACT.transferFrom(msg.sender, address(this), amount), "deposit token transfer failed");
        
        // Update `desposits` and emit
        info.deposit = uint112(newAmount);
        emit Deposited(account, info.deposit);
    }

    /**
     * attempt to unlock the stake.
     * the value can be withdrawn (using withdrawStake) after the unstake delay.
     */
    function unlockStake() external {
        DepositInfo storage info = deposits[msg.sender];
        require(info.unstakeDelaySec != 0, "not staked");
        require(info.staked, "already unstaking");
        uint48 withdrawTime = uint48(block.timestamp) + info.unstakeDelaySec;
        info.withdrawTime = withdrawTime;
        info.staked = false;
        emit StakeUnlocked(msg.sender, withdrawTime);
    }


    /**
     * withdraw from the (unlocked) stake.
     * must first call unlockStake and wait for the unstakeDelay to pass
     * @param withdrawAddress the address to send withdrawn value.
     */
    function withdrawStake(address withdrawAddress) external {
        DepositInfo storage info = deposits[msg.sender];
        uint256 stake = info.stake;
        require(stake > 0, "No stake to withdraw");
        require(info.withdrawTime > 0, "must call unlockStake() first");
        require(info.withdrawTime <= block.timestamp, "Stake withdrawal is not due");
        info.unstakeDelaySec = 0;
        info.withdrawTime = 0;
        info.stake = 0;
        emit StakeWithdrawn(msg.sender, withdrawAddress, stake);
        require(VTHO_TOKEN_CONTRACT.transfer(withdrawAddress, stake), "failed to withdraw stake");
    }

    /**
     * withdraw from the deposit.
     * @param withdrawAddress the address to send withdrawn value.
     * @param withdrawAmount the amount to withdraw.
     */
    function withdrawTo(address withdrawAddress, uint256 withdrawAmount) external {
        DepositInfo storage info = deposits[msg.sender];
        require(withdrawAmount <= info.deposit, "Withdraw amount too large");
        info.deposit = uint112(info.deposit - withdrawAmount);
        emit Withdrawn(msg.sender, withdrawAddress, withdrawAmount);
        require(VTHO_TOKEN_CONTRACT.transfer(withdrawAddress, withdrawAmount), "failed to withdraw stake");
    }
}
