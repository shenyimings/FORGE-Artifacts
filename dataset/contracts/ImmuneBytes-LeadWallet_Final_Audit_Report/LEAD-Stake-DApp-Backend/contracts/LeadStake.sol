//"SPDX-License-Identifier: UNLICENSED"

pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '@openzeppelin/contracts/access/Ownable.sol';

contract LeadStake is Ownable {
    
    //initializing safe computations
    using SafeMath for uint;

    //LEAD contract address
    address public lead;
    //total amount of staked lead
    uint public totalStaked;
    //tax rate for staking in percentage
    uint public stakingTaxRate;
    //tax amount for registration
    uint public registrationTax;
    //daily return of investment in percentage
    uint8 public weeklyROI;
    //total amount of LEAD distributed
    uint public totalDistributed;
    //tax rate for unstaking in percentage
    uint public unstakingTaxRate;
    //minimum stakeable LEAD 
    uint public minimumStakeValue;
    //referral allocation from the registration tax
    uint public referralTaxAllocation;
    //list of stakeholders' addresses
    address[] public stakeholders;
    //mapping of stakeholders' address to number of stakes
    mapping(address => uint) public stakes;
    //mapping of stakeholders' address to stake rewards
    mapping(address => uint) public stakeRewards;
    //mapping of stakeholders' address to number of referrals 
    mapping(address => uint) public referralCount;
    //mapping of stakeholders' address to referral rewards earned 
    mapping(address => uint) public referralRewards;
    //mapping of stakeholder's address to last transaction time for reward calculation
    mapping(address => uint) public lastClock;
    //mapping of addresses to verify registered stakers
    mapping(address => bool) public registered;
    
    //Events
    event OnWithdrawal(address sender, uint amount);
    event OnStake(address sender, uint amount, uint tax);
    event OnUnstake(address sender, uint amount, uint tax);
    event OnDeposit(address sender, uint amount, uint time);
    event OnRegisterAndStake(address stakeholder, uint amount, uint totalTax , address _referrer);
    
    /**
     * @dev Sets the initial values
     */
    constructor(
        address _token,
        uint8 _stakingTaxRate, 
        uint8 _unstakingTaxRate,
        uint8 _weeklyROI,
        uint _registrationTax,
        uint _referralTaxAllocation,
        uint _minimumStakeValue) public {
            
        //set initial state variables
        lead = _token;
        stakingTaxRate = _stakingTaxRate;
        unstakingTaxRate = _unstakingTaxRate;
        weeklyROI = _weeklyROI;
        registrationTax = _registrationTax;
        referralTaxAllocation = _referralTaxAllocation;
        minimumStakeValue = _minimumStakeValue;
    }
    
    //exclusive access for registered address
    modifier onlyRegistered() {
        require(registered[msg.sender] == true, "Staker must be registered");
        _;
    }
    
    //exclusive access for unregistered address
    modifier onlyUnregistered() {
        require(registered[msg.sender] == false, "Staker is already registered");
        _;
    }
    
    /**
     * registers and creates stakes for new stakeholders
     * deducts the registration tax and staking tax
     * calculates refferal bonus from the registration tax and sends it to the _referrer if there is one
     * transfers LEAD from sender's address into the smart contract
     * Emits an {OnRegisterAndStake} event..
     */
    function registerAndStake(uint _amount, address _referrer) external onlyUnregistered() {
        //makes sure user is not the referrer
        require(msg.sender != _referrer, "Cannot refer self");
        //makes sure user has enough amount
        require(IERC20(lead).balanceOf(msg.sender) >= _amount, "Must have enough balance to stake");
        //makes sure smart contract transfers LEAD from user
        require(IERC20(lead).transferFrom(msg.sender, address(this), _amount), "Stake failed due to failed amount transfer.");
        //makes sure amount is more than the registration fee and the minimum deposit
        require(_amount >= registrationTax.add(minimumStakeValue), "Must send at least enough LEAD to pay registration fee.");
        //calculates referral bonus
        uint referralBonus = (registrationTax.mul(referralTaxAllocation)).div(100);
        //calculates final amount after deducting registration tax
        uint finalAmount = _amount.sub(registrationTax);
        //calculates staking tax on final calculated amount
        uint stakingTax = (stakingTaxRate.mul(finalAmount)).div(100);
        //conditional statement if user registers with referrer 
        if(_referrer != address(0x0)) {
            //increase referral count of referrer
            referralCount[_referrer]++;
            //add referral bonus to referrer
            referralRewards[_referrer] = referralRewards[_referrer].add(referralBonus);
        } 
        //update the user's stakes deducting the staking tax
        stakes[msg.sender] = stakes[msg.sender].add(finalAmount).sub(stakingTax);
        //update the total staked LEAD amount in the pool
        totalStaked = totalStaked.add(finalAmount).sub(stakingTax);
        //register user and add to stakeholders list
        registered[msg.sender] = true;
        stakeholders.push(msg.sender);
        //mark the transaction date
        lastClock[msg.sender] = now;
        //emit event
        emit OnRegisterAndStake(msg.sender, _amount, registrationTax.add(stakingTax), _referrer);
    }
    
    //calculates stakeholders latest unclaimed earnings 
    function calculateEarnings(address _stakeholder) public view returns(uint) {
        //records the number of weeks between the last payout time and now
        uint activeWeeks = (now.sub(lastClock[_stakeholder])).div(604800);
        //returns earnings based on daily ROI and active days
        return (stakes[_stakeholder].mul(weeklyROI).mul(activeWeeks)).div(100);
    }
    
    /**
     * creates stakes for already registered stakeholders
     * deducts the staking tax from _amount inputted
     * registers the remainder in the stakes of the sender
     * records the previous earnings before updated stakes 
     * Emits an {OnStake} event
     */
    function stake(uint _amount) external onlyRegistered() {
        //makes sure the time interval between the last payout time and now is up to 1 week
        require(now.sub(lastClock[msg.sender]) >= 604800, 'Must wait for 7 days at least');
        //makes sure stakeholder does not stake below the minimum
        require(_amount >= minimumStakeValue, "Amount is below minimum stake value.");
        //makes sure stakeholder has enough balance
        require(IERC20(lead).balanceOf(msg.sender) >= _amount, "Must have enough balance to stake");
        //makes sure smart contract transfers LEAD from user
        require(IERC20(lead).transferFrom(msg.sender, address(this), _amount), "Stake failed due to failed amount transfer.");
        //calculates staking tax on amount
        uint stakingTax = (stakingTaxRate.mul(_amount)).div(100);
        //calculates amount after tax
        uint afterTax = _amount.sub(stakingTax);
        //update the total staked LEAD amount in the pool
        totalStaked = totalStaked.add(afterTax);
        //adds earnings current earnings to stakeRewards
        stakeRewards[msg.sender] = stakeRewards[msg.sender].add(calculateEarnings(msg.sender));
        //mark transaction date
        lastClock[msg.sender] = now;
        //updates stakeholder's stakes
        stakes[msg.sender] = stakes[msg.sender].add(afterTax);
        //emit event
        emit OnStake(msg.sender, afterTax, stakingTax);
    }
    
    
    /**
     * removes '_amount' stakes for already registered stakeholders
     * deducts the unstaking tax from '_amount'
     * transfers the sum of the remainder, stake rewards, referral rewards, and current eanrings to the sender 
     * deregisters stakeholder if all the stakes are removed
     * Emits an {OnStake} event
     */
    function unstake(uint _amount) external onlyRegistered() {
        //makes sure the time interval between the last payout time and now is up to 1 week
        require(now.sub(lastClock[msg.sender]) >= 604800, 'Must wait for 7 days at least');
        //makes sure _amount is not more than stake balance
        require(_amount <= stakes[msg.sender], 'Insufficient balance to unstake');
        //calculates unstaking tax
        uint unstakingTax = (unstakingTaxRate.mul(_amount)).div(100);
        //calculates amount after tax
        uint afterTax = _amount.sub(unstakingTax);
        //sums up stakeholder's total rewards with _amount deducting unstaking tax
        uint unstakePlusAllEarnings = stakeRewards[msg.sender].add(referralRewards[msg.sender]).add(afterTax).add(calculateEarnings(msg.sender));
        //transfers value to stakeholder
        IERC20(lead).transfer(msg.sender, unstakePlusAllEarnings);
        //initializes stake rewards
        stakeRewards[msg.sender] = 0;
        //updates stakes
        stakes[msg.sender] = stakes[msg.sender].sub(_amount);
        //initializes referral rewards
        referralRewards[msg.sender] = 0;
        //initializes referral count
        referralCount[msg.sender] = 0;
        //mark transaction date 
        lastClock[msg.sender] = now;
        //update the total staked LEAD amount in the pool
        totalStaked = totalStaked.sub(_amount);
        //conditional statement if stakeholder has no stake left
        if(stakes[msg.sender] == 0) {
            //deregister stakeholder
            _removeStakeholder(msg.sender);
        }
        //emit event
        emit OnUnstake(msg.sender, _amount, unstakingTax);
    }
    
    /**
     * checks if _address is a registered stakeholder
     * returns 'true' and 'id number' if stakeholder and 'false' and '0'  if not
     */
    function isStakeholder(address _address) public view returns(bool, uint) {
        //loops through the stakeholders list
        for (uint i = 0; i < stakeholders.length; i += 1){
            //conditional statement if address is stakeholder
            if (_address == stakeholders[i]) {
                //returns true and list id
                return (true, i);
            }
        }
        //returns false and 0
        return (false, 0);
    }
    
    //deregisters _stakeholder and removes address from stakeholders list
    function _removeStakeholder(address _stakeholder) internal {
        //changes registered staus to false
        registered[msg.sender] = false;
        //identify stakeholder in the stakeholders list
        (bool _isStakeholder, uint i) = isStakeholder(_stakeholder);
        if(_isStakeholder){
            //transfer stakeholdeer to last id in the list
            stakeholders[i] = stakeholders[stakeholders.length - 1];
            //delete last id of the list
            stakeholders.pop();
        }
    }
    
    //transfers total active earnng to stakeholders wallett
    function withdrawEarnings() external onlyRegistered() {
        //makes sure the time interval between the last payout time and now is up to 1 week
        require(now.sub(lastClock[msg.sender]) >= 604800, 'Must wait for 7 days at least');
        //calculates the total redeemable rewards
        uint totalReward = referralRewards[msg.sender].add(stakeRewards[msg.sender]).add(calculateEarnings(msg.sender));
        //makes sure user has rewards to withdraw before execution
        require(totalReward > 0, 'No reward to withdraw'); 
        //transfers total rewards to stakeholder
        IERC20(lead).transfer(msg.sender, totalReward);
        //initializes stake rewards
        stakeRewards[msg.sender] = 0;
        //initializes referal rewards
        referralRewards[msg.sender] = 0;
        //initializes referral count
        referralCount[msg.sender] = 0;
        //registers transaction date
        lastClock[msg.sender] = now;
        //emit event
        emit OnWithdrawal(msg.sender, totalReward);
    }

    //sets the staking rate
    function setStakingTaxRate(uint8 _stakingTaxRate) external onlyOwner() {
        stakingTaxRate = _stakingTaxRate;
    }
    
    //sets the unstaking rate
    function setUnstakingTaxRate(uint8 _unstakingTaxRate) external onlyOwner() {
        unstakingTaxRate = _unstakingTaxRate;
    }
    
    //sets the weekly ROI
    function setweeklyROI(uint8 _weeklyROI) external onlyOwner() {
        for(uint i = 0; i < stakeholders.length; i++){
            //registers all previous earnings
            stakeRewards[stakeholders[i]] = stakeRewards[stakeholders[i]].add(calculateEarnings(stakeholders[i]));
            //logs transaction time
            lastClock[stakeholders[i]] = now;
        }
        weeklyROI = _weeklyROI;
    }
    
    //sets the registration tax
    function setRegistrationTax(uint _registrationTax) external onlyOwner() {
        registrationTax = _registrationTax;
    }
    
    //sets the refferal tax allocation 
    function setReferralTaxAllocation(uint _referralTaxAllocation) external onlyOwner() {
        referralTaxAllocation = _referralTaxAllocation;
    }
    
    //sets the minimum stake value
    function setMinimumStakeValue(uint _minimumStakeValue) external onlyOwner() {
        minimumStakeValue = _minimumStakeValue;
    }
    
    //withdraws _amount from the pool to _address
    function adminWithdraw(address _address, uint _amount) external onlyOwner {
        //makes sure _amount is not more than smart contract balance
        require(IERC20(lead).balanceOf(msg.sender) >= _amount, 'Insufficient LEAD balance in smart contract');
        //transfers _amount to _address
        IERC20(lead).transfer(_address, _amount);
        //emit event
        emit OnWithdrawal(_address, _amount);
    }
    
    //supplies LEAD from 'owner' to smart contract if pool balance runs dry
    function supplyPool() external onlyOwner() {
        //total balance that can be claimed in the pool
        uint totalClaimable;
        //loop through stakeholders' list
        for(uint i = 0; i < stakeholders.length; i++){
            //sum up all redeemable LEAD
            totalClaimable = stakeRewards[stakeholders[i]].add(referralRewards[stakeholders[i]]).add(stakes[stakeholders[i]]).add(calculateEarnings(stakeholders[i]));
        }
        //calculate difference
        uint difference = totalClaimable.sub(IERC20(lead).balanceOf(address(this)));
        //makes sure the pool dept is higher than balance
        require(totalClaimable > IERC20(lead).balanceOf(address(this)), 'Still have enough pool reserve');
        //makes sure 'owner' has enough balance
        require(IERC20(lead).balanceOf(msg.sender) >= difference, 'Insufficient LEAD balance in owner wallet');
        //transfers LEAD from 'owner' to smart contract to make up for dept
        IERC20(lead).transferFrom(msg.sender, address(this), difference);
        //emits event
        emit OnDeposit(msg.sender, difference, now);
    }
    
}