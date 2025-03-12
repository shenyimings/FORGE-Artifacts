pragma solidity 0.8 ;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MedPingToken is ERC20,Ownable{

    /// @notice Contract ownership will be renouced after all the lock and burn is fullfilled. 
    using SafeMath for uint256;
    uint256 tSupply = 200 * 10**6 * (10 ** uint256(decimals()));
    uint256 crowdsaleBal; // token remaining after crowdsale 
    uint256 firstListingDate = 1; //date for first exchange listing
    /** If false we are are in transfer lock up period.*/
    bool public released = false;
    bool burnBucketEmptied = false;
    address public crowdsale; //crowdsale address
    struct lockAllowance{
        uint256 total; uint256 allowance; uint256 spent; uint lockStage;
    }
    mapping(address => lockAllowance) lockAllowances; //early investors allowance profile
    mapping(address => bool) earlyInvestors;//list of early investors

    /** MODIFIER: Limits token transfer until the lockup period is over.*/
    modifier canTransfer() {
        if(!released) {
            require(crowdsale == msg.sender,"you are not permitted to make transactions");
        }
        _;
    }
    /** MODIFIER: Limits actions to only crowdsale.*/
    modifier onlyCrowdSale() {
        require(crowdsale == msg.sender,"you are not permitted to make transactions");
        _;
    }
    /** MODIFIER: Limits and manages early investors transfer.
    *check if is early investor and if within the 30days constraint
    */
    modifier investorChecks(uint256 _value,address _sender){
        if( (firstListingDate + 30 days) > block.timestamp){ //is investor and within 30days constraint 
            if(isEarlyInvestor(msg.sender)){
                 require(provisionLockAllownces(_sender)); //provision allowance and update stage
                 lockAllowance storage lock = lockAllowances[_sender]; 
                 require(lock.allowance >= _value); //validate spending amount
                 require(updateLockAllownces(_value,_sender)); //update lock spent 
            }
        }
        _;
    }
    
    constructor() ERC20("Medping", "PING"){
        _mint(msg.sender, tSupply);
    }
    /** Allows only the crowdsale address to relase the tokens into the wild */
    function releaseTokenTransfer() onlyCrowdSale() public {
            released = true;       
    }
    /**Set the crowdsale address. **/
    function setReleaser(address _crowdsale) onlyOwner() public {
        crowdsale = _crowdsale;
    }
    /** update token remaining after crowdsale .*/
    function updatecrowdsaleBal(uint256 amount) public onlyCrowdSale() returns(bool success) {
        crowdsaleBal = amount;
        return true;
    }
    function getCrowdsaleBal()  public view returns(uint256) {
        return crowdsaleBal;
    }
    function investorAllowance(address investor) public view returns (uint256 total,uint256 allowance,uint256 spent, uint lockStage){
        lockAllowance storage l =  lockAllowances[investor];
        return (l.total,l.allowance,l.spent,l.lockStage);
    }
     /** lock early investments per tokenomics.*/
    function addToLock(uint256 _total,address _investor) public onlyCrowdSale(){
        //check if the early investor's address is not registered
        if(!earlyInvestors[_investor]){
            lockAllowance memory lock;
            lock.total = _total;
            lock.allowance = 0;
            lock.spent = 0;
            lockAllowances[_investor] = lock;
            earlyInvestors[_investor]=true;
        }else{
            updateLockTotal(_total,_investor);
        }
    }
     /** update investments lock total.*/
    function updateLockTotal(uint256 _total, address _investor) internal returns(bool){
        lockAllowance storage lock = lockAllowances[_investor];
        lock.total = lock.total + _total;
        return true;
    }
     /** update allowance box.*/
    function updateLockAllownces(uint256 _spending, address _sender) internal returns (bool){
        lockAllowance storage lock = lockAllowances[_sender];
        lock.allowance = lock.allowance - _spending;
        lock.spent = lock.spent + _spending;
        return true; 
    }
     /** provision allowance box.*/
    function provisionLockAllownces(address _sender) internal   returns (bool){
        lockAllowance storage lock = lockAllowances[_sender];
        if((firstListingDate + 7 days <= block.timestamp) && (firstListingDate + 13 days >= block.timestamp)){
            if(lock.lockStage < 1){//first allowance 
                lock.allowance = (lock.total.mul(50 *100)).div(10000); //provision allowance = 50% of investments
                lock.lockStage = 1;
            }
        }else if((firstListingDate + 14 days <= block.timestamp) && (firstListingDate + 29 days >= block.timestamp)){ 
            if(lock.lockStage == 1){//second allowance
                lock.allowance = ((lock.total.mul(70 *100)).div(10000) - (lock.total.mul(50 *100)).div(10000)) + lock.allowance; //provision allowance = 70% of remaining investments
                lock.lockStage = 2;
            }
        }
        return true; 
    }
    function isEarlyInvestor(address investor) public view returns(bool){
        if(earlyInvestors[investor]){
            return true; 
        }
        return false;
    }
    function setFirstListingDate(uint256 _date) public onlyOwner() returns(bool){
        firstListingDate = _date;
        return true; 
    } 
    function getFirstListingDate() public view returns(uint256){
        return firstListingDate;
    }
    function transfer(address _to, uint256 _value) canTransfer() investorChecks(_value,msg.sender) public override returns (bool success) {
        super.transfer(_to,_value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) canTransfer() investorChecks(_value,_from) public override returns (bool success) {
       super.transferFrom(_from, _to, _value);
        return true;
    }
    /**
    *TO BE USED BY OWNER ONLY and once! 
    *This burns 5% of the total supply of the PINGTOKEN plus any remaining tokens after the crowdsale 
    */
    function emptyBurnBucket() public onlyOwner returns(bool success){
        require(!burnBucketEmptied);
        uint256 burnBucket = (tSupply.mul(5 *100)).div(10000); // 5% of total supply
        uint256 totalToBurn = burnBucket + crowdsaleBal; 
        _burn(msg.sender, totalToBurn);
        burnBucketEmptied = true;
        return true;
    }
    function isBurnBucketEmpty() public view  returns(bool){
        return burnBucketEmptied;
    }

    
}