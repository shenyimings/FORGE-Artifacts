// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "https://github.com/Woonkly/OpenZeppelinBaseContracts/contracts/math/SafeMath.sol";
import "https://github.com/Woonkly/MartinHSolUtils/Utils.sol";
import "https://github.com/Woonkly/OpenZeppelinBaseContracts/contracts/GSN/Context.sol";


contract Erc20Manager is Context {

 using SafeMath for uint256;

    struct E20 {
    address sc;
    uint8 flag; //0 no exist  1 exist 2 deleted
    
  }

  // las index of 
  uint256 internal _lastIndexE20s;
  // store new  by internal  id (_lastIndexE20s)
  mapping(uint256 => E20) internal _E20s;    
  // store address  -> internal  id (_lastIndexE20s)
  mapping(address => uint256) internal _IDE20sIndex;    
 uint256 internal _E20Count;

 

constructor ()  internal {
    
      _lastIndexE20s = 0;
       _E20Count = 0;

    }    


    function hasContracts() public view returns(bool){
        if(_E20Count==0) {
            return false;
        }
        return true;
    }

    function getERC20Count() public view returns (uint256) {
        return _E20Count;
    }

    function getLastIndexERC20s() public view returns (uint256) {
        return _lastIndexE20s;
    }


    function ERC20Exist(address sc) public view returns (bool) {
        return _E20Exist( _IDE20sIndex[sc]);
    }

    function ERC20IndexExist(uint256 index) public view returns (bool) {
        
        if(_E20Count==0) return false;
        
        if(index <  (_lastIndexE20s + 1) ) return true;
        
        return false;
    }


    function _E20Exist(uint256 E20ID)internal view returns (bool) {
        
        //0 no exist  1 exist 2 deleted
        if(_E20s[E20ID].flag == 1 ){ 
            return true;
        }
        return false;         
    }


      modifier onlyNewERC20(address sc) {
        require(!this.ERC20Exist(sc), "E2 Exist");
        _;
      }
      
      
      modifier onlyERC20Exist(address sc) {
        require(this.ERC20Exist(sc), "E2 !Exist");
        _;
      }
      
      modifier onlyERC20IndexExist(uint256 index) {
        require(this.ERC20IndexExist(index), "E2I !Exist");
        _;
      }
  
  
  
  
  event NewERC20(address sc);
    
     
 function newERC20(address sc ) internal onlyNewERC20(sc) returns (uint256){
    _lastIndexE20s=_lastIndexE20s.add(1);
    _E20Count=  _E20Count.add(1);
    
    _E20s[_lastIndexE20s].sc = sc;
    _E20s[_lastIndexE20s].flag = 1;
    
    _IDE20sIndex[sc] = _lastIndexE20s;

    emit NewERC20(sc);
    return _lastIndexE20s;
}    





event ERC20Removed(address sc);

function removeERC20(address sc) internal onlyERC20Exist(sc) {
    _E20s[ _IDE20sIndex[sc] ].flag = 2;
    _E20s[ _IDE20sIndex[sc] ].sc=address(0);
    _E20Count=  _E20Count.sub(1);
    emit ERC20Removed( sc);
}







function getERC20ByIndex(uint256 index) public view  returns( address) {
    
        if(!ERC20IndexExist( index)) return address(0);
     
        E20 memory p= _E20s[ index ];
         
        return p.sc;
    }



function getAllERC20() public view returns(uint256[] memory, address[] memory ) {
  
    uint256[] memory indexs=new uint256[](_E20Count);
    address[] memory pACCs=new address[](_E20Count);
    uint256 ind=0;
    
    for (uint32 i = 0; i < (_lastIndexE20s +1) ; i++) {
        E20 memory p= _E20s[ i ];
        if(p.flag == 1 ){
            indexs[ind]=i;
            pACCs[ind]=p.sc;
            ind++;
        }
    }

    return (indexs, pACCs);

}

event AllERC20Removed();
function removeAllERC20() internal returns(bool){
    for (uint32 i = 0; i < (_lastIndexE20s +1) ; i++) {
        _IDE20sIndex[_E20s[ i ].sc] = 0;
        _E20s[ i ].flag=0;
        _E20s[ i ].sc=address(0);
    }
    _lastIndexE20s = 0;
    _E20Count = 0;
    emit AllERC20Removed();
    return true;
}
  







    
}