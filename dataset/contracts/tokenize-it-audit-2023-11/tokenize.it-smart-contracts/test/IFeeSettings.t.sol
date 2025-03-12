// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/interfaces/IFeeSettings.sol";

contract IFeeSettingsTest is Test {
    function testManuallyVerifyInterfaceIDV1() public {
        // see https://medium.com/@chiqing/ethereum-standard-erc165-explained-63b54ca0d273
        bytes4 expected = getFunctionSelector("tokenFee(uint256)");
        expected = expected ^ getFunctionSelector("continuousFundraisingFee(uint256)");
        expected = expected ^ getFunctionSelector("personalInviteFee(uint256)");
        expected = expected ^ getFunctionSelector("feeCollector()");
        expected = expected ^ getFunctionSelector("owner()");
        expected = expected ^ getFunctionSelector("supportsInterface(bytes4)");
        bytes4 actual = type(IFeeSettingsV1).interfaceId;

        // hardcoding this here so this test throws when search and replace changes the interface
        bytes4 fixedValue = 0xc664b798;

        assertEq(actual, fixedValue, "interface ID mismatch: did search and replace change the interface?");

        assertEq(actual, expected, "interface ID mismatch");
    }

    function testManuallyVerifyInterfaceIDV2() public {
        // see https://medium.com/@chiqing/ethereum-standard-erc165-explained-63b54ca0d273
        bytes4 expected = getFunctionSelector("crowdinvestingFee(uint256,address)");
        expected = expected ^ getFunctionSelector("crowdinvestingFeeCollector(address)");
        expected = expected ^ getFunctionSelector("privateOfferFee(uint256,address)");
        expected = expected ^ getFunctionSelector("privateOfferFeeCollector(address)");
        expected = expected ^ getFunctionSelector("tokenFee(uint256,address)");
        expected = expected ^ getFunctionSelector("tokenFeeCollector(address)");
        expected = expected ^ getFunctionSelector("owner()");
        expected = expected ^ getFunctionSelector("supportsInterface(bytes4)");
        bytes4 actual = type(IFeeSettingsV2).interfaceId;

        console.logBytes4(expected);
        console.logBytes4(actual);

        // hardcoding this here so this test throws when search and replace changes the interface
        bytes4 fixedValue = 0x302be8a8;

        assertEq(actual, fixedValue, "interface ID mismatch: did search and replace change the interface?");

        assertEq(actual, expected, "interface ID mismatch");
    }

    function getFunctionSelector(string memory signature) public pure returns (bytes4) {
        return bytes4(keccak256(bytes(signature)));
    }
}
