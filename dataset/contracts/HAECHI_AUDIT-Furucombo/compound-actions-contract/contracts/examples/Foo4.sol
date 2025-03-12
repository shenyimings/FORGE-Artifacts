pragma solidity ^0.6.0;

contract Foo4 {
    bytes32 public bValue;
    uint256 public nValue;

    function bar() external returns (bytes32) {
        return
            0x0000000000000000000000000000000000000000000000000123456789abcdef;
    }

    function barUint() external returns (uint256) {
        nValue = 1 ether;
        return nValue;
    }

    function bar1(bytes32 a) external returns (bytes32) {
        bValue = a;
        return bValue;
    }

    function bar2(bytes32 a, bytes32 b) external returns (bytes32) {
        bValue = b;
        return bValue;
    }

    function barUint1(uint256 a) external returns (uint256) {
        nValue = a;
        return nValue;
    }

    function barUList(
        uint256 a,
        uint256 b,
        uint256 c
    ) external returns (uint256[] memory) {
        uint256[] memory uList = new uint256[](3);
        uList[0] = a;
        uList[1] = b;
        uList[2] = c;
        return uList;
    }
}
