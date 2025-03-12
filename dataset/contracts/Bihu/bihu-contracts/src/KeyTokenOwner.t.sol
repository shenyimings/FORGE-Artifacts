pragma solidity 0.4.18;

import "ds-test/test.sol";

import "ds-token/token.sol";

import "./KeyTokenReborn.sol";
import "./KeyTokenOwner.sol";

contract KeyTokenFoundation {

    DSToken key;

    function KeyTokenFoundation() {}

    function setKey(DSToken _key) {
        key = _key;
    }

    function setKeyOwner(address _owner) {
        key.setOwner(_owner);
    }

    function doTransfer(address to, uint256 amount) returns (bool){
        return key.transfer(to, amount);
    }
}

contract KeyTokenOwnerTest is DSTest {
    KeyTokenReborn keyReborn;
    DSToken key;

    KeyTokenFoundation keyFoundation;
    KeyTokenOwner keyOwner;

    function setUp() {
        keyFoundation = new KeyTokenFoundation();
        keyReborn = new KeyTokenReborn(keyFoundation);

        key = keyReborn.key();
        keyFoundation.setKey(key);

        keyOwner = new KeyTokenOwner(key);
        keyFoundation.setKeyOwner(keyOwner);
    }

    function testTokenOwner() {
        assertEq(key.owner(), keyOwner);
    }

    function testTokenBalance() {
        assertEq(key.balanceOf(keyFoundation), (10 ** 11)* 1 ether);
    }

    function testTokenTransfer() {
        keyFoundation.doTransfer(0x1234, (10 ** 10)* 1 ether);

        assertEq(key.balanceOf(keyFoundation), 9 * (10 ** 10)* 1 ether);
    }

    // new owner is keyOwner
    function testFailTokenSetOwner() {
        keyFoundation.setKeyOwner(0x1234);
    }

    function testFailTokenTransferWhenTokenStop() {
        keyOwner.stopKeyToken();
        keyFoundation.doTransfer(0x1234, (10 ** 10)* 1 ether);
    }
}
