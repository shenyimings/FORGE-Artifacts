//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "../src/libraries/LibSanitize.sol";

contract SanitizedInputs {
    function setAddress(address _address) external pure {
        LibSanitize._notZeroAddress(_address);
    }

    function setString(string calldata _string) external pure {
        LibSanitize._notEmptyString(_string);
    }

    function setFee(uint256 _fee) external pure {
        LibSanitize._validFee(_fee);
    }
}

contract SanitizeTest is Test {
    SanitizedInputs internal si;

    function setUp() external {
        si = new SanitizedInputs();
    }

    function testSetZeroAddress() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        si.setAddress(address(0));
    }

    function testSetNonZeroAddress() external {
        address validAddress = makeAddr("validAddress");
        si.setAddress(validAddress);
    }

    function testSetEmptyString() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyString()"));
        si.setString("");
    }

    function testSetNonEmptyString() external view {
        string memory _string = "valid string";
        si.setString(_string);
    }

    function testSetFeeTooHigh() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidFee()"));
        si.setFee(10001);
    }

    function testSetValidFee() external view {
        uint256 validFee = 10000;
        si.setFee(validFee);
    }
}
