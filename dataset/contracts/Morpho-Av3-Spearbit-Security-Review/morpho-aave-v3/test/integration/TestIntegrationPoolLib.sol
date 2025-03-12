// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IPool, IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPool.sol";

import {PoolLib} from "src/libraries/PoolLib.sol";
import {DataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";

import "test/helpers/ForkTest.sol";

contract TestIntegrationPoolLib is ForkTest {
    using PoolLib for IPool;

    address internal aDai;
    address internal vDai;

    uint256 internal constant MIN_AMOUNT = 10;
    uint256 internal constant MAX_AMOUNT = 100 ether;

    constructor() {
        ERC20(dai).approve(address(pool), type(uint256).max);

        DataTypes.ReserveData memory reserveData = pool.getReserveData(dai);
        aDai = reserveData.aTokenAddress;
        vDai = reserveData.variableDebtTokenAddress;
    }
}

contract TestIntegrationPoolLibSupply is TestIntegrationPoolLib {
    using PoolLib for IPool;

    function testSupplyToPool(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        uint256 balanceBefore = ERC20(dai).balanceOf(address(this));
        uint256 aBalanceBefore = ERC20(aDai).balanceOf(address(this));

        pool.supplyToPool(dai, amount);

        assertEq(ERC20(dai).balanceOf(address(this)) + amount, balanceBefore, "balance");
        assertApproxEqAbs(ERC20(aDai).balanceOf(address(this)), aBalanceBefore + amount, 1, "aBalance");
    }
}

contract TestIntegrationPoolLibBorrow is TestIntegrationPoolLib {
    using PoolLib for IPool;

    function setUp() public virtual override {
        super.setUp();
        pool.supplyToPool(dai, MAX_AMOUNT);
    }

    function testBorrowFromPool(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        uint256 balanceBefore = ERC20(dai).balanceOf(address(this));
        uint256 vBalanceBefore = ERC20(vDai).balanceOf(address(this));

        pool.borrowFromPool(dai, amount / 2);

        assertEq(ERC20(dai).balanceOf(address(this)), balanceBefore + amount / 2, "balance");
        assertApproxEqAbs(ERC20(vDai).balanceOf(address(this)), vBalanceBefore + amount / 2, 1, "vBalance");
    }
}

contract TestIntegrationPoolLibRepay is TestIntegrationPoolLib {
    using PoolLib for IPool;

    function setUp() public virtual override {
        super.setUp();
        pool.supplyToPool(dai, MAX_AMOUNT);
        pool.borrowFromPool(dai, MAX_AMOUNT / 2);

        _forward(1);
    }

    function testRepayToPool(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        uint256 balanceBefore = ERC20(dai).balanceOf(address(this));
        uint256 vBalanceBefore = ERC20(vDai).balanceOf(address(this));

        pool.repayToPool(dai, vDai, amount / 4);

        assertEq(ERC20(dai).balanceOf(address(this)) + amount / 4, balanceBefore, "balance");
        assertApproxEqAbs(ERC20(vDai).balanceOf(address(this)) + amount / 4, vBalanceBefore, 1, "vBalance");
    }
}

contract TestIntegrationPoolLibWithdraw is TestIntegrationPoolLib {
    using PoolLib for IPool;

    function setUp() public virtual override {
        super.setUp();
        pool.supplyToPool(dai, MAX_AMOUNT);
    }

    function testWithdrawFromPool(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 balanceBefore = ERC20(dai).balanceOf(address(this));
        uint256 aBalanceBefore = ERC20(aDai).balanceOf(address(this));

        pool.withdrawFromPool(dai, aDai, amount / 2);

        assertEq(ERC20(dai).balanceOf(address(this)), balanceBefore + amount / 2, "balance");
        assertApproxEqAbs(ERC20(aDai).balanceOf(address(this)) + amount / 2, aBalanceBefore, 1, "aBalance");
    }
}
