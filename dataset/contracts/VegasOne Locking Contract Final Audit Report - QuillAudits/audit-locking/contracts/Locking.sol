// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Locking is ReentrancyGuard {
    using SafeERC20 for IERC20;

    event TimerStarted(uint256 _time, address _beneficiary);

    event TokenWithdrawn(address _beneficiary, uint256 _amount);

    event PendingGovernanceUpdated(address pendingGovernance);

    event GovernanceUpdated(address governance);

    address public governance;

    address public pendingGovernance;

    uint256 public totalDeposit;

    uint256 public totalWithdrawn;

    IERC20  public erc20Token;

    uint256 public startingTime;

    address public beneficiary;

    /// @dev Number of periods to wait before unlocking happens.
    uint256 public lockingPeriods;

    /// @dev Number of periods to linearly unlock locked token after locking periods.
    uint256 public withdrawPeriods;

    /// @dev Time for a period in block time unit.
    uint256 public periodLength;

    constructor(
        address _governance,
        IERC20 _erc20Token,
        uint256 _lockingPeriods,
        uint256 _withdrawPeriods,
        uint256 _periodLength
    ) {
        require(
            _governance != address(0),
            "Locking: governance address cannot be 0x0"
        );
        require(
            address(_erc20Token) != address(0),
            "Locking: erc20Token cannot be 0x0"
        );
        require(_periodLength != 0, "Locking: periodLength cannot be 0");
        governance = _governance;
        erc20Token = _erc20Token;
        lockingPeriods = _lockingPeriods;
        withdrawPeriods = _withdrawPeriods;
        periodLength = _periodLength;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "Locking: only governance");
        _;
    }

    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "Locking: only beneficiary");
        _;
    }

    /// @dev Sets the governance.
    ///
    /// This function can only called by the current governance.
    ///
    /// @param _pendingGovernance the new pending governance.
    function setPendingGovernance(address _pendingGovernance)
        external
        onlyGovernance
    {
        require(
            _pendingGovernance != address(0),
            "StakingPools: pending governance address cannot be 0x0"
        );
        pendingGovernance = _pendingGovernance;

        emit PendingGovernanceUpdated(_pendingGovernance);
    }

    /// @dev Accepts to be the governance
    ///
    /// The function can only be called by the current pending governance
    function acceptGovernance() external {
        require(
            msg.sender == pendingGovernance,
            "StakingPools: only pending governance"
        );

        governance = pendingGovernance;

        emit GovernanceUpdated(pendingGovernance);
    }

    /// @dev Starts the timer
    ///
    /// The function can only be called by the current governance.
    /// The function can only be called once.
    ///
    /// @param _time time in the future when the timer starts.
    /// @param _beneficiary the address that is allowed to claim the unlocked amount.
    function startTimer(uint256 _time, address _beneficiary) external onlyGovernance {
        require(_beneficiary != address(0), "Locking: beneficiary cannot be 0x0");
        require(startingTime == 0, "Locking: timer already started");
        require(
            block.timestamp <= _time,
            "Locking: timer can't start at the past"
        );
        totalDeposit = erc20Token.balanceOf(address(this));
        require(totalDeposit > 0, "Locking: no deposit yet for the beneficiary");

        startingTime = _time;
        beneficiary = _beneficiary;

        emit TimerStarted(_time, _beneficiary);
    }

    /// @dev Withdraws unlocked amount
    ///
    /// The funtion can only be called by the assigned beneficiary.
    ///
    /// @param _amount Claims _amount if unlocked amount is enough, claims all otherwise.
    function withdraw(uint256 _amount) external onlyBeneficiary nonReentrant {
        uint256 _amount_max = withdrawable();
        require(_amount_max > 0, "Locking: cannot withdraw yet");
        if (_amount > _amount_max) _amount = _amount_max;
        totalWithdrawn += _amount;
        erc20Token.safeTransfer(msg.sender, _amount);
        if (totalWithdrawn == totalDeposit) {
            totalDeposit = 0;
        }

        emit TokenWithdrawn(msg.sender, _amount);
    }

    /// @dev Gets the remain unlocked amount yet to be claimed.
    ///
    /// @return The remain unlocked amount.
    function withdrawable() public view returns (uint256) {
        if (block.timestamp <= startingTime) return 0;
        if (totalDeposit == 0) return 0;
        uint256 _periods = (block.timestamp - startingTime) / periodLength;
        if (_periods <= lockingPeriods) return 0;
        uint256 _amount = ((_periods - lockingPeriods) * totalDeposit) /
            withdrawPeriods;
        if (_amount > totalDeposit) _amount = totalDeposit;
        return _amount - totalWithdrawn;
    }
}
