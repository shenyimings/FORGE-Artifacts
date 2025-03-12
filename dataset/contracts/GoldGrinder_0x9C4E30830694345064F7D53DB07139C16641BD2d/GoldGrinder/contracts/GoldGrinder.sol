
// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract GoldGrinder is Ownable {

    uint256 public constant GOLD_TO_HIRE_1MINER = 100 *1 days /9;//960k golds to hire 1 miner, 9%apr daily
    uint256 private constant PSN = 10000;
    uint256 private PSNH = 5000;
    uint256 private constant devFeeVal = 2;
    bool private _initialized;
    mapping (address => uint256) public goldMiners;
    mapping (address => uint256) private claimedGold;
    mapping (address => uint256) private lastHireTime;
    mapping (address => address) private referrals;
    uint256 private marketGold = 100000*GOLD_TO_HIRE_1MINER;

    mapping (address => bool) private hasParticipated;
    uint256 public uniqueUsers;

    modifier initialized {
      require(_initialized, "Contract not initialized");
      _;
   }
    
    function hireMiner(address ref) public initialized {
        
        if(ref != msg.sender && referrals[msg.sender] == address(0) && ref!= address(0)) {
            referrals[msg.sender] = ref;
        }
        
        uint256 goldUsed = getMyGold(msg.sender);
        uint256 myGoldRewards = getGoldSincelastHireTime(msg.sender);
        claimedGold[msg.sender] += myGoldRewards;

        uint256 newMiners = claimedGold[msg.sender]/GOLD_TO_HIRE_1MINER;
        
        claimedGold[msg.sender] -=(GOLD_TO_HIRE_1MINER * newMiners);
        goldMiners[msg.sender] += newMiners;
        
        lastHireTime[msg.sender] = block.timestamp;
        
        //send referral gold
        claimedGold[referrals[msg.sender]] += goldUsed/8;
        
        //boost market to nerf miners hoarding
        marketGold += goldUsed/5;

        if(!hasParticipated[msg.sender]) {
            hasParticipated[msg.sender] = true;
            uniqueUsers++;
        }
        if(!hasParticipated[ref] && ref!= address(0)) {
            hasParticipated[ref] = true;
            uniqueUsers++;
        }
    }
    
    function sellGold() public initialized{
        uint256 hasGold = getMyGold(msg.sender);
        uint256 goldValue = calculateGoldSell(hasGold);
        uint256 fee = devFee(goldValue);
        claimedGold[msg.sender] = 0;
        lastHireTime[msg.sender] = block.timestamp;
        marketGold += hasGold;
        payable(owner()).transfer(fee);
        payable (msg.sender).transfer(goldValue-fee);
        if(goldMiners[msg.sender] == 0) uniqueUsers--;
    }
    
    function buyGold(address ref) external payable initialized {
        _buyGold(ref,msg.value);
    }

    //to prevent sniping
    function seedMarket() public payable onlyOwner  {
        require(!_initialized, "Already initialized");
        _initialized = true;
        _buyGold(0x0000000000000000000000000000000000000000,msg.value);
    }
    
    function _buyGold(address ref, uint256 amount) private
    {
        uint256 goldBought = calculateGoldBuy(amount,address(this).balance-amount);
        goldBought -= devFee(goldBought);
        uint256 fee = devFee(amount);
        payable(owner()).transfer(fee);
        claimedGold[msg.sender] += goldBought;

        hireMiner(ref);
    }
    function goldRewardsToBNB(address adr) external view returns(uint256) {
        uint256 hasGold = getMyGold(adr);
        uint256 goldValue;
        try  this.calculateGoldSell(hasGold) returns (uint256 value) {goldValue=value;} catch{}
        return goldValue;
    }

    function calculateTrade(uint256 rt,uint256 rs, uint256 bs) private view returns(uint256) {
        return (PSN*bs)/(PSNH+(PSN*rs+PSNH*rt)/rt);
    }
    
    function calculateGoldSell(uint256 gold) public view returns(uint256) {
        return calculateTrade(gold,marketGold,address(this).balance);
    }
    
    function calculateGoldBuy(uint256 eth,uint256 contractBalance) public view returns(uint256) {
        return calculateTrade(eth,contractBalance,marketGold);
    }
    
    function calculateGoldBuySimple(uint256 eth) external view returns(uint256) {
        return calculateGoldBuy(eth,address(this).balance);
    }
    
    function devFee(uint256 amount) private pure returns(uint256) {
        return amount*devFeeVal/100;
    }
    
    function getMyGold(address adr) public view returns(uint256) {
        return claimedGold[adr]+ getGoldSincelastHireTime(adr);
    }
    
    function getGoldSincelastHireTime(address adr) public view returns(uint256) {
        return Math.min(GOLD_TO_HIRE_1MINER,block.timestamp-lastHireTime[adr])*goldMiners[adr];
    }
    
    /*for the front end, it returns a value between 0 and GOLD_TO_HIRE_1MINER, when reached GOLD_TO_HIRE_1MINER 
    user will stop accumulating gold and should compound or sell to get others
    */
    function getGoldAccumulationValue(address adr) public view returns(uint256) {
        return Math.min(GOLD_TO_HIRE_1MINER,block.timestamp-lastHireTime[adr]);
    }
    
}