// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "https://github.com/Woonkly/OpenZeppelinBaseContracts/contracts/math/SafeMath.sol";
import "https://github.com/Woonkly/OpenZeppelinBaseContracts/contracts/token/ERC20/ERC20.sol";
import "https://github.com/Woonkly/MartinHSolUtils/Utils.sol";

import "https://github.com/Woonkly/MartinHSolUtils/Owners.sol";


contract StakeManager  is Owners, ERC20{

 using SafeMath for uint256;

    struct Stake {
    address account;
    bool autoCompound;
    uint8 flag; //0 no exist  1 exist 2 deleted
    
  }

  // las index of 
  uint256 internal _lastIndexStakes;
  // store new  by internal  id (_lastIndexStakes)
  mapping(uint256 => Stake) internal _Stakes;    
  // store address  -> internal  id (_lastIndexStakes)
  mapping(address => uint256) internal _IDStakesIndex;    
 uint256 internal _StakeCount;

 

constructor (string memory name, string memory symbol)  ERC20(name,symbol) public {
    
      _lastIndexStakes = 0;
       _StakeCount = 0;

    }    
    
    function _transfer(address sender, address recipient, uint256 amount) internal override virtual {
        require(false)  ;  

        
        //require(_inv.canWithdrawFunds(sender,amount,balanceOf(sender)),"WO:!i");
        super._transfer(sender,recipient,amount);
        //_inv.updateFund(sender,amount);
        
    }

    


    function getStakeCount() public view returns (uint256) {
        return _StakeCount;
    }
    
    function getLastIndexStakes() public view returns (uint256) {
        return _lastIndexStakes;
    }

    
    


    function StakeExist(address account) public view returns (bool) {
        return _StakeExist( _IDStakesIndex[account]);
    }

    function StakeIndexExist(uint256 index) public view returns (bool) {
        
        if(_StakeCount==0) return false;
        
        if(index <  (_lastIndexStakes + 1) ) return true;
        
        return false;
    }


    function _StakeExist(uint256 StakeID)internal view returns (bool) {
        
        //0 no exist  1 exist 2 deleted
        if(_Stakes[StakeID].flag == 1 ){ 
            return true;
        }
        return false;         
    }


      modifier onlyNewStake(address account) {
        require(!this.StakeExist(account), "This Stake account exist");
        _;
      }
      
      
      modifier onlyStakeExist(address account) {
        require(StakeExist(account), "This Stake account not exist");
        _;
      }
      

      
      modifier onlyStakeIndexExist(uint256 index) {
        require(StakeIndexExist(index), "This Stake index not exist");
        _;
      }
  
  
  
  
  event addNewStake(address account,uint256 amount);
    
     
 function newStake(address account,uint256 amount ) public onlyIsInOwners onlyNewStake(account) returns (uint256){
    _lastIndexStakes=_lastIndexStakes.add(1);
    _StakeCount=  _StakeCount.add(1);
    
    _Stakes[_lastIndexStakes].account = account;
    _Stakes[_lastIndexStakes].autoCompound=false;
    _Stakes[_lastIndexStakes].flag = 1;
    
    _IDStakesIndex[account] = _lastIndexStakes;

    if(amount>0){
        _mint(account,  amount);        
    }
    
    emit addNewStake(account,amount);
    return _lastIndexStakes;
}    


event StakeAdded(address account, uint256 oldAmount,uint256 newAmount);

function addToStake(address account, uint256 addAmount) public onlyIsInOwners onlyStakeExist(account) returns(uint256){

    uint256 oldAmount = balanceOf(account);    
    if(addAmount>0){
        _mint(account,  addAmount);    
    }
    

    emit StakeAdded( account, oldAmount, addAmount );
    
    return _IDStakesIndex[account];
}   




event StakeReNewed(address account, uint256 oldAmount,uint256 newAmount);

function renewStake(address account, uint256 newAmount) public onlyIsInOwners onlyStakeExist(account) returns(uint256){

    uint256 oldAmount = balanceOf(account);    
    if(oldAmount>0){
        _burn( account,oldAmount);    
    }
    
    if(newAmount>0){
        _mint(account,  newAmount);        
    }
    

    emit StakeReNewed( account, oldAmount, newAmount);
    
    return _IDStakesIndex[account];
}   





event AutoCompoundChanged(address account, bool active);
function setAutoCompound(address account, bool active) public onlyIsInOwners onlyStakeExist(account) returns(uint256){

    _Stakes[ _IDStakesIndex[account] ].autoCompound= active ;
    emit AutoCompoundChanged(account, _Stakes[ _IDStakesIndex[account] ].autoCompound);
    return _IDStakesIndex[account];
}   





event StakeRemoved(address account);

function removeStake(address account) public onlyIsInOwners onlyStakeExist(account) {
    _Stakes[ _IDStakesIndex[account] ].flag = 2;
    _Stakes[ _IDStakesIndex[account] ].account=address(0);
    _Stakes[ _IDStakesIndex[account] ].autoCompound=false;
    uint256 bl=balanceOf(account);
    if(bl>0){
        _burn( account,bl);    
    }
    
    _StakeCount=  _StakeCount.sub(1);
    emit StakeRemoved( account);
}



function getAutoCompoundStatus(address account) public view returns(bool){
    if(!StakeExist( account)) return false;
 
    Stake memory p= _Stakes[ _IDStakesIndex[account] ];
     
    return p.autoCompound ;

}



 function getStake(address account) public view returns( uint256 ,bool) {
     
        if(!StakeExist( account)) return (0,false);
     
        Stake memory p= _Stakes[ _IDStakesIndex[account] ];
         
        return (balanceOf(account)  ,p.autoCompound );
    }



function getStakeByIndex(uint256 index) public view  returns(address, uint256,bool,uint8) {
    
        if(!StakeIndexExist( index)) return (address(0),  0,false,0);
     
        Stake memory p= _Stakes[ index ];
         
        return (p.account, balanceOf(p.account)  ,p.autoCompound ,p.flag);
    }



function getAllStake() public view returns(uint256[] memory, address[] memory ,uint256[] memory , bool[] memory) {
  
    uint256[] memory indexs=new uint256[](_StakeCount);
    address[] memory pACCs=new address[](_StakeCount);
    uint256[] memory pAmounts=new uint256[](_StakeCount);
    bool[] memory pAuto=new bool[](_StakeCount);

    uint256 ind=0;
    
    for (uint32 i = 0; i < (_lastIndexStakes +1) ; i++) {
        Stake memory p= _Stakes[ i ];
        if(p.flag == 1 ){
            indexs[ind]=i;
            pACCs[ind]=p.account;
            pAmounts[ind]=balanceOf(p.account);
            pAuto[ind]=p.autoCompound;
            ind++;
        }
    }

    return (indexs, pACCs, pAmounts,pAuto);

}

event AllStakeRemoved();
function removeAllStake() public onlyIsInOwners returns(bool){
    for (uint32 i = 0; i < (_lastIndexStakes +1) ; i++) {
        _IDStakesIndex[_Stakes[ i ].account] = 0;
        
        address acc=_Stakes[ i ].account;
        _Stakes[ i ].flag=0;
        _Stakes[ i ].account=address(0);
        _Stakes[ i ].autoCompound=false;
        uint256 bl=balanceOf(acc);
        if(bl>0){
            _burn( acc,bl);    
        }
        
        
    }
    _lastIndexStakes = 0;
    _StakeCount = 0;
    emit AllStakeRemoved();
    return true;
}
  







    
}