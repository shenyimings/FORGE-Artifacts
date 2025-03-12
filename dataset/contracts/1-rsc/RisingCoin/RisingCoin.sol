// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RisingCoin {

    address  public owner;
     address payable public wallet;
    string public name; 
    string public symbol; 
    uint256 public balance;
    uint public decimals;
    uint public totalSupply_;
    uint public maxSupply = 1000000000 * 10 ** 18;


    uint256 public dailyMineLimit = 100000 * 10 ** 18;

    uint256 public reward = 10 * 10 ** 18;

    mapping (address => uint256) public lastMineTime;


    uint256 public fourYears = 4 * 365 * 24 * 60 * 60;
    uint256 public halvingInterval = fourYears;
    uint256 public lastHalving;   
     
     uint256 public timeSinceLastHalving;
     uint256 public timeSinceLastMined;

      uint256 public mingingInterval =  24 * 60* 60;
      uint256 public lastMining;    
      uint256 public dailyMineTotal; 
 
    
  mapping(address => uint) balances;
  mapping(address => mapping(address => uint)) allowed; 
 
    

    
   
  


 event TransferReceived(address _from, uint _amount);
 event TransferSent(address _from, address _destAddr, uint _amount);

  event Transfer (address indexed from, address indexed to, uint256 value); 
  event Approval(address indexed owner, address indexed spender, uint256 value);




  modifier sufficientBalance(address _spender, uint _value){
    require(_value <= balances[_spender] , "Insufficient Balance for User");
    _;
  }

  modifier sufficientApproval(address _owner, address _spender, uint _value){
    require(_value <= allowed[_owner][_spender], "Insufficient allowance for this User from owner");
    _;
  }

  modifier validAddress(address _address){
    require(_address != address(0), "Invalid address");
    _;
  } 


   
 




  constructor(uint _totalSupply, uint _decimals, string memory _name, string memory _symbol, address payable _wallet){
      totalSupply_ = _totalSupply * 10 ** 18;
      decimals = _decimals;
      name = _name;
      symbol = _symbol;
       owner = msg.sender;    
      balances[msg.sender] = _totalSupply * 10 ** 18;
      wallet = _wallet;
      timeSinceLastMined = block.timestamp + 24 * 60* 60;
      timeSinceLastHalving = block.timestamp + 4 * 365 * 24 * 60 * 60;
        

  }



      receive() payable external {
        balance += msg.value;
        emit TransferReceived(msg.sender, msg.value);
    }    
    
    function withdraw(uint amount, address payable destAddr) public {
        require(msg.sender == owner, "Only owner can withdraw funds"); 
        require(amount <= balance, "Insufficient funds");
        
        destAddr.transfer(amount);
        balance -= amount;
        emit TransferSent(msg.sender, destAddr, amount);
    }
    
  

  
  function totalSupply() public view virtual returns(uint256){
    return totalSupply_;
  }


  function balanceOf(address _who) public view virtual returns(uint256){
    return balances[_who];
  }

  function transfer(address to, uint256 value) public virtual sufficientBalance(msg.sender, value) validAddress(to) returns(bool){
    balances[msg.sender] = balances[msg.sender] - value;
    balances[to] = balances[to] + value;
    emit Transfer(msg.sender, to, value);
    
    return true;
  }

  function approve(address spender, uint256 value) public virtual validAddress(spender) returns(bool){
    allowed[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);

    return true;
  }
  
  function allowance(address owner_, address spender) public virtual view returns(uint256){
      return allowed[owner_][spender];
  }

  function transferFrom(address from, address to, uint256 value) public virtual sufficientBalance(from, value) sufficientApproval(from, msg.sender, value) validAddress(to) returns(bool){
      allowed[from][msg.sender] = allowed[from][msg.sender] - value; 
      balances[from] = balances[from] - value; 
      balances[to] = balances[to] + value; 
      emit Transfer(from, to, value);
      return true;

  } 


 

 function mine()  external payable returns (bool)  {
        require(msg.value >= 0.00064 ether);
        require(block.timestamp >= lastMineTime[msg.sender] + mingingInterval, "Cannot mine again today.");
        

        require( totalSupply_ <= maxSupply, "No more tokens can be mined.");
        
        lastMineTime[msg.sender] = block.timestamp; 
         updateDailyTotal();

         require(dailyMineTotal <= dailyMineLimit);

        updateMintLimit();
        

        balances[msg.sender] += reward;
        totalSupply_ += reward;
          dailyMineTotal += reward;
          wallet.transfer(msg.value);
        // emit Transfer(address(0), msg.sender, amount);
        return true ;
 } 

 
   function updateMintLimit() internal { 
     
        if (timeSinceLastHalving <= block.timestamp) {
            dailyMineLimit /= 2;
            timeSinceLastHalving = block.timestamp + 4 * 365 * 24 * 60 * 60;
        }
     }


    function updateDailyTotal() internal {
      
        if (timeSinceLastMined <= block.timestamp) {
            dailyMineTotal = 0;
            timeSinceLastMined = block.timestamp + 24 * 60* 60;
        }
    }






  
}