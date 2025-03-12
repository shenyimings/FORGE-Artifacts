//New version
pragma solidity ^0.6.0;
// SPDX-License-Identifier: MIT
// Libs
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
// Used contracts
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
//Internal
import { LPTokenWrapper } from  "./LPTokenWrapper.sol";

contract StakingPool is Ownable, ReentrancyGuard, LPTokenWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;
    
    //interface for Rewards Token
    IERC20 public rewardsToken;
    //Conctact status states
    enum Status {Setup, Running, Ended}
    
    //Constants
    uint256 constant public CALC_PRECISION = 1e18;

    // Address where fees will be sent if fee isn't 0
    address public fee_beneficiary;
    // Fee in PPM (Parts Per Million), can be 0
    uint256 public fee;
    //Status of contract
    Status public status;
    //Rewards for period
    uint256 public rewardsPerPeriodCap;
    //Total rewards for all periods
    uint256 public rewardsTotalCap;
    //Staking Period in seconds
    uint256 public periodTime;
    //Total Periods
    uint256 public totalPeriods;
    //Grace Periods Time (time window after contract is Ended when users have to claim their Reward Tokens)
    //after this period ends, no reward withdrawal is possible and contact owner can withdraw unclamed Reward Tokens
    uint256 public gracePeriodTime;
    //Time when contracts starts
    uint256 public startTime;
    //Time when contract ends 
    uint256 public endTime;
    //Time when contract closes (endTime + gracePeriodTime)
    uint256 public closeTime;
    
    
    //Last Period
    uint256 public period;
    
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event WithdrawnERC20(address indexed user, address token, uint256 amount);
    

    /** @dev Updates Period before executing function */
    modifier updatePeriod() {
        _updatePeriod();
        _;
    }
    
    /** @dev Make sure setup is finished */
    modifier onlyAferSetup() {
        require(status != Status.Setup, "Setup is not finished");
        _;
    }

    /**
     * @dev Contract constructor
     * @param _lpToken Contract address of LP Token
     * @param _rewardsToken Contract address of Rewards Token
     * @param _rewardsPerPeriodCap Amount of tokens to be distributed each period (1e18)
     * @param _periodDays Period time in days
     * @param _totalPeriods Total periods contract will be running
     * @param _gracePeriodDays Grace period in days 
     * @param _holdDays Time in days LP Tokens will be on hold for user after each stake
     */
    constructor(
        address _lpToken,
        address _rewardsToken,
        uint256 _rewardsPerPeriodCap,
        uint256 _periodDays, 
        uint256 _totalPeriods,
        uint256 _gracePeriodDays,
        uint256 _holdDays,
        address _fee_beneficiary,
        uint256 _fee
    )
        public
        LPTokenWrapper(_lpToken, _holdDays)
    {
        require(_lpToken.isContract(), "LP Token address must be a contract");
        require(_rewardsToken.isContract(), "Rewards Token address must be a contract");
        rewardsToken = IERC20(_rewardsToken);
        rewardsPerPeriodCap = _rewardsPerPeriodCap;
        rewardsTotalCap = _rewardsPerPeriodCap.mul(_totalPeriods);
        periodTime = _periodDays.mul(1 days);
        totalPeriods = _totalPeriods;
        gracePeriodTime = _gracePeriodDays.mul(1 days);
        fee_beneficiary = _fee_beneficiary;
        fee = _fee;
    }

    /***************************************
                    ADMIN
    ****************************************/

    /**
     * @dev Updates contract setup and mark contract status as Running if all requirements are met
     * @param _now Start contract immediatly if true
     */    
    function adminStart(bool _now) 
        external 
        onlyOwner
    {
        require(status == Status.Setup, "Already started");
        require(rewardsToken.balanceOf(address(this)) >= rewardsTotalCap, "Not enough reward tokens to start");
        status = Status.Running;
        if(_now) _startNow();
    }
    
    /**
     * @dev Option to start contract even there is no deposits yet
     */
    function adminStartNow()
        external
        onlyOwner
        onlyAferSetup
    {
        require(startTime == 0 && status == Status.Running, "Already started");
        _startNow();
        
    }
    
    /**
     * @dev Option to end contract 
     */
    function adminEnd()
        external
        onlyOwner
        onlyAferSetup
    {
        require(block.timestamp >= endTime && endTime != 0, "Cannot End");
        _updatePeriod();
    }
    
    /**
     * @dev Close contract after End and Grace period and withdraw unclamed rewards tokens
     * @param _address where to send
     */
     function adminClose(address _address)
        external
        onlyOwner
        onlyAferSetup
    {
        require(block.timestamp >= closeTime && closeTime != 0, "Cannot Close");
        uint256 _rewardsBalance = rewardsToken.balanceOf(address(this));
        if(_rewardsBalance > 0) rewardsToken.safeTransfer(_address, _rewardsBalance);
    }
    
    /**
     * @dev Withdraw other than LP or Rewards tokens 
     * @param _tokenAddress address of the token contract to withdraw
     */
     function adminWithdrawERC20(address _tokenAddress)
        external
        onlyOwner
    {
        require(_tokenAddress != address(rewardsToken) && _tokenAddress != address(lpToken), "Cannot withdraw Reward or LP Tokens");
        IERC20 _token = IERC20(_tokenAddress);
        uint256 _balance = _token.balanceOf(address(this));
        require(_balance != 0, "Not enough balance");
        uint256 _fee = _balance.mul(fee).div(1e6);
        if(_fee != 0){
            _token.safeTransfer(fee_beneficiary, _fee);
            emit WithdrawnERC20(fee_beneficiary, _tokenAddress, _fee);
        }
        _token.safeTransfer(msg.sender, _balance.sub(_fee));
        emit WithdrawnERC20(msg.sender, _tokenAddress, _balance.sub(_fee));
    }
    
    /***************************************
                    PRIVATE
    ****************************************/
    
    /**
     * @dev Starts the contract
     */
    function _startNow()
        private
    {
        startTime = block.timestamp;
        endTime = startTime.add(periodTime.mul(totalPeriods));  
        closeTime = endTime.add(gracePeriodTime);
    }

    /**
     * @dev Updates last period to current and set status to Ended if needed
     */
    function _updatePeriod()
        private
    {
        uint256 _currentPeriod = currentPeriod();
        if(_currentPeriod != period){
            period = _currentPeriod;
            _updateHistoryTotalSupply(period);
            if(_currentPeriod == totalPeriods){
                status = Status.Ended;
                //release hold of LP tokens
                holdTime = 0;
            }
        }
    }
    
 
    /***************************************
                    ACTIONS
    ****************************************/
    
    /**
     * @dev Stakes an amount for the sender, assumes sender approved allowace at LP Token contract _amount for this contract address
     * @param _amount of LP Tokens
     */
    function stake(uint256 _amount)
        external
        onlyAferSetup
        updatePeriod
    {
        require(_amount > 0, "Cannot stake 0");
        require(status != Status.Ended, "Contract is Ended");
        if(startTime == 0) _startNow();
        _stake(_amount, period);
        emit Staked(msg.sender, _amount);
    }

    /**
     * @dev Withdraws given LP Token stake amount from the pool
     * @param _amount LP Tokens to withdraw
     */
    function withdraw(uint256 _amount)
        public
        onlyAferSetup
        updatePeriod
    {
        require(_amount > 0, "Cannot withdraw 0");
        _withdraw(_amount, period);
        emit Withdrawn(msg.sender, _amount);
    }
    
    /**
     * @dev Claims outstanding rewards for the sender.
     * First updates outstanding reward allocation and then transfers.
     */
    function claimReward()
        public
        nonReentrant
        onlyAferSetup
        updatePeriod
    {
        require(block.timestamp <= closeTime, "Contract is Closed");
        uint256 reward = calculateReward(msg.sender);
        if (reward > 0) {
            _updateUser(msg.sender, period);
            rewardsToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }    
    
    /**
     * @dev Withdraws LP Tokens stake from pool and claims any rewards
     */
    function exit() 
        external
    {
        uint256 _amount = balanceOf(msg.sender);
        if(_amount !=0) withdraw(_amount);
        claimReward();
    }
    
    /***************************************
                    GETTERS
    ****************************************/

    /**
     * @dev Calculates current period, if contract is ended returns currentPeriod + 1 (totalPeriods)
     */
    function currentPeriod() 
        public 
        view 
        returns (uint256)
    {
        uint256 _currentPeriod;
        if(startTime != 0 && endTime != 0)
        {
            if(block.timestamp >= endTime){
                _currentPeriod = totalPeriods;
            }else{
                _currentPeriod = block.timestamp.sub(startTime).div(periodTime);
            }
        }
        return _currentPeriod;
    }

    /**
     * @dev Calculates pending rewards for the user since last period claimed rewards to current period
     * @param _address address of the user
     */
     function calculateReward(address _address) 
        public
        view
        returns (uint256)
    {
        UserData storage user = getUserData(_address);
        if(!user.exists || block.timestamp >= closeTime) return 0;
        uint256 _period = currentPeriod();
        uint256 periodTotalSupply;
        uint256 savedTotalSupply;
        uint256 periodBalance;
        uint256 savedBalance;
        uint256 rewardTotal;
        savedTotalSupply =  historyTotalSupply(user.period);
        savedBalance = user.historyBalance[user.period];
        for(uint256 i = user.period; i < _period; i++){
            periodTotalSupply = historyTotalSupply(i);
            periodBalance = user.historyBalance[i];
            if(i > user.period){
                periodBalance == 0 ? periodBalance = savedBalance : savedBalance = periodBalance;
                periodTotalSupply == 0 ? periodTotalSupply = savedTotalSupply : savedTotalSupply = periodTotalSupply;
            }
            rewardTotal = rewardTotal.add(
                rewardsPerPeriodCap.mul(
                    periodBalance
                ).mul(
                    CALC_PRECISION
                ).div(
                    periodTotalSupply
                ).div(
                    CALC_PRECISION
                )
            );
        }
        return rewardTotal;
    }

    /**
     * @dev Returns estimated current period reward for the user based on current total supply and his balance
     * @param _address address of the user
     */
     function estimateReward(address _address) 
        public
        view
        returns (uint256)
    {
        uint256 _totalSupply = totalSupply();
        if(_totalSupply == 0 || !isUserExist(_address) || block.timestamp >= closeTime) return 0;
        return rewardsPerPeriodCap.mul(
            balanceOf(_address)
        ).mul(
            CALC_PRECISION
        ).div(
            _totalSupply
        ).div(
            CALC_PRECISION
        );
    }

}
