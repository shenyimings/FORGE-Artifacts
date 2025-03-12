//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../src/libraries/LibUnstructuredStorage.sol";

contract LibUnstructuredStorageInputs {
    function getStorageBool(bytes32 _position) external view returns (bool data) {
        return LibUnstructuredStorage.getStorageBool(_position);
    }

    function getStorageAddress(bytes32 _position) external view returns (address data) {
        return LibUnstructuredStorage.getStorageAddress(_position);
    }

    function getStorageBytes32(bytes32 _position) external view returns (bytes32 data) {
        return LibUnstructuredStorage.getStorageBytes32(_position);
    }

    function getStorageUint256(bytes32 _position) external view returns (uint256 data) {
        return LibUnstructuredStorage.getStorageUint256(_position);
    }

    function setStorageBool(bytes32 _position, bool _data) external {
        return LibUnstructuredStorage.setStorageBool(_position, _data);
    }

    function setStorageAddress(bytes32 _position, address _data) external {
        LibUnstructuredStorage.setStorageAddress(_position, _data);
    }

    function setStorageBytes32(bytes32 _position, bytes32 _data) external {
        LibUnstructuredStorage.setStorageBytes32(_position, _data);
    }

    function setStorageUint256(bytes32 _position, uint256 _data) external {
        LibUnstructuredStorage.setStorageUint256(_position, _data);
    }
}

contract LibUnstructuredStorageTest is Test {
    LibUnstructuredStorageInputs internal libUnstructuredStorageInputs;
    bytes32 position = keccak256("test");

    function setUp() public {
        libUnstructuredStorageInputs = new LibUnstructuredStorageInputs();
    }

    function testBoolSetterAndGetter() public {
        // Set value
        libUnstructuredStorageInputs.setStorageBool(position, true);
        // Get value
        bool data = libUnstructuredStorageInputs.getStorageBool(position);
        // Assert value
        assert(data);
    }

    function testAddressSetterAndGetter() public {
        libUnstructuredStorageInputs.setStorageAddress(position, address(this));
        // Get value
        address data = libUnstructuredStorageInputs.getStorageAddress(position);
        // Assert value
        assert(data == address(this));
    }

    function testBytes32SetterAndGetter() public {
        // Set value
        libUnstructuredStorageInputs.setStorageBytes32(position, bytes32("test data"));
        // Get value
        bytes32 data = libUnstructuredStorageInputs.getStorageBytes32(position);
        // Assert value
        assert(data == bytes32("test data"));
    }

    function testUint256SetterAndGetter() public {
        // Set value
        libUnstructuredStorageInputs.setStorageUint256(position, 123);
        // Get value
        uint256 data = libUnstructuredStorageInputs.getStorageUint256(position);
        // Assert value
        assert(data == 123);
    }
}
