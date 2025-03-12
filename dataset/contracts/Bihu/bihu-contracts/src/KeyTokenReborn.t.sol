pragma solidity ^0.4.11;

import "ds-test/test.sol";

import "ds-token/token.sol";

import "./KeyTokenReborn.sol";


contract KeyTokenOwner {

    DSToken key;

    function KeyTokenOwner() {}

    function setKey(DSToken key_) {
        key = key_;
    }

    function doStop() {
        key.stop();
    }

    function() payable {}

    function doTransfer(address to, uint256 amount) returns (bool){
        return key.transfer(to, amount);
    }
}

contract KeyTokenRebornTest is DSTest {
    KeyTokenReborn keyReborn;
    DSToken key;

    KeyTokenOwner keyFoundation;

    function setUp() {
        keyFoundation = new KeyTokenOwner();
        keyReborn = new KeyTokenReborn(keyFoundation);

        key = keyReborn.key();
        keyFoundation.setKey(key);
    }

    function testTokenBalance() {
        assertEq(key.balanceOf(keyFoundation), (10 ** 11)* 1 ether);
    }

    function testTokenOwner() {
        assertEq(key.owner(), keyFoundation);
    }


    function testTokenTransfer() {
        //assertEq(key.balanceOf(destFound), (10 ** 11)* 1 ether);
        keyFoundation.doTransfer(0x1234, (10 ** 10)* 1 ether);

        assertEq(key.balanceOf(keyFoundation), 9 * (10 ** 10)* 1 ether);

    }
}