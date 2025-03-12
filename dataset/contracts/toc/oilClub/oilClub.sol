// SPDX-License-Identifier: MIT

/********************************************************************

  ▒█████   ██▓ ██▓                   ▄████▄   ██▓     █    ██  ▄▄▄▄   
 ▒██▒  ██▒▓██▒▓██▒                  ▒██▀ ▀█  ▓██▒     ██  ▓██▒▓█████▄ 
 ▒██░  ██▒▒██▒▒██░                  ▒▓█    ▄ ▒██░    ▓██  ▒██░▒██▒ ▄██
 ▒██   ██░░██░▒██░                  ▒▓▓▄ ▄██▒▒██░    ▓▓█  ░██░▒██░█▀  
 ░ ████▓▒░░██░░██████▒       ██▓    ▒ ▓███▀ ░░██████▒▒▒█████▓ ░▓█  ▀█▓
 ░ ▒░▒░▒░ ░▓  ░ ▒░▓  ░       ▒▓▒    ░ ░▒ ▒  ░░ ▒░▓  ░░▒▓▒ ▒ ▒ ░▒▓███▀▒
   ░ ▒ ▒░  ▒ ░░ ░ ▒  ░       ░▒       ░  ▒   ░ ░ ▒  ░░░▒░ ░ ░ ▒░▒   ░ 
 ░ ░ ░ ▒   ▒ ░  ░ ░          ░      ░          ░ ░    ░░░ ░ ░  ░    ░ 
     ░ ░   ░      ░  ░        ░     ░ ░          ░  ░   ░      ░      
                              ░     ░                               ░ 
*********************************************************************/

pragma solidity 0.8.9;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
    * @dev Initializes the contract setting the deployer as the initial owner.
    */
    constructor () {
      address msgSender = _msgSender();
      _owner = msgSender;
      emit OwnershipTransferred(address(0), msgSender);
    }

    /**
    * @dev Returns the address of the current owner.
    */
    function owner() public view returns (address) {
      return _owner;
    }

    
    modifier onlyOwner() {
      require(_owner == _msgSender(), "Ownable: caller is not the owner");
      _;
    }

    function renounceOwnership() public onlyOwner {
      emit OwnershipTransferred(_owner, address(0));
      _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
      _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
      require(newOwner != address(0), "Ownable: new owner is the zero address");
      emit OwnershipTransferred(_owner, newOwner);
      _owner = newOwner;
    }
}

