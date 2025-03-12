// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract randomSource is Ownable {
    using SafeMath for uint256;
    using SafeMath for uint16;
    
    uint256 private randNonce;
    uint256 constant private MAX_NONCE = 354183101105107135153161173 ;

  
    function seedMod(uint256 _modulus) public returns(uint256){
        return  _seed() % _modulus;                                    
    }

    function seedModU16List(uint256 _modulus, uint256 _amount) public returns(uint16[] memory){
        require(_modulus < 65535, "invalid mod");
        uint16[] memory res = new uint16[](_amount);
        for(uint i = 0; i < _amount; i++){
            res[i] = uint16(_seed() % _modulus);
        }
        return res;
    }

    function seed() public returns(uint256){
        return  _seed();                                    
    }


    function genWithWeightDistributionU16(uint16[] memory _weightList) external returns (uint16){
        uint16[] memory sumList =  new uint16[](_weightList.length + 1);
        sumList[0] = 0;
        for (uint16 i = 0; i < _weightList.length; i++){
            sumList[i+1] = sumList[i] + _weightList[i];
        }
        uint16 _value = uint16(seedMod(sumList[_weightList.length]));
        (uint16 _loc, ) = _getLocU16(sumList, _value, 0, uint16(_weightList.length));
        return _loc;
    }

    function genWithWSumDistributionU16Sum(uint16[] memory _sumList) public returns (uint16){
        uint16 _value = uint16(seedMod(_sumList[_sumList.length-1]));
        (uint16 _loc, ) = _getLocU16(_sumList, _value, 0, uint16(_sumList.length-1));
        return _loc;
    }

    function genWithPriorDistributionU16SumList(uint16[] memory _sumList, uint256 _amount) public returns (uint16[] memory){
        uint16[] memory resList = new uint16[](_amount);
        for(uint256 i = 0; i < _amount; i++){
            resList[i] = genWithWSumDistributionU16Sum(_sumList);
        }
        return resList;
    }




    //------------internal
    function _seed() internal returns (uint256) {
        uint256 res = uint256(keccak256(abi.encodePacked(block.timestamp,
                                                randNonce.mul(13),
                                                msg.sender,
                                                randNonce)));

        randNonce = randNonce.add(res.div(75017)).mod(MAX_NONCE);          
        return res;
    }

    function _getLocU16(uint16[] memory _acumList, uint16 _value,  uint16 _start, uint16 _end) internal view returns (uint16, uint16){
        if (_end.sub(_start) <= 1) 
            return (_start, _end);
        uint16 center = (_end + _start)/2;
        if (_acumList[center] > _value)
            return _getLocU16(_acumList, _value, _start, center);
        else
            return _getLocU16(_acumList, _value, center, _end);
    }
}
