// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


library SafeMath {

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }


  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}


contract AstroFarmer is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using SafeMath for uint256;
    
    uint256 public OXY_TO_HIRE_1_ASTRONAUT;
    uint256 public PERCENTS_DIVIDER;
    uint256 public REFERRAL;
    uint256 public DEV_FEES;
    uint256 public MARKET_OXYGEN_DIVISOR;
    uint256 public MARKET_OXYGEN_DIVISOR_SELL;

    uint256 public WALLET_DEPOSIT_LIMIT;

    uint256 public COMPOUND_BONUS;
    uint256 public COMPOUND_BONUS_MAX_TIMES;
    uint256 public COMPOUND_STEP;
    uint256 public WITHDRAWAL_TAX;
    uint256 public COMPOUND_FOR_NO_TAX_WITHDRAWAL;

    uint256 public totalStaked;
    uint256 public totalDeposits;
    uint256 public totalCompound;
    uint256 public totalRefBonus;
    uint256 public totalWithdrawn;

    uint256 public availableOxygen;
    uint256 PSN;
    uint256 PSNH;
    bool public contractStarted;

    uint256 public CUTOFF_STEP;

    address public ownerAddress;

    function initialize() public initializer {
        OXY_TO_HIRE_1_ASTRONAUT = 575424; // 12% daily reward
        PERCENTS_DIVIDER = 1000;
        REFERRAL = 140;  // 14%
        DEV_FEES = 10; // 1%
        MARKET_OXYGEN_DIVISOR = 2; // 50%
        MARKET_OXYGEN_DIVISOR_SELL = 1; // 100%

        WALLET_DEPOSIT_LIMIT = 100 ether;

        COMPOUND_BONUS = 25; // 2.5%
        COMPOUND_BONUS_MAX_TIMES = 12; // 12 times == 6 days
        COMPOUND_STEP = 12 * 60 * 60; // every 12 hours

        WITHDRAWAL_TAX = 500; // 50%
        COMPOUND_FOR_NO_TAX_WITHDRAWAL = 6; // compound days, for no tax withdrawal

        PSN = 10000;
        PSNH = 5000;

        CUTOFF_STEP = 48 * 60 * 60; // 48 hours

        ownerAddress = msg.sender;

        __Ownable_init();
    }

   function _authorizeUpgrade(address) internal override onlyOwner {}

    struct User {
        uint256 initialDeposit;
        uint256 userDeposit;
        uint256 astronauts;
        uint256 claimedOxygen;
        uint256 lastReinvest;
        address referrer;
        uint256 referralsCount;
        uint256 referralOxygenRewards;
        uint256 totalWithdrawn;
        uint256 dailyCompoundBonus;
        uint256 lastWithdrawTime;
    }

    mapping(address => User) public users;

    function reinvestOxygen(bool isCompound) public {
        User storage user = users[msg.sender];
        require(contractStarted, "Contract not yet Started.");

        uint256 oxygenUsed = getMyOxygen();
        uint256 oxygenForCompound = oxygenUsed;

        if(isCompound) {
            uint256 dailyCompoundBonus = getDailyCompoundBonus(msg.sender, oxygenForCompound);
            oxygenForCompound = oxygenForCompound.add(dailyCompoundBonus);
            uint256 oxygenUsedValue = calculateOxygenSell(oxygenForCompound);
            user.userDeposit = user.userDeposit.add(oxygenUsedValue);
            totalCompound = totalCompound.add(oxygenUsedValue);
        } 

        if(block.timestamp.sub(user.lastReinvest) >= COMPOUND_STEP) {
            if(user.dailyCompoundBonus < COMPOUND_BONUS_MAX_TIMES) {
                user.dailyCompoundBonus = user.dailyCompoundBonus.add(1);
            }
        }
        
        user.astronauts = user.astronauts.add(oxygenForCompound.div(OXY_TO_HIRE_1_ASTRONAUT));
        user.claimedOxygen = 0;
        user.lastReinvest = block.timestamp;

        availableOxygen = availableOxygen.add(oxygenUsed.div(MARKET_OXYGEN_DIVISOR));
    }

    function sellOxygen() public {
        require(contractStarted);
        User storage user = users[msg.sender];
        uint256 hasOxygen = getMyOxygen();
        uint256 oxyValue = calculateOxygenSell(hasOxygen);
        
        if(user.dailyCompoundBonus < COMPOUND_FOR_NO_TAX_WITHDRAWAL){
            oxyValue = oxyValue.sub(oxyValue.mul(WITHDRAWAL_TAX).div(PERCENTS_DIVIDER));
        } else {
            user.dailyCompoundBonus = 0;   
        }
        
        user.lastWithdrawTime = block.timestamp;
        user.claimedOxygen = 0;  
        user.lastReinvest = block.timestamp;
        availableOxygen = availableOxygen.add(hasOxygen.div(MARKET_OXYGEN_DIVISOR_SELL));
        
        if(getBalance() < oxyValue) {
            oxyValue = getBalance();
        }

        uint256 oxygenPayout = oxyValue.sub(payFees(oxyValue));
        payable(msg.sender).transfer(oxygenPayout);
        user.totalWithdrawn = user.totalWithdrawn.add(oxygenPayout);
        totalWithdrawn = totalWithdrawn.add(oxygenPayout);
    }

    function buyOxygen(address ref) public payable {
        require(contractStarted);
        User storage user = users[msg.sender];

        uint256 amount = msg.value;

        require(user.initialDeposit.add(amount) <= WALLET_DEPOSIT_LIMIT, "Max deposit limit reached.");
        
        uint256 oxygenBought = calculateOxygenBuy(msg.value, getBalance().sub(amount));
        user.userDeposit = user.userDeposit.add(amount);
        user.initialDeposit = user.initialDeposit.add(amount);
        user.claimedOxygen = user.claimedOxygen.add(oxygenBought);

        if (user.referrer == address(0)) {
            if (ref != msg.sender) {
                user.referrer = ref;
            }

            address upline1 = user.referrer;
            if (upline1 != address(0)) {
                users[upline1].referralsCount = users[upline1].referralsCount.add(1);
            }
        }
                
        if (user.referrer != address(0)) {
            address upline = user.referrer;
            if (upline != address(0)) {
                uint256 refRewards = oxygenBought.mul(REFERRAL).div(PERCENTS_DIVIDER);
                users[upline].claimedOxygen = SafeMath.add(users[upline].claimedOxygen,refRewards);
                users[upline].referralOxygenRewards = users[upline].referralOxygenRewards.add(refRewards);
                totalRefBonus = totalRefBonus.add(refRewards);
            }
        }

        uint256 oxygenPayout = payFees(amount);

        totalStaked = totalStaked.add(amount.sub(oxygenPayout));
        totalDeposits = totalDeposits.add(1);
        reinvestOxygen(false);
    }

    function payFees(uint256 oxyValue) internal returns(uint256){
        uint256 fees = oxyValue.mul(DEV_FEES).div(PERCENTS_DIVIDER);
        payable(ownerAddress).transfer(fees);
        return fees;
    }

    function getDailyCompoundBonus(address _adr, uint256 amount) public view returns(uint256){
        if(users[_adr].dailyCompoundBonus == 0) {
            return 0;
        } else {
            uint256 totalBonus = users[_adr].dailyCompoundBonus.mul(COMPOUND_BONUS); 
            uint256 result = amount.mul(totalBonus).div(PERCENTS_DIVIDER);
            return result;
        }
    }

    function getUserInfo(address _adr) public view returns(uint256 _initialDeposit, uint256 _userDeposit, uint256 _astronauts,
     uint256 _claimedOxygen, uint256 _lastInvest, address _referrer, uint256 _referrals,
	 uint256 _totalWithdrawn, uint256 _referralOxygenRewards, uint256 _dailyCompoundBonus, uint256 _lastWithdrawTime) {
         _initialDeposit = users[_adr].initialDeposit;
         _userDeposit = users[_adr].userDeposit;
         _astronauts = users[_adr].astronauts;
         _claimedOxygen = users[_adr].claimedOxygen;
         _lastInvest = users[_adr].lastReinvest;
         _referrer = users[_adr].referrer;
         _referrals = users[_adr].referralsCount;
         _totalWithdrawn = users[_adr].totalWithdrawn;
         _referralOxygenRewards = users[_adr].referralOxygenRewards;
         _dailyCompoundBonus = users[_adr].dailyCompoundBonus;
         _lastWithdrawTime = users[_adr].lastWithdrawTime;
    }

    function seedMarket() public payable onlyOwner {
        require(availableOxygen == 0);
        contractStarted = true;
        availableOxygen = 86400000000;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getTimeStamp() public view returns (uint256) {
        return block.timestamp;
    }

    function getAvailableEarnings(address _adr) public view returns(uint256) {
        uint256 userOxygen = users[_adr].claimedOxygen.add(getOxygenSinceLastReinvest(_adr));
        return calculateOxygenSell(userOxygen);
    }

    function calculateTrade(uint256 rt,uint256 rs, uint256 bs) public view returns(uint256){
        return SafeMath.div(SafeMath.mul(PSN, bs), SafeMath.add(PSNH, SafeMath.div(SafeMath.add(SafeMath.mul(PSN, rs), SafeMath.mul(PSNH, rt)), rt)));
    }

    function calculateOxygenSell(uint256 oxygen) public view returns(uint256){
        return calculateTrade(oxygen, availableOxygen, getBalance());
    }

    function calculateOxygenBuy(uint256 eth,uint256 contractBalance) public view returns(uint256){
        return calculateTrade(eth, contractBalance, availableOxygen);
    }

    function calculateOxygenBuySimple(uint256 eth) public view returns(uint256){
        return calculateOxygenBuy(eth, getBalance());
    }

    function getOxygenFarmed(uint256 amount) public view returns(uint256,uint256) {
        uint256 oxygenAmount = calculateOxygenBuy(amount , getBalance().add(amount).sub(amount));
        uint256 astronauts = oxygenAmount.div(OXY_TO_HIRE_1_ASTRONAUT);
        uint256 day = 1 days;
        uint256 oxygenPerDay = day.mul(astronauts);
        uint256 earningsPerDay = calculateOxygenSellForFarming(oxygenPerDay, amount);
        return(astronauts, earningsPerDay);
    }

    function calculateOxygenSellForFarming(uint256 oxygen,uint256 amount) public view returns(uint256){
        return calculateTrade(oxygen,availableOxygen, getBalance().add(amount));
    }

    function getSiteInfo() public view returns (uint256 _totalStaked, uint256 _totalDeposits, uint256 _totalCompound, uint256 _totalRefBonus) {
        return (totalStaked, totalDeposits, totalCompound, totalRefBonus);
    }

    function getMyAstronauts() public view returns(uint256){
        return users[msg.sender].astronauts;
    }

    function getMyOxygen() public view returns(uint256){
        return users[msg.sender].claimedOxygen.add(getOxygenSinceLastReinvest(msg.sender));
    }

    function getOxygenSinceLastReinvest(address adr) public view returns(uint256){
        uint256 secondsSinceLastHatch = block.timestamp.sub(users[adr].lastReinvest);
        uint256 cutoffTime = min(secondsSinceLastHatch, CUTOFF_STEP);
        uint256 secondsPassed = min(OXY_TO_HIRE_1_ASTRONAUT, cutoffTime);
        return secondsPassed.mul(users[adr].astronauts);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}