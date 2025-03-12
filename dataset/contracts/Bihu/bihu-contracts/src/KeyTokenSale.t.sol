// Copyright (C) 2017 DappHub, LLC

pragma solidity ^0.4.11;

import "ds-test/test.sol";
import "ds-exec/exec.sol";
import "ds-token/token.sol";

import "./KeyTokenSale.sol";

contract KeyTokenSaleUser is DSExec {

    KeyTokenSale sale;
    DSToken key;

    function KeyTokenSaleUser(KeyTokenSale sale_) {
        sale = sale_;
        key = sale.key();
    }

    function() payable {}

    function doBuy(uint wad) {
        exec(sale, wad);
    }

    function doTransfer(address to, uint256 amount) returns (bool){
        return key.transfer(to, amount);
    }
}

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
}

contract TestableKeyTokenSale is KeyTokenSale {

    function TestableKeyTokenSale(uint startTime, address destFoundation)
    KeyTokenSale(startTime, destFoundation) {
        localTime = now;
    }

    uint public localTime;

    function time() constant returns (uint) {
        return localTime;
    }

    function addTime(uint extra) {
        localTime += extra;
    }

    function canBuy(uint total) returns (bool) {
        return msg.sender == owner ? true : total < USER_BUY_LIMIT;
    }
}

contract KeyTokenSaleTest is DSTest, DSExec {
    TestableKeyTokenSale sale;
    DSToken key;
    KeyTokenOwner keyFoundation;

    KeyTokenSaleUser user1;
    KeyTokenSaleUser user2;


    function setUp() {
        keyFoundation = new KeyTokenOwner();
        sale = new TestableKeyTokenSale(now, keyFoundation);
        key = sale.key();

        keyFoundation.setKey(key);

        user1 = new KeyTokenSaleUser(sale);
        exec(user1, 600 ether);

        user2 = new KeyTokenSaleUser(sale);
        exec(user2, 600 ether);

    }



    function testKeySaleToken() {
        assertEq(key.balanceOf(sale), (10 ** 11)* 16 / 100 * 1 ether - 40000 * 200000 ether);
    }

    function testFoundationToken() {
        assertEq(key.balanceOf(keyFoundation), (10 ** 11)* 84 / 100 * 1 ether + 40000 * 200000 ether);
    }


    function testPublicBuy() {
        sale.addTime(1 days);

        user1.doBuy(19 ether);
        assertEq(key.balanceOf(user1), 200000 * 19 ether);
        assertEq(keyFoundation.balance, 19 ether);

        exec(sale, 11 ether);
        assertEq(key.balanceOf(this), 200000 * 11 ether);
        assertEq(keyFoundation.balance, 30 ether);
    }

    function testClaimTokens() {
        DSToken test = new DSToken("TST");
        test.mint(1 ether);
        test.push(sale, 1 ether);
        assertEq(test.balanceOf(this), 0);
        sale.transferTokens(this, 1 ether, test);
    }


    function testBuyManyTimes() {
        exec(sale, 100 ether);
        assertEq(key.balanceOf(this), 200000 * 100 ether);

        exec(sale, 200 ether);
        assertEq(key.balanceOf(this), 200000 * 300 ether);

        exec(sale, 200 ether);
        assertEq(key.balanceOf(this), 200000 * 500 ether);
    }


    function testPostponeStartTime(){

        assertEq(sale.startTime(), now );
        assertEq(sale.endTime(), now + 14 days);

        sale.setStartTime(now + 2 days);

        assertEq(sale.startTime(), now + 2 days);
        assertEq(sale.endTime(), now + 16 days);
    }

    function testHitSoftCap() {
        exec(sale, 20000 ether);

        assertEq(sale.endTime(), now + 24 hours);
    }

    function testFinalize() {

        // sell 30000 ether, remains 10000 ether
        exec(sale, 30000 ether);

        sale.addTime(14 days);

        assertEq(key.balanceOf(sale), 10000 * 200000 * 1 ether);
        assertEq(key.balanceOf(keyFoundation), ( (10 ** 11) * 84 / 100 ) * 1 ether + 40000 * 200000 ether);

        sale.finalize();

        assertEq(key.balanceOf(sale), 0 );
        assertEq(key.balanceOf(keyFoundation), ( (10 ** 11) * 84 / 100 + 10000 * 200000) * 1 ether + 40000 * 200000 ether);

        assertEq(keyFoundation.balance, 30000 ether);

    }

    function testTokenOwnershipAfterFinalize() {

        sale.addTime(14 days);

        sale.finalize();
        keyFoundation.doStop();
    }

    function testTransferAfterFinalize() {
        user1.doBuy(1 ether);
        assertEq(key.balanceOf(user1), 200000 * 1 ether);

        sale.addTime(14 days);
        sale.finalize();

        assert(user1.doTransfer(user2, 200000 * 1 ether));

        assertEq(key.balanceOf(user1), 0);
        assertEq(key.balanceOf(user2), 200000 * 1 ether);

    }

    function testBuyExceedHardLimit() {

        exec(sale, 39900 ether);

        // one 100 ether left, 200 ether will return
        user1.doBuy(300 ether);

        assertEq(key.balanceOf(user1), 200000 * 100 ether);
        assertEq(user1.balance, 500 ether);

        assertEq(sale.endTime(), now);
    }

    function testFailTransferBeforeFinalize() {
        user1.doBuy(1 ether);
        assert(user1.doTransfer(user2, 200000 * 1 ether));
    }

    function testEndTimeAfterSoftLimit(){

        // normal sell is 14 days
        assertEq(sale.endTime(), now + 14 days);

        // hit soft limit
        exec(sale, 20000 ether);
        assertEq(key.balanceOf(this), 200000 * 20000 ether);

        // 24 hours left for sell
        assertEq(sale.endTime(), now + 24 hours);
    }

    function testFailSoftLimit() {

        exec(sale, 60000 ether);

        sale.addTime(24 hours);

        // sell is finished
        exec(sale, 1 ether);
    }

    function testFailHardLimit() {

        // hit hard limit
        exec(sale, 40000 ether);

        // sell is finished
        exec(sale, 1 ether);
    }

    // tries to buy more than 500 eth
    function testFailUserBuyTooMuch() {
        user1.doBuy(501 ether);
    }


    function testFailStartTooEarly() {
        sale = new TestableKeyTokenSale(now + 1 days, keyFoundation);
        exec(sale, 10 ether);
    }

    function testFailBuyAfterClose() {
        sale.addTime(14 days);
        exec(sale, 10 ether);
    }

}