contract oilClub is Context, Ownable {
    using SafeMath for uint256;

    uint256 private LEASE_COEF = 1080000;
    uint256 private OIL_COEF = 10000;
    uint256 private OIL_COEFH = 5000;
    uint256 private devFeeVal = 2;
    uint256 private strikeDailyPump = 2;
    uint256 private holdWeekBonus = 5;
    uint256 private maxStrikeBonus = 15;
    bool private initialized = false;
    address payable private recAdd;
    mapping (address => uint256) private workingMiners;
    mapping (address => uint256) private generatedOil;
    mapping (address => uint256) private lastHatch;
    mapping (address => uint256) private lastSell;
    mapping (address => address) private referrals;
    mapping (address => uint256) private leaseStrike;
    uint256 private marketWells;
    
    constructor() {
        recAdd = payable(msg.sender);
    }

   

    function countBonus(uint256 seconds_hold) public view returns(uint256) {
        uint256 dayz = SafeMath.div(seconds_hold,86400);
        uint256 weekz = SafeMath.div(dayz,7);
        uint256 week_bonus = SafeMath.mul(weekz, holdWeekBonus);
        return min (week_bonus, maxStrikeBonus);       
    }
    
    function hatchWells(address ref) public {
        require(initialized);
        
        //prevent using self/contract ref
        if(ref == msg.sender || ref == address(this)) {
            ref = address(0);
        }
        
        if(referrals[msg.sender] == address(0) && referrals[msg.sender] != msg.sender && ref != address(this)) {
            referrals[msg.sender] = ref;
        }
        
        uint256 eggsUsed = getMyOil(msg.sender);
        uint256 newMiners = SafeMath.div(eggsUsed,LEASE_COEF);
        
        lastHatch[msg.sender] = block.timestamp;
        if (lastSell[msg.sender] <= 0) lastSell[msg.sender] = lastHatch[msg.sender]; //set initial sell date
        uint256 seconds_hold = SafeMath.sub(block.timestamp, lastSell[msg.sender]);
        uint256 strike_bonus = countBonus(seconds_hold);


        uint256 totalMiners = SafeMath.add(workingMiners[msg.sender],newMiners);
        uint256 bonusMiners = SafeMath.mul(SafeMath.div(newMiners,100),strike_bonus);
        workingMiners[msg.sender] = SafeMath.add(totalMiners,bonusMiners);
        generatedOil[msg.sender] = 0;
        
        
        
        //send referral eggs
        generatedOil[referrals[msg.sender]] = SafeMath.add(generatedOil[referrals[msg.sender]],SafeMath.div(eggsUsed,20));
        
        //boost market to nerf miners hoarding
        marketWells=SafeMath.add(marketWells,SafeMath.div(eggsUsed,5));

        leaseStrike[msg.sender] = SafeMath.add(leaseStrike[msg.sender],1);
    }
    
    function sellWells() public {
        require(initialized);
        uint256 hasEggs = getMyOil(msg.sender);
        uint256 eggValue = calculateOilSell(hasEggs);
        uint256 fee = devFee(eggValue);
        generatedOil[msg.sender] = 0;
        lastHatch[msg.sender] = block.timestamp;
        leaseStrike[msg.sender] = 0;
        marketWells = SafeMath.add(marketWells,hasEggs);
        lastSell[msg.sender] = block.timestamp;
        recAdd.transfer(fee);
        payable (msg.sender).transfer(SafeMath.sub(eggValue,fee));
    }
    
    function oilRewards(address adr) public view returns(uint256) {
        uint256 hasEggs = getMyOil(adr);
        uint256 eggValue = calculateOilSell(hasEggs);
        return eggValue;
    }
    
    function buyWells(address ref) public payable {
        require(initialized);
        uint256 eggsBought = calculateWellsBuy(msg.value,SafeMath.sub(address(this).balance,msg.value));
        eggsBought = SafeMath.sub(eggsBought,devFee(eggsBought));
       
        uint256 fee = devFee(msg.value);
        recAdd.transfer(fee);

      
        if (ref == msg.sender) {//return self-ref-payment
            payable (msg.sender).transfer(msg.value);  
        }
        else {
           generatedOil[msg.sender] = SafeMath.add(generatedOil[msg.sender],eggsBought);
           hatchWells(ref); 
        }
        
    }
    
    function calculateTrade(uint256 rt,uint256 rs, uint256 bs) private view returns(uint256) {
        return SafeMath.div(SafeMath.mul(OIL_COEF,bs),SafeMath.add(OIL_COEFH,SafeMath.div(SafeMath.add(SafeMath.mul(OIL_COEF,rs),SafeMath.mul(OIL_COEFH,rt)),rt)));
    }
    
    function calculateOilSell(uint256 eggs) public view returns(uint256) {
        return calculateTrade(eggs,marketWells,address(this).balance);
    }
    
    function calculateWellsBuy(uint256 eth,uint256 contractBalance) public view returns(uint256) {
        return calculateTrade(eth,contractBalance,marketWells);
    }
    
    function calculateWellsBuySimple(uint256 eth) public view returns(uint256) {
        return calculateWellsBuy(eth,address(this).balance);
    }
    
    function devFee(uint256 amount) private view returns(uint256) {
        return SafeMath.div(SafeMath.mul(amount,devFeeVal),100);
    }
    
    function seedMarket() public payable onlyOwner {
        require(marketWells == 0);
        initialized = true;
        marketWells = 108000000000;
    }
    
    function getBalance() public view returns(uint256) {
        return address(this).balance;
    }
    
    function getMyMiners(address adr) public view returns(uint256) {
        return workingMiners[adr];
    }

    function getMyStreak(address adr) public view returns(uint256) {
        return leaseStrike[adr];
    }

    function getLastSell(address adr) public view returns(uint256) {
        return lastSell[adr];
    }

    function getLastHatch(address adr) public view returns(uint256) {
        return lastHatch[adr];
    }
    
    function getMyOil(address adr) public view returns(uint256) {
        return SafeMath.add(generatedOil[adr],getOilSinceLastHatch(adr));
    }

    function getBlockTime() public view returns(uint256) {
        return block.timestamp;
    }
   
    function getSecondsPassed(address adr) public view returns(uint256) {
        uint256 secondsPassed=min(LEASE_COEF,SafeMath.sub(block.timestamp,lastHatch[adr]));
        return secondsPassed;
    }
    
    function getOilSinceLastHatch(address adr) public view returns(uint256) {
        uint256 secondsPassed=min(LEASE_COEF,SafeMath.sub(block.timestamp,lastHatch[adr]));
        return SafeMath.mul(secondsPassed,workingMiners[adr]);
    }
    
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}


library SafeMath {

    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }


    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }


    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }


    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }


    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }


    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }


    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }


    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }


    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }


    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }


    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}