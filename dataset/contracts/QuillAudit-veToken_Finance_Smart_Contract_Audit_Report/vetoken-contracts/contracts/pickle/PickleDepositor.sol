// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../Interfaces/Interfaces.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract PickleDepositor {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public constant pickle = address(0x429881672B9AE42b8EbA0E26cD9C73711b891Ca5);
    address public constant escrow = address(0xbBCf169eE191A1Ba7371F30A1C344bFC498b29Cf);
    uint256 private constant MAXTIME = 4 * 364 * 86400;
    uint256 private constant WEEK = 7 * 86400;

    uint256 public lockIncentive = 10; //incentive to users who spend gas to lock pickle
    uint256 public constant FEE_DENOMINATOR = 10000;

    address public feeManager;
    address public immutable staker;
    address public immutable minter;
    uint256 public incentivePickle = 0;
    uint256 public unlockTime;

    constructor(address _staker, address _minter) public {
        staker = _staker;
        minter = _minter;
        feeManager = msg.sender;
    }

    function setFeeManager(address _feeManager) external {
        require(msg.sender == feeManager, "!auth");
        feeManager = _feeManager;
    }

    function setFees(uint256 _lockIncentive) external {
        require(msg.sender == feeManager, "!auth");

        if (_lockIncentive >= 0 && _lockIncentive <= 30) {
            lockIncentive = _lockIncentive;
        }
    }

    function initialLock() external {
        require(msg.sender == feeManager, "!auth");

        uint256 vepickle = IERC20(escrow).balanceOf(staker);
        if (vepickle == 0) {
            uint256 unlockAt = block.timestamp + MAXTIME;
            uint256 unlockInWeeks = (unlockAt / WEEK) * WEEK;

            //release old lock if exists
            IStaker(staker).release();
            //create new lock
            uint256 pickleBalanceStaker = IERC20(pickle).balanceOf(staker);
            IStaker(staker).createLock(pickleBalanceStaker, unlockAt);
            unlockTime = unlockInWeeks;
        }
    }

    //lock pickle
    function _lockPickle() internal {
        uint256 pickleBalance = IERC20(pickle).balanceOf(address(this));
        if (pickleBalance > 0) {
            IERC20(pickle).safeTransfer(staker, pickleBalance);
        }

        //increase ammount
        uint256 pickleBalanceStaker = IERC20(pickle).balanceOf(staker);
        if (pickleBalanceStaker == 0) {
            return;
        }

        //increase amount
        IStaker(staker).increaseAmount(pickleBalanceStaker);

        uint256 unlockAt = block.timestamp + MAXTIME;
        uint256 unlockInWeeks = (unlockAt / WEEK) * WEEK;

        //increase time too if over 2 week buffer
        if (unlockInWeeks.sub(unlockTime) > 2) {
            IStaker(staker).increaseTime(unlockAt);
            unlockTime = unlockInWeeks;
        }
    }

    function lockPickle() external {
        _lockPickle();

        //mint incentives
        if (incentivePickle > 0) {
            ITokenMinter(minter).mint(msg.sender, incentivePickle);
            incentivePickle = 0;
        }
    }

    //deposit pickle for vtDill
    //can locking immediately or defer locking to someone else by paying a fee.
    //while users can choose to lock or defer, this is mostly in place so that
    //the vetoken reward contract isnt costly to claim rewards
    function deposit(
        uint256 _amount,
        bool _lock,
        address _stakeAddress
    ) public {
        require(_amount > 0, "!>0");

        if (_lock) {
            //lock immediately, transfer directly to staker to skip an erc20 transfer
            IERC20(pickle).safeTransferFrom(msg.sender, staker, _amount);
            _lockPickle();
            if (incentivePickle > 0) {
                //add the incentive tokens here so they can be staked together
                _amount = _amount.add(incentivePickle);
                incentivePickle = 0;
            }
        } else {
            //move tokens here
            IERC20(pickle).safeTransferFrom(msg.sender, address(this), _amount);
            //defer lock cost to another user
            uint256 callIncentive = _amount.mul(lockIncentive).div(FEE_DENOMINATOR);
            _amount = _amount.sub(callIncentive);

            //add to a pool for lock caller
            incentivePickle = incentivePickle.add(callIncentive);
        }

        bool depositOnly = _stakeAddress == address(0);
        if (depositOnly) {
            //mint for msg.sender
            ITokenMinter(minter).mint(msg.sender, _amount);
        } else {
            //mint here
            ITokenMinter(minter).mint(address(this), _amount);
            //stake for msg.sender
            IERC20(minter).safeApprove(_stakeAddress, 0);
            IERC20(minter).safeApprove(_stakeAddress, _amount);
            IRewards(_stakeAddress).stakeFor(msg.sender, _amount);
        }
    }

    function deposit(uint256 _amount, bool _lock) external {
        deposit(_amount, _lock, address(0));
    }

    function depositAll(bool _lock, address _stakeAddress) external {
        uint256 pickleBal = IERC20(pickle).balanceOf(msg.sender);
        deposit(pickleBal, _lock, _stakeAddress);
    }
}
