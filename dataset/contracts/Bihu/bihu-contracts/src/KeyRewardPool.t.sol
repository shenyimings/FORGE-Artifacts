pragma solidity 0.4.18;

import "ds-test/test.sol";
import "ds-math/math.sol";

import "./KeyRewardPool.sol";
import "./KeyTokenReborn.sol";


contract KeyRewardPoolOwner {

    TestableKeyRewardPool pool;

    function KeyRewardPoolOwner(TestableKeyRewardPool _pool) {
        pool = _pool;
    }

    function stopRewardPool() {
        pool.pauseCollectToken();
    }

    function startRewardPool() {
        pool.resumeCollectToken();
    }
}

contract KeyRewardPoolWithdrawer {
    TestableKeyRewardPool pool;

    function KeyRewardPoolWithdrawer() {

    }

    function setKeyRewardPool(TestableKeyRewardPool _pool) {
        pool = _pool;
    }

    function collectToken() {
        pool.collectToken();
    }

    function transferTokens(address dst, uint wad, address _token) {
        pool.transferTokens(dst, wad, _token );
    }
}

contract TestableKeyRewardPool is KeyRewardPool {

    function TestableKeyRewardPool(uint256 _rewardStartTime, address _key, address _withdrawer)
    KeyRewardPool(_rewardStartTime, _key, _withdrawer) {
        localTime = now;
    }

    uint public localTime;

    function time() constant returns (uint) {
        return localTime;
    }

    function addTime(uint extra) {
        localTime += extra;
    }
}

contract KeyRewardPoolTest is DSTest, DSMath{

    TestableKeyRewardPool rewardPool;
    KeyTokenReborn keyReborn;
    DSToken key;

    KeyRewardPoolOwner poolOwner;
    KeyRewardPoolWithdrawer poolWithdrawer;

    function setUp() {

        keyReborn = new KeyTokenReborn(this);
        key = keyReborn.key();

        poolWithdrawer = new KeyRewardPoolWithdrawer();
        rewardPool = new TestableKeyRewardPool(now, key, poolWithdrawer);
        poolWithdrawer.setKeyRewardPool(rewardPool);

        key.transfer(rewardPool, 100 ether);

        poolOwner = new KeyRewardPoolOwner(rewardPool);
        rewardPool.setOwner(poolOwner);

    }

    function testKeyOwner() {
        assertEq(address(key.owner()), address(this));
    }

    function testPoolTotalBalance() {
        assertEq(key.balanceOf(rewardPool), 100 ether);
        assertEq(key.balanceOf(poolOwner), 0 ether);
    }

    function testPoolOwner() {
        assertEq(address(rewardPool.owner()), poolOwner);
    }

    function testPoolWithdrawer() {
        assertEq(address(rewardPool.withdrawer()), poolWithdrawer);
    }

    function testCollectTokenOneDay() {
        rewardPool.addTime(1 days);
        poolWithdrawer.collectToken();
        assertEq(key.balanceOf(poolWithdrawer), div(10 ether, 365));
    }

    function testFailCollectTokenOneDay() {
        poolOwner.stopRewardPool();

        rewardPool.addTime(1 days);
        poolWithdrawer.collectToken();
        assertEq(key.balanceOf(poolWithdrawer), div(10 ether, 365));
    }

    function testCollectToken300Day() {
        rewardPool.addTime(300 days);
        poolWithdrawer.collectToken();
        assertEq(key.balanceOf(poolWithdrawer), div(300 * 10 ether , 365));
    }

    function testCollectToken400Day() {

        rewardPool.addTime(1 years);
        poolWithdrawer.collectToken();

        rewardPool.addTime(35 days);
        poolWithdrawer.collectToken();

        uint256 reward = 10 ether;
        reward = reward + div( 35 * 90 * 10 ether, 365 * 100) ;

        assertEq(key.balanceOf(poolWithdrawer), reward);
    }

    function testCollectTokenOneYear() {

        rewardPool.addTime(365 days);
        poolWithdrawer.collectToken();
        assertEq(key.balanceOf(poolWithdrawer), 10 ether);
    }

    function testCollectToken2Year() {

        rewardPool.addTime(1 years);
        poolWithdrawer.collectToken();

        rewardPool.addTime(1 years);
        poolWithdrawer.collectToken();

        assertEq(key.balanceOf(poolWithdrawer), 10 ether + (10 * 90 ether)/100);
    }

    function testFailTransferTokens() {

        poolWithdrawer.transferTokens(this, 1 ether, key);


    }



}
