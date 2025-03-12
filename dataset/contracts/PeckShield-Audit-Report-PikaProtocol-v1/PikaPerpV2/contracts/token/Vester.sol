pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./IPika.sol";

/**
 * @title Vester
 * @notice Support vesting esPIKA to PIKA token. A high fee is attached for short term claimer and the fee decreases linearly to reward long term claimer.
 */
contract Vester is Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    struct UserInfo {
        uint256 depositAmount;
        uint256 vestedUntil;
        uint256 vestingStartTime;
    }

    address public esPika;
    address public pika;
    address public treasury;
    uint256 public vestingPeriod = 365 days;
    uint256 public initialClaimFee = 8000; // 80%
    uint256 public totalEsPikaDeposit;
    uint256 public totalPikaClaimed;
    uint256 public totalClaimFee;
    mapping(address => uint256) private _balances;

    uint256 public constant FEE_BASE = 10000;

    /// @notice user => depositId => UserInfo
    mapping (address => mapping (uint256 => UserInfo)) public userInfo;
    /// @notice user => depositId[]
    mapping (address => EnumerableSet.UintSet) private allUserDepositIds;
    /// @notice user => deposit index
    mapping (address => uint256) public currentId;

    event Deposit(address indexed user, uint256 depositId, uint256 amount);
    event Withdraw(address indexed user, uint256 depositId, uint256 amount);
    event Claim(address indexed user, uint256 depositId, uint256 amountClaimed, uint256 claimFee);

    constructor(
        address _esPika,
        address _pika,
        address _treasury
    ) public {
        esPika = _esPika;
        pika = _pika;
        treasury = _treasury;
    }

    /** @notice Deposit esPIKA for vesting.
     */
    function deposit(uint256 _amount) external {
        IERC20(esPika).safeTransferFrom(msg.sender, address(this), _amount);
        (UserInfo storage user, uint256 depositId) = _addDeposit(msg.sender);
        totalEsPikaDeposit += _amount;
        user.depositAmount = _amount;
        user.vestedUntil = block.timestamp + vestingPeriod;
        user.vestingStartTime = block.timestamp;
        emit Deposit(msg.sender, depositId, _amount);
    }

    /**
     * @notice Withdraw the deposited esPIKA. The vesting is reset for the withdrawn amount.
     */
    function withdraw(uint256 _amount, uint256 _depositId) external {
        UserInfo storage user = userInfo[msg.sender][_depositId];
        require (user.depositAmount > 0, "nothing to withdraw");
        if(user.depositAmount < _amount) {
            _amount = user.depositAmount;
        }
        totalEsPikaDeposit -= _amount;
        user.depositAmount -= _amount;
        IERC20(esPika).safeTransfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _depositId, _amount);
    }

    /**
     * @notice Claim PIKA token from vesting. If the vesting is not completed, it is attached a fee,
     * which decreases linearly to 0 at the vesting completion time. The deposited esPIKA token is burned and
     * the fee is transferred to the treasury.
     */
    function claim(uint256 _depositId) public {
        UserInfo storage user = userInfo[msg.sender][_depositId];
        uint256 amountToClaim = claimable(msg.sender, _depositId);
        if (amountToClaim == 0) {
            return;
        }
        uint256 claimFee = user.depositAmount - amountToClaim;
        IPika(esPika).burn(user.depositAmount);
        totalPikaClaimed += amountToClaim;
        totalClaimFee += claimFee;
        user.depositAmount = 0;
        IERC20(pika).safeTransfer(msg.sender, amountToClaim);
        IERC20(pika).safeTransfer(treasury, claimFee);

        emit Claim(msg.sender, _depositId, amountToClaim, claimFee);
    }

    function claimAll() external {
        uint256[] memory depositIds = allUserDepositIds[msg.sender].values();
        for (uint256 i = 0; i < depositIds.length; i++) {
            claim(depositIds[i]);
        }
    }

    function claimable(address _account, uint256 _depositId) public view returns(uint256) {
        UserInfo memory user = userInfo[_account][_depositId];
        if (user.depositAmount == 0) {
            return 0;
        }
        if (block.timestamp < user.vestedUntil) {
            return user.depositAmount * (FEE_BASE - initialClaimFee) / FEE_BASE +
                user.depositAmount * initialClaimFee * (block.timestamp - user.vestingStartTime) / (FEE_BASE * vestingPeriod);
        }
        return user.depositAmount;
    }

    function claimableAll(address _account) external view returns(uint256 claimableAmount) {
        claimableAmount = 0;
        uint256 len = allUserDepositIds[_account].length();
        for (uint256 i = 0; i < len; i++) {
            uint256 depositId = allUserDepositIds[_account].at(i);
            claimableAmount += claimable(_account, depositId);
        }
    }

    function unvested(address _account, uint256 _depositId) public view returns(uint256) {
        UserInfo memory user = userInfo[_account][_depositId];
        return deposited(_account, _depositId) - claimable(_account, _depositId);
    }

    function unvestedAll(address _account) view external returns(uint256) {
        uint256 unvestedAllAmount = 0;
        uint256 len = allUserDepositIds[_account].length();
        for (uint256 i = 0; i < len; i++) {
            uint256 depositId = allUserDepositIds[_account].at(i);
            unvestedAllAmount += unvested(_account, depositId);
        }
        return unvestedAllAmount;
    }

    function deposited(address _account, uint256 _depositId) public view returns(uint256) {
        return userInfo[_account][_depositId].depositAmount;
    }

    function depositedAll(address _account) external view returns(uint256 depositedAllAmount) {
        depositedAllAmount = 0;
        uint256 len = allUserDepositIds[_account].length();
        for (uint256 i = 0; i < len; i++) {
            uint256 depositId = allUserDepositIds[_account].at(i);
            depositedAllAmount += deposited(_account, depositId);
        }
    }

    function getAllUserDepositIds(address _user) public view returns (uint256[] memory) {
        return allUserDepositIds[_user].values();
    }

    function _addDeposit(address _user) internal virtual returns (UserInfo storage user, uint256 newDepositId) {
        // start depositId from 1
        newDepositId = ++currentId[_user];
        allUserDepositIds[_user].add(newDepositId);
        user = userInfo[_user][newDepositId];
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }
}
