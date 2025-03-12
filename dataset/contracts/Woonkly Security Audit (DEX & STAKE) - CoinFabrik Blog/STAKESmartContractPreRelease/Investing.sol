// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "https://github.com/Woonkly/OpenZeppelinBaseContracts/contracts/math/SafeMath.sol";
import "https://github.com/Woonkly/MartinHSolUtils/Utils.sol";
import "https://github.com/Woonkly/MartinHSolUtils/Owners.sol";


contract Investing  is Owners{

 using SafeMath for uint256;

    struct Freeze {
    address account;
    uint256 fund;
    uint256 date;
    uint256 delivered;
    uint8 flag; //0 no exist  1 exist 2 deleted
    
  }

  // las index of 
  uint256 internal _lastIndexFreezes;
  // store new  by internal  id (_lastIndexFreezes)
  mapping(uint256 => Freeze) internal _Freezes;    
  // store address  -> internal  id (_lastIndexFreezes)
  mapping(address => uint256) internal _IDFreezesIndex;    
 uint256 internal _FreezeCount;

uint256 _totalFunds;
uint256 _totalDelivered;
 

constructor () public   {
    
      _lastIndexFreezes = 0;
       _FreezeCount = 0;
       _totalFunds =0;
       _totalDelivered =0;
       

    }    


    function getStadistics()public view returns(uint256,uint256,uint256){
        return (_FreezeCount,_totalFunds,_totalDelivered);
    }

    function getFreezeCount() public view returns (uint256) {
        return _FreezeCount;
    }
    
    function getLastIndexFreezes() public view returns (uint256) {
        return _lastIndexFreezes;
    }

    
    


    function FreezeExist(address account) public view returns (bool) {
        return _FreezeExist( _IDFreezesIndex[account]);
    }

    function FreezeIndexExist(uint256 index) public view returns (bool) {
        
        if(_FreezeCount==0) return false;
        
        if(index <  (_lastIndexFreezes + 1) ) return true;
        
        return false;
    }


    function _FreezeExist(uint256 FreezeID)internal view returns (bool) {
        
        //0 no exist  1 exist 2 deleted
        if(_Freezes[FreezeID].flag == 1 ){ 
            return true;
        }
        return false;         
    }


      modifier onlyNewFreeze(address account) {
        require(!this.FreezeExist(account), "This Freeze account exist");
        _;
      }
      
      
      modifier onlyFreezeExist(address account) {
        require(FreezeExist(account), "This Freeze account not exist");
        _;
      }
      
      modifier onlyFreezeIndexExist(uint256 index) {
        require(FreezeIndexExist(index), "This Freeze index not exist");
        _;
      }
  
  
  
  
  event addNewFreeze(address account,uint256 amount);
 function _newFreeze(address account,uint256 amount,uint256 date ) internal onlyNewFreeze(account) returns (uint256){
     
    _lastIndexFreezes=_lastIndexFreezes.add(1);
    _FreezeCount=  _FreezeCount.add(1);
    
    _Freezes[_lastIndexFreezes].account = account;
    _Freezes[_lastIndexFreezes].fund = amount;
    _Freezes[_lastIndexFreezes].delivered = 0;
    _Freezes[_lastIndexFreezes].date = date;
    _Freezes[_lastIndexFreezes].flag = 1;
    
    _IDFreezesIndex[account] = _lastIndexFreezes;
    
    _totalFunds=_totalFunds.add(amount);

    emit addNewFreeze(account,amount);
    return _lastIndexFreezes;
}    

 
    
     
 function newFreeze(address account,uint256 amount ) public onlyIsInOwners  returns (uint256){
     require(account != address(0), "newFreeze: 0 address!");
     require(amount>0,"newFreeze: 0 amount!");
     return _newFreeze( account, amount ,now); 
     
}    



event FreezeRemoved(address account);

function _removeFreeze(address account) internal onlyFreezeExist(account) {
    
    _totalFunds=_totalFunds.sub(_Freezes[ _IDFreezesIndex[account] ].fund);
    _totalDelivered=_totalDelivered.sub(_Freezes[ _IDFreezesIndex[account] ].delivered);

    _Freezes[ _IDFreezesIndex[account] ].flag = 2;
    _Freezes[ _IDFreezesIndex[account] ].account=address(0);
    _Freezes[ _IDFreezesIndex[account] ].fund=0;
    _Freezes[ _IDFreezesIndex[account] ].date=0;
    _Freezes[ _IDFreezesIndex[account] ].delivered=0;

    _FreezeCount=  _FreezeCount.sub(1);
    emit FreezeRemoved( account);
}

function removeFreeze(address account)  public onlyIsInOwners {
    _removeFreeze(account);
}




 function getFreeze(address account) public view returns( uint256 , uint256 , uint256 ) {
     
        if(!FreezeExist( account)) return (0,0,0);
     
        Freeze memory p= _Freezes[ _IDFreezesIndex[account] ];
         
        return (p.fund  ,p.date , p.delivered );
    }



function getFreezeByIndex(uint256 index) public view  returns( uint256 , uint256 , uint256 ) {
    
        if(!FreezeIndexExist( index)) return (0,0,0);
     
        Freeze memory p= _Freezes[ index ];
         
        return (p.fund  ,p.date , p.delivered );
    }



function getAllFreeze() public view returns(uint256[] memory, address[] memory ,uint256[] memory , uint256[] memory , uint256[] memory ) {
  
    uint256[] memory indexs=new uint256[](_FreezeCount);
    address[] memory pACCs=new address[](_FreezeCount);
    uint256[] memory pFunds=new uint256[](_FreezeCount);
    uint256[] memory pDates=new uint256[](_FreezeCount);
    uint256[] memory pDelivereds=new uint256[](_FreezeCount);

    uint256 ind=0;
    
    for (uint32 i = 0; i < (_lastIndexFreezes +1) ; i++) {
        Freeze memory p= _Freezes[ i ];
        if(p.flag == 1 ){
            indexs[ind]=i;
            pACCs[ind]=p.account;
            pFunds[ind]=p.fund;
            pDates[ind]=p.date;
            pDelivereds[ind]=p.delivered;

            ind++;
        }
    }

    return (indexs, pACCs, pFunds,pDates,pDelivereds);

}



function updateFund(address account,uint256 withdraw) public onlyIsInOwners  returns(bool){
    
    if(!FreezeExist(account)) return true;

    Freeze memory p= _Freezes[ _IDFreezesIndex[account] ];

    uint256 canw=howMuchCanWithdraw(account,p.fund);
    
    if(withdraw > canw) return false;
    

    _Freezes[ _IDFreezesIndex[account] ].delivered=_Freezes[ _IDFreezesIndex[account] ].delivered.add(withdraw);
    
    _totalDelivered=_totalDelivered.sub(withdraw);
    return true;
}



function canWithdrawFunds(address account,uint256 withdraw,uint256 currentFund) public view returns(bool){
    if(!FreezeExist(account)) return true;
    
    uint256 can =howMuchCanWithdraw( account, currentFund);
    
    if(can >= withdraw) return true;
    
    return false;
    
}


function howMuchCanWithdraw(address account,uint256 currentFund) public view returns(uint256){
    
    if(!FreezeExist(account)) return currentFund;

    uint256 fund;
    uint256 delivered;
    uint256 date;
    
    (fund,date,delivered)=getFreeze( account);
    
    uint256 dif=0;
    if(currentFund > fund){
        dif=currentFund - fund;
    }

    uint256 unf=calcUnfreezed(fund,date,delivered);
    
    return dif + unf;
}



function calcUnfreezed(uint256 fund,uint256 date,uint256 delivered) public view returns(uint256){

    if(fund==0|| date==0)  return 0;
    
    uint256 unf=getHowMuchUnfreezed(date, now, fund);
    
    if(unf==0)  return 0;
    
    if(delivered >= unf) return 0;

    return unf - delivered;
    
}



function getHowMuchUnfreezed(uint256 dateIni, uint256 dateEnd, uint256 fund) public pure returns(uint256){
    
    
    
    if(fund==0) return 0;
    
    if( dateIni >= dateEnd ) return 0;
    
    uint256 year=60*60*24*365;
    
    uint256 secs= dateEnd.sub(dateIni);
    
    
    uint8 yearsq=uint8(secs / year);

    if(yearsq==0) return 0;
    
    uint8 perc=getPercent(yearsq);
    
    return fund.mul(perc) / 100;

    
}



function getPercent(uint8 yearsq) pure public returns(uint8) {
    
    if(yearsq >= 0 && yearsq < 14 ){
        return yearsq;
    }
    
    return 100;
    
}

    
}