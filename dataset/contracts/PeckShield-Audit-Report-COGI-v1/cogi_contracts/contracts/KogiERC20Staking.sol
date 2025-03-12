// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./common/interfaces/IERC20Mintable.sol";

/**
 * @title KOGI ERC20 Staking
 * @author KOGI Inc
 */
contract KogiERC20Staking is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    event Deposited(
        address indexed sender,
        uint256 indexed id,
        uint256 amount,
        uint256 balance,
        uint256 rate,
        uint256 now
    );

    event WithdrawalRequested(address indexed sender, uint256 indexed id);

    event Withdrawn(
        address indexed sender,
        uint256 indexed id,
        uint256 amount,
        uint256 fee,
        uint256 balance,
        uint256 rate,
        uint256 period
    );

    uint256 private constant YEAR = 365 days;

    address public liquidityProviderAddress;
    uint256 public fee;
    uint256 public withdrawalLockDuration;
    uint256 public withdrawalUnlockDuration;

    mapping (address => mapping (uint256 => uint256)) public balances;
    mapping (address => mapping (uint256 => uint256)) public depositDates;
    mapping (address => mapping (uint256 => uint256)) public withdrawalRequestsDates;
    mapping (address => uint256[]) public depositIds;
    mapping (address => uint256) public lastDepositIds;
    uint256 public totalStaked;
    uint256 public totalHolders;

    bool private locked;
    IERC20Mintable public token;
    uint256 rate;

    struct Deposit {
        uint256 id;
        uint256 balance;
        uint256 date;
    }

    function initialize(
        address _tokenAddress,
        address _liquidityProviderAddress,
        uint256 _fee,
        uint256 _withdrawalLockDuration,
        uint256 _withdrawalUnlockDuration,
        uint256 _rate
    ) external initializer {
        __Ownable_init();
        token = IERC20Mintable(_tokenAddress);
        liquidityProviderAddress = _liquidityProviderAddress;
        fee = _fee;
        withdrawalLockDuration = _withdrawalLockDuration;
        withdrawalUnlockDuration = _withdrawalUnlockDuration;
        rate = _rate;
    }

    function balanceOf(address _account) external view returns (uint256){
        uint256 ret = 0;
        for(uint index=0; index<depositIds[_account].length; index++){
            ret += balances[_account][index];
        }
        return ret;
    }

    function depositOf(address _account) external view returns (Deposit[] memory){
        Deposit[] memory ret;
        uint256 id;
        for(uint i=0; i<depositIds[_account].length; i++){
            id = depositIds[_account][i];
            ret[id] = Deposit(
                id,
                balances[_account][id],
                depositDates[_account][id]
            );
        }
        return ret;
    }

    function deposit(uint256 _amount) public {
        require(_amount > 0, "deposit amount should be more than 0");
        uint256 _depositId = ++lastDepositIds[_msgSender()];
        _deposit(_msgSender(), _depositId, _amount);
        _setLocked(true);
        require(token.transferFrom(_msgSender(), address(this), _amount), "transfer failed");
        _setLocked(false);
    }

    function requestWithdrawal(uint256 _depositId) external {
        require(_depositId > 0 && _depositId <= lastDepositIds[_msgSender()], "wrong deposit id");
        withdrawalRequestsDates[_msgSender()][_depositId] = _now();
        emit WithdrawalRequested(_msgSender(), _depositId);
    }

    function withdrawal(uint256 _depositId, uint256 _amount) public {
        uint256 requestDate = withdrawalRequestsDates[_msgSender()][_depositId];
        require(requestDate > 0, "withdrawal wasn't requested");
        uint256 timestamp = _now();
        uint256 lockEnd = requestDate + withdrawalLockDuration;
        require(timestamp >= lockEnd, "too early");
        require(timestamp < lockEnd + withdrawalUnlockDuration, "too late");
        withdrawalRequestsDates[_msgSender()][_depositId] = 0;
        _withdraw(_msgSender(), _depositId, _amount, false);
    }
    
    function withdrawalEarly(uint256 _depositId, uint256 _amount) public {
        _withdraw(_msgSender(), _depositId, _amount, true);
    }

    function getProfit(
        uint256 _depositDate,
        uint256 _amount
    ) public view returns (uint256 userShare, uint256 timePassed) {
        if (_amount == 0 || _depositDate == 0) return (0, 0);
        timePassed = _now() - _depositDate;
        if (timePassed == 0) return (0, 0);
        userShare = _amount * timePassed * rate / 100 / YEAR * 1 ether;
    }

    function addDepositIds(address _sender, uint256 _id) internal{
        if(depositIds[_sender].length == 0){
            totalHolders ++;
        }
        depositIds[_sender].push(_id);
    }
    
    function removeDepositIdsAt(address _sender, uint256 _index) internal{
        if (_index == depositIds[_sender].length - 1) {
            depositIds[_sender].pop();
        } else {
            for (uint i = _index; i < depositIds[_sender].length - 1; i++) {
                depositIds[_sender][i] = depositIds[_sender][i + 1];
            }
            depositIds[_sender].pop();
        }
    }

    function removeDepositIds(address _sender, uint256 _id) internal{
        for (uint _index = 0; _index < depositIds[_sender].length-1; _index++) {
            if(depositIds[_sender][_index] == _id){
                removeDepositIdsAt(_sender, _id);                
                break;
            }
        }

        if (depositIds[_sender].length == 0){
            totalHolders --;
        }
    }

    function _deposit(address _sender, uint256 _id, uint256 _amount) internal nonReentrant {
        uint256 newBalance = balances[_sender][_id] + _amount;        
        balances[_sender][_id] = newBalance;
        totalStaked = totalStaked + _amount;
        depositDates[_sender][_id] = _now();
        addDepositIds(_sender, _id);                
        emit Deposited(_sender, _id, _amount, newBalance, rate, _now());
    }

    function _withdraw(address _sender, uint256 _id, uint256 _amount, bool _forced) internal nonReentrant {
        require(_id > 0 && _id <= lastDepositIds[_sender], "wrong deposit id");
        require(balances[_sender][_id] > 0 && balances[_sender][_id] >= _amount, "insufficient funds");
        _amount = (_amount == 0 ? balances[_sender][_id] : _amount);//0 withdraw max
        (uint256 userShare, uint256 timePassed) = getProfit(depositDates[_sender][_id], _amount);
        uint256 amount = userShare + _amount;
        uint256 feeValue = 0;
        if (_forced) {
            feeValue = amount / fee / 1 ether;
            amount = amount - feeValue;
            if(feeValue > userShare){
                require(token.transfer(liquidityProviderAddress, feeValue - userShare), "transfer failed");
            }            
        }
        if(userShare > feeValue){
            require(token.transferFrom(liquidityProviderAddress, address(this), userShare - feeValue), "transfer failed");
        }
        require(token.transfer(_sender, amount), "transfer failed");

        balances[_sender][_id] = balances[_sender][_id] - _amount;
        totalStaked = totalStaked - _amount;
        removeDepositIds(_sender, _id);
        if (balances[_sender][_id] == 0) {
            depositDates[_sender][_id] = 0;
        }

        emit Withdrawn(_sender, _id, amount, feeValue, balances[_sender][_id], rate, timePassed);
    }

    function _setLocked(bool _locked) internal {
        locked = _locked;
    }

    function _now() internal view returns (uint256) {
        return block.timestamp;
    }
}