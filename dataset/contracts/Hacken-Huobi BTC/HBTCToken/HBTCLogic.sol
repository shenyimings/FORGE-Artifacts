pragma solidity ^0.5.11;

import "./SafeMath.sol";
import "./HBTCStorage.sol";

contract HBTCLogic {

    using SafeMath for uint256;

    string public constant name = "HBTCLogic";

    uint256 public constant TASKINIT = 0;
    uint256 public constant TASKPROCESSING = 1;
    uint256 public constant TASKCANCELLED = 2;
    uint256 public constant TASKDONE = 3;
    uint256 public constant MINTTASK = 1;
    uint256 public constant BURNTASK = 2;

    address private caller;
    HBTCStorage private store;

    constructor(address aCaller) public{
        caller = aCaller;
    }

    modifier onlyCaller(){
        require(msg.sender == caller, "only main contract can call");
        _;
    }

    function mintLogic(uint256 value,address to,string calldata proof,
        bytes32 taskHash, address supportAddress, uint256 requireNum)
        external onlyCaller returns(uint256){
        require(to != address(0), "cannot be burned from zero address");
        require(value > 0, "value need > 0");
        require(taskHash == keccak256((abi.encodePacked(to,value,proof))),"taskHash is wrong");
        uint256 status = supportTask(MINTTASK, taskHash, supportAddress, requireNum);

        if( status == TASKDONE){
            uint256 totalSupply = store.getTotalSupply();
            uint256 balanceTo = store.balanceOf(to);
            balanceTo = balanceTo.safeAdd(value);
            totalSupply = totalSupply.safeAdd(value);
            store.setBalance(to,balanceTo);
            store.setTotalSupply(totalSupply);
        }
        return status;
    }

    function burnLogic(address from, uint256 value,string calldata btcAddress,
        string calldata proof,bytes32 taskHash, address supportAddress, uint256 requireNum)
        external onlyCaller returns(uint256){

        uint256 balance = store.balanceOf(from);
        require(balance >= value,"sender address not have enough HBTC");
        require(value > 0, "value need > 0");
        require(taskHash == keccak256((abi.encodePacked(from,value,btcAddress,proof))),"taskHash is wrong");
        uint256 status = supportTask(BURNTASK, taskHash, supportAddress, requireNum);

        if ( status == TASKDONE ){
            uint256 totalSupply = store.getTotalSupply();
            totalSupply = totalSupply.safeSub(value);
            balance = balance.safeSub(value);
            store.setBalance(from,balance);
            store.setTotalSupply(totalSupply);

        }
        return status;
    }

    function transferLogic(address sender,address to,uint256 value) external onlyCaller returns(bool) {
        require(to != address(0), "cannot transfer to address zero");
        require(sender != to, "sender need != to");
        require(value > 0, "value need > 0");
        require(address(store) != address(0), "dataStore address error");

        uint256 balanceFrom = store.balanceOf(sender);
        uint256 balanceTo = store.balanceOf(to);
        require(value <= balanceFrom, "insufficient funds");
        balanceFrom = balanceFrom.safeSub(value);
        balanceTo = balanceTo.safeAdd(value);
        store.setBalance(sender,balanceFrom);
        store.setBalance(to,balanceTo);
        return true;
    }

    function transferFromLogic(address sender,address from,address to,uint256 value) external onlyCaller returns(bool) {
        require(from != address(0), "cannot transfer from address zero");
        require(to != address(0), "cannot transfer to address zero");
        require(value > 0, "can not tranfer zero Token");
        require(from!=to,"from and to can not be be the same ");
        require(address(store) != address(0), "dataStore address error");

        uint256 balanceFrom = store.balanceOf(from);
        uint256 balanceTo = store.balanceOf(to);
        uint256 allowedvalue = store.getAllowed(from,sender);

        require(value <= allowedvalue, "insufficient allowance");
        require(value <= balanceFrom, "insufficient funds");

        balanceFrom = balanceFrom.safeSub(value);
        balanceTo = balanceTo.safeAdd(value);
        allowedvalue = allowedvalue.safeSub(value);

        store.setBalance(from,balanceFrom);
        store.setBalance(to,balanceTo);
        store.setAllowed(from,sender,allowedvalue);
        return true;
    }

    function approveLogic(address sender,address spender,uint256 value)  external onlyCaller returns(bool success){
        require(spender != address(0), "spender address zero");
        require(value > 0, "value need > 0");
        require(address(store) != address(0), "dataStore address error");

        store.setAllowed(sender,spender,value);
        return true;
    }

    function resetStoreLogic(address storeAddress) external onlyCaller {
        store = HBTCStorage(storeAddress);
    }

    function getTotalSupply() public view returns (uint256 supply) {
        return store.getTotalSupply();
    }

    function balanceOf(address owner) public view returns (uint256 balance) {
        return store.balanceOf(owner);
    }

    function getAllowed(address owner, address spender) public view returns (uint256 remaining){
        return store.getAllowed(owner,spender);
    }

    function getStoreAddress() public view returns(address){
        return address(store);
    }

    function supportTask(uint256 taskType, bytes32 taskHash, address oneAddress, uint256 requireNum) private returns(uint256){
        require(!store.supporterExists(taskHash, oneAddress), "supporter already exists");
        (uint256 theTaskType,uint256 theTaskStatus,uint256 theSupporterNum) = store.getTaskInfo(taskHash);
        require(theTaskStatus < TASKDONE, "wrong status");

        if (theTaskStatus != TASKINIT)
            require(theTaskType == taskType, "task type not match");
        store.addSupporter(taskHash, oneAddress);
        theSupporterNum++;
        if(theSupporterNum >= requireNum)
            theTaskStatus = TASKDONE;
        else
            theTaskStatus = TASKPROCESSING;
        store.setTaskInfo(taskHash, taskType, theTaskStatus);
        return theTaskStatus;
    }

    function cancelTask(bytes32 taskHash)  external onlyCaller returns(uint256){
        (uint256 theTaskType,uint256 theTaskStatus,uint256 theSupporterNum) = store.getTaskInfo(taskHash);
        require(theTaskStatus == TASKPROCESSING, "wrong status");
        if(theSupporterNum > 0) store.removeAllSupporter(taskHash);
        theTaskStatus = TASKCANCELLED;
        store.setTaskInfo(taskHash, theTaskType, theTaskStatus);
        return theTaskStatus;
    }
}