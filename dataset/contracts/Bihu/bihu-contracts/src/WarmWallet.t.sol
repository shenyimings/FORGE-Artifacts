pragma solidity 0.4.18;


import "ds-test/test.sol";
import "ds-token/token.sol";
import "./WarmWallet.sol";
import "./KeyTokenReborn.sol";


contract Wallet {}

contract Withdrawer {
    WarmWallet warmWallet;
    DSToken key;

    function Withdrawer(address _key) {
        key = DSToken(_key);
    }

    function setWarmWallet(address _warmWallet) {
        warmWallet = WarmWallet(_warmWallet);
    }

    function forwardToHotWallet(uint _amount) {
        warmWallet.forwardToHotWallet(_amount);
    }

    function restoreToColdWallet(uint _amount) {
        warmWallet.restoreToColdWallet(_amount);
    }

}

contract WarmWalletTest is DSTest {

    DSToken key;
    WarmWallet warmWallet;
    KeyTokenReborn keyReborn;

    address hotWallet = new Wallet();
    address coldWallet = new Wallet();
    Withdrawer withdrawer;

    function setUp() {

        keyReborn = new KeyTokenReborn(this);

        key = keyReborn.key();


        withdrawer = new Withdrawer(key);

        warmWallet = new WarmWallet(key, hotWallet, coldWallet, withdrawer, 200 ether);

        withdrawer.setWarmWallet(warmWallet);

        key.transfer(warmWallet, 1000 ether);

    }

    function testTokenBalance() {
        assertEq(key.balanceOf(warmWallet), 1000 ether);
    }

    function testWarmWalletOwner() {
        assertEq(address(warmWallet.owner()), address(this));

        warmWallet.setOwner(0);
        assertEq(address(warmWallet.owner()), address(0));
    }

    function testForwardToHotWallet() {
        withdrawer.forwardToHotWallet(100 ether);

        assertEq(key.balanceOf(hotWallet), 100 ether);
        assertEq(key.balanceOf(warmWallet), 900 ether);
    }

    function testRestoreToColdWallet() {
        withdrawer.restoreToColdWallet(800 ether);

        assertEq(key.balanceOf(coldWallet), 800 ether);
        assertEq(key.balanceOf(warmWallet), 200 ether);
    }


    function testForwardToHotWalletExceedLimit() {
        withdrawer.forwardToHotWallet(500 ether);

        assertEq(key.balanceOf(hotWallet), 200 ether);
        assertEq(key.balanceOf(warmWallet), 800 ether);
    }

    function testFailForwardToHotIn24Hours(){
        withdrawer.forwardToHotWallet(100 ether);
        withdrawer.forwardToHotWallet(100 ether);
    }
}

