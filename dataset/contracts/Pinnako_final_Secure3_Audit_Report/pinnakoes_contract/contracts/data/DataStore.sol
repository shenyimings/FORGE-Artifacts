// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../utils/EnumerableValues.sol";


contract DataStore {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableValues for EnumerableSet.AddressSet;
    using EnumerableValues for EnumerableSet.Bytes32Set;
    using EnumerableValues for EnumerableSet.UintSet;

    mapping(bytes32 => EnumerableSet.UintSet) internal uintSetValues;
    mapping(bytes32 => EnumerableSet.Bytes32Set) internal bytes32SetValues;
    mapping(bytes32 => EnumerableSet.AddressSet) internal addressSetValues;
  
    mapping(bytes32 => uint256) internal uintValues;
    mapping(bytes32 => int256) internal intValues;
    mapping(bytes32 => address) internal addressValues;
    mapping(bytes32 => bytes32) internal dataValues;
    mapping(bytes32 => bool) internal boolValues;

    mapping(address => mapping(bytes32 => EnumerableSet.UintSet)) internal addUintSetValues;
    mapping(address => mapping(bytes32 => EnumerableSet.Bytes32Set)) internal addDataSetValues;
    mapping(address => mapping(bytes32 => EnumerableSet.AddressSet)) internal addAddressSetValues;
    
    mapping(address => mapping(bytes32 => uint256)) internal addUintValues;
    mapping(address => mapping(bytes32 => address)) internal addAddressValues;
    mapping(address => mapping(bytes32 => bool)) internal addBoolValues;
    

    function grantAddressSet(bytes32 _key, address _account) internal {
        addressSetValues[_key].add(_account);
    }
    function safeGrantAddressSet(bytes32 _key, address _account) internal {
        if (!addressSetValues[_key].contains(_account))
            addressSetValues[_key].add(_account);
    }
    function revokeAddressSet(bytes32 _key, address _account) internal {
        addressSetValues[_key].remove(_account);
    }
    function safeRevokeAddressSet(bytes32 _key, address _account) internal {
        if (addressSetValues[_key].contains(_account))
            addressSetValues[_key].remove(_account);
    }
    function hasAddressSet( bytes32 _key, address _account) public view returns (bool) {
        return addressSetValues[_key].contains(_account);
    }
    function getAddressSetCount(bytes32 _key) public view returns (uint256) {
        return addressSetValues[_key].length();
    }
    function getAddressSetRoles(bytes32 _key, uint256 _start, uint256 _end) public view returns (address[] memory) {
        return addressSetValues[_key].valuesAt(_start, _end);
    }


    function grantUintSet(bytes32 _key, uint256 _value) internal {
        uintSetValues[_key].add(_value);
    }
    function revokeUintSet(bytes32 _key, uint256 _value) internal {
        uintSetValues[_key].remove(_value);
    }
    function hasUintSet( bytes32 _key, uint256 _value) public view returns (bool) {
        return uintSetValues[_key].contains(_value);
    }
    function getUintSetCount(bytes32 _key) public view returns (uint256) {
        return uintSetValues[_key].length();
    }
    function getUintetRoles(bytes32 _key, uint256 _start, uint256 _end) public view returns (uint256[] memory) {
        return uintSetValues[_key].valuesAt(_start, _end);
    }

    function grantBytes32Set(bytes32 _key, bytes32 _content) internal {
        bytes32SetValues[_key].add(_content);
    }
    function revokeBytes32Set(bytes32 _key, bytes32 _content) internal {
        bytes32SetValues[_key].remove(_content);
    }
    function hasBytes32Set( bytes32 _key, bytes32 _content) public view returns (bool) {
        return bytes32SetValues[_key].contains(_content);
    }
    function getBytes32SetCount(bytes32 _key) public view returns (uint256) {
        return bytes32SetValues[_key].length();
    }
    function getBytes32SetRoles(bytes32 _key, uint256 _start, uint256 _end) public view returns (bytes32[] memory) {
        return bytes32SetValues[_key].valuesAt(_start, _end);
    }


    function grantAddMpAddressSet( bytes32 _key, address _account) internal {
        address _mpaddress = msg.sender;
        grantAddMpAddressSetForAccount(_mpaddress, _key, _account);
    }
    function revokeAddMpAddressSet( bytes32 _key, address _account) internal {
        address _mpaddress = msg.sender;
        revokeAddMpAddressSetForAccount(_mpaddress, _key, _account);
    }
    function grantAddMpAddressSetForAccount(address _mpaddress, bytes32 _key, address _account) internal {
        addAddressSetValues[_mpaddress][_key].add(_account);
    }
    function revokeAddMpAddressSetForAccount(address _mpaddress, bytes32 _key, address _account) internal {
        addAddressSetValues[_mpaddress][_key].remove(_account);
    }
    function hasAddMpAddressSet(address _mpaddress,  bytes32 _key, address _account) public view returns (bool) {
        return addAddressSetValues[_mpaddress][_key].contains(_account);
    }
    function getAddMpAddressSetCount(address _mpaddress, bytes32 _key) public view returns (uint256) {
        return addAddressSetValues[_mpaddress][_key].length();
    }
    function getAddMpAddressSetRoles(address _mpaddress, bytes32 _key, uint256 _start, uint256 _end) public view returns (address[] memory) {
        return addAddressSetValues[_mpaddress][_key].valuesAt(_start, _end);
    }


    function grantAddMpUintSet(bytes32 _key, uint256 _value) internal {
        address _mpaddress = msg.sender;
        grantAddMpUintSetForAccount(_mpaddress, _key, _value);
    }
    function revokeAddMpUintSet(bytes32 _key, uint256 _value) internal {
        address _mpaddress = msg.sender;
        revokeAddMpUintSetForAccount(_mpaddress, _key, _value);
    }
    function grantAddMpUintSetForAccount(address _mpaddress, bytes32 _key, uint256 _value) internal {
        addUintSetValues[_mpaddress][_key].add(_value);
    }
    function revokeAddMpUintSetForAccount(address _mpaddress, bytes32 _key, uint256 _value) internal {
        addUintSetValues[_mpaddress][_key].remove(_value);
    }  
    function hasAddMpUintSet(address _mpaddress,  bytes32 _key, uint256 _value) public view returns (bool) {
        return addUintSetValues[_mpaddress][_key].contains(_value);
    }
    function getAddMpUintSetCount(address _mpaddress, bytes32 _key) public view returns (uint256) {
        return addUintSetValues[_mpaddress][_key].length();
    }
    function getAddMpUintetRoles(address _mpaddress, bytes32 _key, uint256 _start, uint256 _end) public view returns (uint256[] memory) {
        return addUintSetValues[_mpaddress][_key].valuesAt(_start, _end);
    }
    function getAddMpUintetRolesFull(address _mpaddress, bytes32 _key) public view returns (uint256[] memory) {
        return addUintSetValues[_mpaddress][_key].valuesAt(0, addUintSetValues[_mpaddress][_key].length());
    }

    function grantAddMpBytes32Set(bytes32 _key, bytes32 _content) internal {
        address _mpaddress = msg.sender;
        grantAddMpBytes32SetForAccount(_mpaddress, _key, _content);
    }
    function revokeAddMpBytes32Set(bytes32 _key, bytes32 _content) internal  {
        address _mpaddress = msg.sender;
        revokeAddMpBytes32SetForAccount(_mpaddress, _key, _content);
    }
    function grantAddMpBytes32SetForAccount(address _mpaddress, bytes32 _key, bytes32 _content) internal {
        addDataSetValues[_mpaddress][_key].add(_content);
    }
    function revokeAddMpBytes32SetForAccount(address _mpaddress, bytes32 _key, bytes32 _content) internal {
        addDataSetValues[_mpaddress][_key].remove(_content);
    }
    function hasAddMpBytes32Set(address _mpaddress,  bytes32 _key, bytes32 _content) public view returns (bool) {
        return addDataSetValues[_mpaddress][_key].contains(_content);
    }
    function getAddMpBytes32SetCount(address _mpaddress, bytes32 _key) public view returns (uint256) {
        return addDataSetValues[_mpaddress][_key].length();
    }
    function getAddMpBytes32SetRoles(address _mpaddress, bytes32 _key, uint256 _start, uint256 _end) public view returns (bytes32[] memory) {
        return addDataSetValues[_mpaddress][_key].valuesAt(_start, _end);
    }






    function getUint(bytes32 key) public view returns (uint256) {
        return uintValues[key];
    }
    function getAddUint(address _account, bytes32 key) public view returns (uint256) {
        return addUintValues[_account][key];
    }
    function setUint(bytes32 key, uint256 value) internal returns (uint256) {
        uintValues[key] = value;
        return value;
    }
    function setAddUint(address _account, bytes32 key, uint256 value) internal returns (uint256) {
        addUintValues[_account][key] = value;
        return value;
    }

    function incrementUint(bytes32 key, uint256 value) internal returns (uint256) {
        uint256 nextUint = uintValues[key] + value;
        uintValues[key] = nextUint;
        return nextUint;
    }
    function incrementAddUint(address _account, bytes32 key, uint256 value) internal returns (uint256) {
        uint256 nextUint = addUintValues[_account][key] + value;
        addUintValues[_account][key] = nextUint;
        return nextUint;
    }

    function decrementUint(bytes32 key, uint256 value) internal returns (uint256) {
        uint256 nextUint =uintValues[key] > value ? uintValues[key] - value : 0;
        uintValues[key] = nextUint;
        return nextUint;
    }
    function decrementAddUint(address _account, bytes32 key, uint256 value) internal returns (uint256) { 
        uint256 nextUint = addUintValues[_account][key] > value ? addUintValues[_account][key] - value : 0;
        addUintValues[_account][key] = nextUint;
        return nextUint;
    }

    function getInt(bytes32 key) public view returns (int256) {
        return intValues[key];
    }

    function setInt(bytes32 key, int256 value) internal returns (int256) {
        intValues[key] = value;
        return value;
    }


    function incrementInt(bytes32 key, int256 value) internal returns (int256) {
        int256 nextInt = intValues[key] + value;
        intValues[key] = nextInt;
        return nextInt;
    }

    function decrementUint(bytes32 key, int256 value) internal returns (int256) {
        int256 nextInt = intValues[key] - value;
        intValues[key] = nextInt;
        return nextInt;
    }

    function getAddress(bytes32 key) public view returns (address) {
        return addressValues[key];
    }
    function getAddAddress(address _account, bytes32 key) public view returns (address) {
        return addAddressValues[_account][key];
    }
    function setAddress(bytes32 key, address value) internal returns (address) {
        addressValues[key] = value;
        return value;
    }
    function setAddAddress(address _account, bytes32 key, address value) internal returns (address) {
        addAddressValues[_account][key] = value;
        return value;
    }


    function getData(bytes32 key) public view returns (bytes32) {
        return dataValues[key];
    }

    function setData(bytes32 key, bytes32 value) internal returns (bytes32) {
        dataValues[key] = value;
        return value;
    }

    function getBool(bytes32 key) public view returns (bool) {
        return boolValues[key];
    }
    function getAddBool(address _account, bytes32 key) public view returns (bool) {
        return addBoolValues[_account][key];
    }


    function setBool(bytes32 key, bool value) internal returns (bool) {
        boolValues[key] = value;
        return value;
    }
    function setAddBool(address _account, bytes32 key, bool value) internal returns (bool) {
        addBoolValues[_account][key] = value;
        return value;
    }
}
