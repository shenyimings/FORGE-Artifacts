// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );


    constructor() {
        _transferOwnership(_msgSender());
    }


    function owner() public view virtual returns (address) {
        return _owner;
    }


    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {

    uint private constant _NOT_ENTERED = 1;
    uint private constant _ENTERED = 2;

    uint private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }


    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        _status = _ENTERED;

        _;


        _status = _NOT_ENTERED;
    }
}

library SafeMath {
   

    function add(uint a, uint b) internal pure returns (uint) {
        return a + b;
    }


    function sub(uint a, uint b) internal pure returns (uint) {
        return a - b;
    }


    function div(uint a, uint b) internal pure returns (uint) {
        return a / b;
    }
}


contract ProfitScraper is Ownable, ReentrancyGuard{
    using SafeMath for uint;

    uint private constant DEVELOPER_FEE_DEPOSIT = 600; 
    uint private constant DEVELOPER_FEE_WITHDRAW = 400; 
    uint private constant REFFER_REVARD_1_LVL = 600; 
    uint private constant REFFER_REVARD_2_LVL = 300;
    uint private constant REWARD_PERIOD = 1 days;
    uint private constant PERCENT_RATE = 10000;
    uint private constant APR_CONST = 510;
    address private devWallet; 
    uint private _currentDepositID = 0;

    uint private totalInvestors = 0;
    uint private totalReward = 0;
    uint private totalInvested = 0;

    struct InvestorStruct{
        address investor;
        address referrer;
        uint totalLocked;
        uint lastCalculationDate;
        uint claimableAmount;
        uint claimedAmount;
        uint referAmount;
        uint APR;
        uint daysWithoutClaim;
        uint lastClaimTime;
        uint accruedPerPool;
        uint referralsOneLvlNumber;
        uint referralsTwoLvlNumber;
    }

    struct FirstDeposit {
        address owner;
        uint contractBalance;
        uint timestamp;
    }

    mapping(uint => FirstDeposit) public firstDeposits;

    mapping(address => uint[]) public ownedDeposits;

    mapping(address => InvestorStruct) public investors;
    
    uint immutable deploymentDate;

    uint constant bnb100 = 100 * 10 ** 18;  
    uint constant bnb10 = 10 * 10 ** 18;  
    
    constructor() {
        devWallet = 0xE274FB24f309f58e3e0412e72174A5227fDFeC2b;
        deploymentDate = block.timestamp;
    }

    function _getNextDepositID() private view returns (uint) {
        return _currentDepositID + 1;
    }

    function _incrementDepositID() private {
        _currentDepositID++;
    }


    function contribution(address _referrer) public payable {
        uint _amount = msg.value;
        require(_amount > 0, "< 0 BNB");

        if(_referrer == msg.sender){
            _referrer = address(0);
        }

        uint _id = _getNextDepositID();
        _incrementDepositID();

        uint depositFee = (_amount * DEVELOPER_FEE_DEPOSIT).div(PERCENT_RATE);
        
        payable(devWallet).transfer(depositFee);

        uint _depositAmount = _amount - depositFee;


        if(investors[msg.sender].investor == address(0)){ 
            
            investors[msg.sender].investor = msg.sender;
            investors[msg.sender].lastCalculationDate = block.timestamp;
            investors[msg.sender].APR = APR_CONST;

            firstDeposits[totalInvestors].owner = msg.sender;
            firstDeposits[totalInvestors].contractBalance = address(this).balance;
            firstDeposits[totalInvestors].timestamp = block.timestamp;

            totalInvestors = totalInvestors.add(1);
        }

        if(address(0) != _referrer && investors[msg.sender].referrer == address(0)) {
            investors[msg.sender].referrer = _referrer;
            investors[_referrer].referralsOneLvlNumber += 1;
            if (investors[_referrer].referrer != address(0)){         
                investors[investors[_referrer].referrer].referralsTwoLvlNumber += 1;
            }            

        }

        if(investors[msg.sender].referrer != address(0)){
            uint referrerAmountlvl1 = (_amount * REFFER_REVARD_1_LVL).div(PERCENT_RATE);
            uint referrerAmountlvl2 = (_amount * REFFER_REVARD_2_LVL).div(PERCENT_RATE);
            

            investors[investors[msg.sender].referrer].referAmount = investors[investors[msg.sender].referrer].referAmount.add(referrerAmountlvl1);

            payable(investors[msg.sender].referrer).transfer(referrerAmountlvl1);

            if(investors[_referrer].referrer != address(0)) {
                investors[investors[_referrer].referrer].referAmount = investors[investors[_referrer].referrer].referAmount.add(referrerAmountlvl2);

                payable(investors[_referrer].referrer).transfer(referrerAmountlvl2);
            }

        }

        uint percent = ((investors[msg.sender].totalLocked + _depositAmount) / (bnb10));

        if (percent > 0){
            investors[msg.sender].APR += percent * 50;
        }

        uint lastRoiTime = block.timestamp - investors[msg.sender].lastCalculationDate;
        uint allClaimableAmount = (lastRoiTime *
            investors[msg.sender].totalLocked *
            investors[msg.sender].APR).div(PERCENT_RATE * REWARD_PERIOD);

        investors[msg.sender].claimableAmount = investors[msg.sender].claimableAmount.add(allClaimableAmount);
        investors[msg.sender].totalLocked = investors[msg.sender].totalLocked.add(_depositAmount);
        
        investors[msg.sender].lastCalculationDate = block.timestamp;

        totalInvested = totalInvested.add(_amount);

        ownedDeposits[msg.sender].push(_id);
        
    }


    function getAllClaimableReward(address _investor) public view returns (uint) {
        uint lastRoiTime = block.timestamp - investors[_investor].lastCalculationDate;
        uint _apr = investors[_investor].APR;
        uint allClaimableAmount = (lastRoiTime *
            investors[_investor].totalLocked *
            _apr).div(PERCENT_RATE * REWARD_PERIOD);

         return investors[_investor].claimableAmount.add(allClaimableAmount);
    }


    function info() public view returns(uint) {
        return address(this).balance;
    }


    function getTotalAmountEarned(address _investor) external view returns(uint){
        uint claimed = getAllClaimableReward(_investor);
        return investors[_investor].claimedAmount + claimed;
    }


    function harvest() public nonReentrant {
        require(ownedDeposits[msg.sender].length > 0, "harvest error");

        require(investors[msg.sender].totalLocked * 3 > investors[msg.sender].claimedAmount, "claimed limit reached");

        uint changeAPR = investors[msg.sender].daysWithoutClaim * 5;
        investors[msg.sender].APR -= changeAPR;
        investors[msg.sender].daysWithoutClaim = 0;
        investors[msg.sender].lastClaimTime = block.timestamp;

        uint lastRoiTime = block.timestamp - investors[msg.sender].lastCalculationDate;

        uint allClaimableAmount = (lastRoiTime *
            investors[msg.sender].totalLocked *
            investors[msg.sender].APR).div(PERCENT_RATE * REWARD_PERIOD);

        investors[msg.sender].claimableAmount = investors[msg.sender].claimableAmount.add(allClaimableAmount);

        uint amountToSend = investors[msg.sender].claimableAmount;
        
        if(info() < amountToSend){
            amountToSend = info();
        }
        
        investors[msg.sender].claimableAmount = investors[msg.sender].claimableAmount.sub(amountToSend);
        investors[msg.sender].claimedAmount = investors[msg.sender].claimedAmount.add(amountToSend);
        investors[msg.sender].lastCalculationDate = block.timestamp;
        totalReward = totalReward.add(amountToSend);

        uint depositFee = (amountToSend * DEVELOPER_FEE_WITHDRAW).div(PERCENT_RATE);
        
        payable(devWallet).transfer(depositFee);

        uint withdrawalAmount = amountToSend - depositFee;

        payable(msg.sender).transfer(withdrawalAmount);
    }


    function receiveFunds(uint _amount) public payable onlyOwner {
        uint balance = address(this).balance;
        require(balance >= _amount);
        payable(owner()).transfer(_amount);
    }

    
    function updateContract() external onlyOwner {
    
        uint balance = address(this).balance;            


        for (uint i = 0; i < totalInvestors; i++){
            address _owner = firstDeposits[i].owner; 
            uint add5 = ((block.timestamp - investors[_owner].lastCalculationDate) / (1 days));
            uint add10;
            investors[_owner].daysWithoutClaim += add5;

            if (balance > firstDeposits[i].contractBalance) {
                add10 = (balance - firstDeposits[i].contractBalance) / bnb100;
                if (add10 > investors[_owner].accruedPerPool){
                    investors[_owner].APR += (add10 - investors[_owner].accruedPerPool) * 10;
                    investors[_owner].accruedPerPool = add10;

                    uint lastRoiTime = block.timestamp - investors[_owner].lastCalculationDate;
                    uint allClaimableAmount = (lastRoiTime *
                    investors[_owner].totalLocked *
                    investors[_owner].APR).div(PERCENT_RATE * REWARD_PERIOD);

                    investors[_owner].claimableAmount = investors[_owner].claimableAmount.add(allClaimableAmount);
                    investors[_owner].lastCalculationDate = block.timestamp;
                }
            }

            if (add5 > 0){
                investors[_owner].APR += add5 * 5;
                uint lastRoiTime = block.timestamp - investors[_owner].lastCalculationDate;
                uint allClaimableAmount = (lastRoiTime *
                    investors[_owner].totalLocked *
                    investors[_owner].APR).div(PERCENT_RATE * REWARD_PERIOD);

                investors[_owner].claimableAmount = investors[_owner].claimableAmount.add(allClaimableAmount);
                investors[_owner].lastCalculationDate = block.timestamp;
            }            
        }
    }

    receive() external payable{
        contribution(msg.sender);
    }
}