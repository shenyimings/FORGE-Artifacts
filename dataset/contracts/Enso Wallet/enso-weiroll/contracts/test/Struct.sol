// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import "../Libraries/Events.sol";
import "../Libraries/Math.sol";

contract Struct is Events, Math {
    struct StringStruct {
      string a;
      string b;
    }

    struct MixedStruct {
      uint256 a;
      address b;
    }

    struct DataStruct {
      bytes32 id;
      uint256 category;
      address from;
      address to;
      uint256 amount;
      bytes data;
    }

    struct UserStruct {
      address from;
      bool approvedTo;
      address to;
      bool approvedFrom;
    }

    struct MultiStruct {
      address a;
      address b;
      DataStruct d;
    }

    struct ArrayStruct {
      address a;
      uint256[] values;
    }

    struct MultiArrayStruct {
      address a;
      uint256[][] values;
    }

    struct StringMultiStruct {
      uint256 a;
      StringStruct b;
    }

    struct NestedStruct1 {
      uint256 a;
      StringMultiStruct b;
    }

    struct NestedStruct2 {
      uint256 a;
      NestedStruct1 b;
    }

    struct NestedStruct3 {
      uint256 a;
      NestedStruct2 b;
    }

    struct BigStruct {
        uint256 a;
        uint256 b;
        uint256 c;
        uint256 d;
        uint256 e;
        uint256 f;
        uint256 g;
        uint256 h;
        uint256 i;
        uint256 j;
        uint256 k;
        uint256 l;
        uint256 m;
        uint256 n;
        uint256 o;
        uint256 p;
        uint256 q;
        uint256 r;
        uint256 s;
        uint256 t;
        uint256 u;
        uint256 v;
        uint256 w;
        uint256 x;
        uint256 y;
        uint256 z;
        uint256 aa;
        uint256 bb;
        uint256 cc;
        uint256 dd;
        uint256 ee;
        uint256 ff;
    }


    function returnStringStruct(StringStruct memory values)
        external
        pure
        returns (string memory, string memory)
    {
        return (values.a, values.b);
    }

    function returnMixedStruct(MixedStruct memory values)
        external
        pure
        returns (uint256, address)
    {
        return (values.a, values.b);
    }


    function returnParamAndStruct(uint256 param, MixedStruct memory values)
        external
        pure
        returns (uint256, uint256, address)
    {
        return (param, values.a, values.b);
    }

    function returnDynamicParamAndStruct(string memory param, MixedStruct memory values)
        external
        returns (string memory, uint256, address)
    {
        emit LogString(param);
        emit LogUint(values.a);
        emit LogAddress(values.b);
        return (param, values.a, values.b);
    }

    function returnComplexStruct(
        DataStruct memory dataStruct,
        UserStruct memory userStruct,
        uint256 amount,
        uint256 timestamp
    )
        external
        returns (bytes32)
    {
        emit LogUint(dataStruct.amount);
        return dataStruct.id;
    }

    function returnMultiStructArray(
        MultiStruct[] memory multiStructs
    )
        external
        returns (uint256, bytes32)
    {
        emit LogUint(multiStructs[0].d.amount);
        return (multiStructs.length, multiStructs[0].d.id);
    }

    function returnNestedStructString(
        NestedStruct3 memory nestedStruct
    )
        external
        returns (string memory)
    {
        emit LogString(nestedStruct.b.b.b.b.a);
        return nestedStruct.b.b.b.b.a;
    }

    function returnArrayStructSum(
        ArrayStruct memory arrayStruct
    )
        external
        returns (uint256)
    {
        uint256 total = sum(arrayStruct.values);
        emit LogUint(total);
        return total;
    }

    function returnArrayOfArrayStructSum(
        ArrayStruct[] memory arrayStructs
    )
        external
        returns (uint256)
    {
        uint256[] memory sums = new uint256[](arrayStructs.length);
        for (uint256 i; i < arrayStructs.length; i++) {
            sums[i] =  sum(arrayStructs[i].values);
        }
        uint256 total = sum(sums);
        emit LogUint(total);
        return total;
    }

    function returnMultiArrayStructSum(
        MultiArrayStruct memory multiArrayStruct
    )
        external
        returns (uint256)
    {
        uint256[] memory sums = new uint256[](multiArrayStruct.values.length);
        for (uint256 i; i < multiArrayStruct.values.length; i++) {
            sums[i] =  sum(multiArrayStruct.values[i]);
        }
        uint256 total = sum(sums);
        emit LogUint(total);
        return total;
    }

    function returnBigStruct(BigStruct memory bigStruct) external returns (uint256) {
        emit LogUint(bigStruct.aa);
        return bigStruct.aa;
    }
}
