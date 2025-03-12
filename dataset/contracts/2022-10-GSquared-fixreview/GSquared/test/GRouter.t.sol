// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Base.GSquared.t.sol";

contract RouterTest is Test, BaseSetup {
    using stdStorage for StdStorage;
    address frax_lp = address(0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B);
    address frax = address(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    address fraxConvexPool =
        address(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    address fraxConvexRewards =
        address(0xB900EF131301B307dB5eFcbed9DBb50A3e209B2e);
    uint256 frax_lp_pid = 32;

    ConvexStrategy convexStrategy;

    function setUp() public virtual override {
        BaseSetup.setUp();
        vm.startPrank(BASED_ADDRESS);
        setupConvexStrategy();
        setStorage(BASED_ADDRESS, DAI.balanceOf.selector, address(DAI), 200E18);
        DAI.approve(address(gRouter), MAX_UINT);
        gRouter.deposit(100E18, 0, false, 0);
        gRouter.deposit(100E18, 0, true, 0);
        vm.stopPrank();
    }

    function setupConvexStrategy() public {
        convexStrategy = new ConvexStrategy(
            IGVault(address(gVault)),
            BASED_ADDRESS,
            frax_lp_pid,
            frax_lp
        );
        StopLossLogic snl = new StopLossLogic();

        convexStrategy.setStopLossLogic(address(snl));
        convexStrategy.setHarvestThresholds(1, 1);
        snl.setStrategy(address(convexStrategy), 1e18, 400);
        convexStrategy.setKeeper(BASED_ADDRESS);
        gVault.removeStrategy(address(strategy));
        gVault.addStrategy(address(convexStrategy), 9000);
    }

    function testDepositSimple() public {
        vm.startPrank(alice);
        setStorage(alice, DAI.balanceOf.selector, address(DAI), 100E20);

        DAI.approve(address(gRouter), MAX_UINT);
        // Get initial USD balances and total supply
        uint256 initialSenior = gTranche.trancheBalances(1);
        uint256 initialJunior = gTranche.trancheBalances(0);

        uint256 initialJuniorSupply = gTranche.totalSupply(0);
        uint256 initialSeniorSupply = gTranche.totalSupply(1);

        uint256 juniorDeposit = 100E18;
        uint256 seniorDeposit = 50E18;

        gRouter.deposit(juniorDeposit, 0, false, 0);
        gRouter.deposit(seniorDeposit, 0, true, 0);
        uint256 finalSenior = gTranche.trancheBalances(1);
        uint256 finalJunior = gTranche.trancheBalances(0);
        assertApproxEqRel(initialJunior + juniorDeposit, finalJunior, 1E15);
        assertApproxEqRel(initialSenior + seniorDeposit, finalSenior, 1E15);

        // Make sure total supply reflects reality after first deposit
        uint256 juniorFactor = gTranche.factor(0);
        // Apply factor to deposited junior amount
        uint256 juniorConvertedFromAssets = (juniorFactor * juniorDeposit) /
            1e18;
        assertApproxEqRel(
            initialJuniorSupply + juniorConvertedFromAssets,
            gTranche.totalSupply(0),
            1e17
        );
        // Not applying factor to Senior as it will be most likely be 1 : 1 relationship
        assertApproxEqRel(
            initialSeniorSupply + seniorDeposit,
            gTranche.totalSupply(1),
            1e15
        );
        vm.stopPrank();
    }

    // Same deposit case but user deposits 3pool LP token
    function testDeposit3PoolToken() public {
        uint256 threePoolPrice = curveOracle.getVirtualPrice();
        vm.startPrank(alice);
        setStorage(
            alice,
            THREE_POOL_TOKEN.balanceOf.selector,
            address(THREE_POOL_TOKEN),
            100E20
        );

        THREE_POOL_TOKEN.approve(address(gRouter), MAX_UINT);
        // Get initial USD balances and total supply
        uint256 initialSenior = gTranche.trancheBalances(1);
        uint256 initialJunior = gTranche.trancheBalances(0);

        uint256 initialJuniorSupply = gTranche.totalSupply(0);
        uint256 initialSeniorSupply = gTranche.totalSupply(1);

        uint256 juniorDeposit = 100E18;
        uint256 seniorDeposit = 50E18;
        uint256 juniorDepositDenomUSD = (juniorDeposit * threePoolPrice) / 1e18;
        uint256 seniorDepositDenomUSD = (seniorDeposit * threePoolPrice) / 1e18;

        gRouter.deposit(juniorDeposit, 3, false, 0);
        gRouter.deposit(seniorDeposit, 3, true, 0);
        uint256 finalSenior = gTranche.trancheBalances(1);
        uint256 finalJunior = gTranche.trancheBalances(0);
        assertApproxEqRel(
            initialJunior + juniorDepositDenomUSD,
            finalJunior,
            1E15
        );
        assertApproxEqRel(
            initialSenior + seniorDepositDenomUSD,
            finalSenior,
            1E15
        );

        // Make sure total supply reflects reality after first deposit
        uint256 juniorFactor = gTranche.factor(0);
        // Apply factor to deposited junior amount
        uint256 juniorConvertedFromAssets = (juniorFactor *
            juniorDepositDenomUSD) / 1e18;
        assertApproxEqRel(
            initialJuniorSupply + juniorConvertedFromAssets,
            gTranche.totalSupply(0),
            1e17
        );
        // Not applying factor to Senior as it will be most likely be 1 : 1 relationship
        assertApproxEqRel(
            initialSeniorSupply + seniorDepositDenomUSD,
            gTranche.totalSupply(1),
            1e15
        );
        vm.stopPrank();
    }

    function testWithdrawalSimple() public {
        vm.startPrank(alice);
        setStorage(alice, DAI.balanceOf.selector, address(DAI), 15000E20);

        DAI.approve(address(gRouter), MAX_UINT);

        gRouter.deposit(10000E18, 0, false, 0);
        gRouter.deposit(5000E18, 0, true, 0);
        vm.stopPrank();

        vm.startPrank(BASED_ADDRESS);
        //convexStrategy.runHarvest();
        vm.stopPrank();

        vm.startPrank(alice);
        gTranche.setApprovalForAll(address(gRouter), true);

        uint256 initialSenior = gTranche.trancheBalances(1);
        uint256 initialJunior = gTranche.trancheBalances(0);

        uint256 initialJuniorSupply = gTranche.totalSupply(0);
        uint256 initialSeniorSupply = gTranche.totalSupply(1);

        uint256 withdrawJunior = (100E18 * 1E18) / gTranche.getPricePerShare(0);
        uint256 withdrawSenior = 4000E18;

        gRouter.withdraw(4000E18, 0, true, 0);
        gRouter.withdraw(withdrawJunior, 0, false, 0);

        uint256 finalSenior = gTranche.trancheBalances(1);
        uint256 finalJunior = gTranche.trancheBalances(0);

        // Make sure total supply reflects reality after withdrawal
        // No need to apply factor here for neither token
        assertApproxEqRel(
            initialJuniorSupply - withdrawJunior,
            gTranche.totalSupply(0),
            1E15
        );
        assertApproxEqRel(
            initialSeniorSupply - withdrawSenior,
            gTranche.totalSupply(1),
            1E15
        );
        vm.stopPrank();
    }

    function testWithdrawal3PoolToken() public {
        vm.startPrank(alice);
        setStorage(
            alice,
            THREE_POOL_TOKEN.balanceOf.selector,
            address(THREE_POOL_TOKEN),
            15000E20
        );

        THREE_POOL_TOKEN.approve(address(gRouter), MAX_UINT);

        gRouter.deposit(10000E18, 3, false, 0);
        gRouter.deposit(5000E18, 3, true, 0);
        vm.stopPrank();

        vm.startPrank(alice);
        gTranche.setApprovalForAll(address(gRouter), true);

        uint256 initialSenior = gTranche.trancheBalances(1);
        uint256 initialJunior = gTranche.trancheBalances(0);

        uint256 initialJuniorSupply = gTranche.totalSupply(0);
        uint256 initialSeniorSupply = gTranche.totalSupply(1);

        uint256 withdrawJunior = (100E18 * 1E18) / gTranche.getPricePerShare(0);
        uint256 withdrawSenior = 4000E18;

        gRouter.withdraw(withdrawSenior, 0, true, 0);
        gRouter.withdraw(withdrawJunior, 0, false, 0);

        uint256 finalSenior = gTranche.trancheBalances(1);
        uint256 finalJunior = gTranche.trancheBalances(0);

        // Make sure total supply reflects reality after withdrawal
        // No need to apply factor here for neither token
        assertApproxEqRel(
            initialJuniorSupply - withdrawJunior,
            gTranche.totalSupply(0),
            1E10
        );
        assertApproxEqRel(
            initialSeniorSupply - withdrawSenior,
            gTranche.totalSupply(1),
            1E15
        );
        vm.stopPrank();
    }

    /// Given a user with assets in the Senior tranche
    /// When there is a loss
    /// Then the user should not experience any loss on
    /// Their senior tranche assets, unless the junior tranche
    ///  is depleated
    ///  invariant:
    ///  ∀ S, J ∃ T, if S₁ >= S₀, then J₁ = 0
    ///  for all gain/losses in senior and junior tranche in the set of tranche asset changes,
    ///  the senior tranche can only be be reduced if and only if the junior tranche is 0
    function testSeniorTrancheLosses(
        uint256 _deposit,
        uint16 _change,
        uint256 _i,
        bool _loss
    ) public {
        uint256 deposit = bound(_deposit, 1E22, 1E26);
        uint256 change = bound(_change, 100, 10000);
        uint256 i = bound(_i, 2, 4);

        for (uint256 j; j < i; j++) {
            address user = users[j];
            prepUser(user);
            vm.startPrank(user);
            gRouter.deposit(deposit, 0, false, 0);
            gRouter.deposit(deposit, 0, true, 0);
            vm.stopPrank();
        }

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();

        uint256 utilisation = gTranche.utilisation();
        uint256 BP = change % 10000;
        uint256 assets = gVault.totalAssets();
        uint256 initialSeniorTrancheAssets = gTranche.trancheBalances(1);

        if (_loss) {
            uint256 loss = assets - (assets * change) / 10000;
            //setStorage(address(convexStrategy), ERC20(fraxConvexRewards).balanceOf.selector, fraxConvexRewards, loss);
        } else {
            uint256 gain = assets + (assets * change) / 10000;
            //setStorage(address(convexStrategy), ERC20(fraxConvexRewards).balanceOf.selector, fraxConvexRewards, gain);
        }

        convexStrategy.runHarvest();
        vm.stopPrank();

        vm.startPrank(alice);

        uint256 aliceSeniorAssets = gTranche.balanceOfWithFactor(alice, 1);
        uint256 aliceJuniorAssets = gTranche.balanceOfWithFactor(alice, 0);
        gRouter.withdraw(aliceSeniorAssets / 10, 0, true, 0);
        initialSeniorTrancheAssets =
            initialSeniorTrancheAssets -
            aliceSeniorAssets /
            10;
        vm.stopPrank();

        // if (_loss) {
        //     if (change <= 5000) {
        //         assertGe(gTranche.trancheBalances(true), initialSeniorTrancheAssets);
        //     } else {
        //         assertLe(gTranche.trancheBalances(true), initialSeniorTrancheAssets);
        //     }
        // } else {
        //     assertGe(gTranche.trancheBalances(true), initialSeniorTrancheAssets);
        // }
    }

    /// Given a user with assets in the Junior tranche
    /// When there is a gain
    /// Then all the gains should go to the Junior tranche
    ///  invariant:
    ///  ∀ S, J ∃ T, if S₁ >= S₀, then J₁ = 0
    ///  for all gain/losses in senior and junior tranche in the set of tranche asset changes,
    ///  the senior tranche can only be be reduced if and only if the junior tranche is 0
    function testJuniorGetsAllYield(
        uint256 deposit,
        uint16 _change,
        uint256 i
    ) public {
        uint256 change = uint256(_change) % 10000;
        vm.assume(deposit > 1E20);
        vm.assume(deposit < 1E25);
        vm.assume(change > 100);
        vm.assume(change <= 10000);
        vm.assume(i > 1);

        vm.startPrank(BASED_ADDRESS);
        pnl.setRate(0);
        vm.stopPrank();

        for (uint256 j; j < (i % 4) + 1; j++) {
            address user = users[j];
            prepUser(user);
            vm.startPrank(user);
            gRouter.deposit(deposit, 0, false, 0);
            gRouter.deposit(deposit, 0, true, 0);
            vm.stopPrank();
        }

        vm.startPrank(BASED_ADDRESS);
        convexStrategy.runHarvest();
        vm.stopPrank();

        uint256 utilisation = gTranche.utilisation();
        uint256 BP = change % 10000;
        uint256 assets = gVault.totalAssets();
        uint256 initialSeniorTrancheAssets = gTranche.trancheBalances(1);
        uint256 initialJuniorTrancheAssets = gTranche.trancheBalances(0);

        vm.startPrank(BASED_ADDRESS);
        uint256 gain = assets + (assets * change) / BP;
        setStorage(
            address(convexStrategy),
            THREE_POOL_TOKEN.balanceOf.selector,
            address(THREE_POOL_TOKEN),
            gain
        );

        convexStrategy.runHarvest();
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 aliceSeniorAssets = gTranche.balanceOfWithFactor(alice, 1);
        uint256 aliceJuniorAssets = gTranche.balanceOfWithFactor(alice, 0);
        gRouter.withdraw(aliceSeniorAssets / 10, 0, true, 0);
        initialSeniorTrancheAssets =
            initialSeniorTrancheAssets -
            aliceSeniorAssets /
            10;
        initialJuniorTrancheAssets =
            initialJuniorTrancheAssets -
            aliceJuniorAssets /
            10;
        vm.stopPrank();

        assertEq(gTranche.trancheBalances(1), initialSeniorTrancheAssets);
        assertGt(gTranche.trancheBalances(0), initialJuniorTrancheAssets);
    }

    function testwithdrawNoImpact(
        uint256 deposit,
        uint8 _i,
        uint8 _k
    ) public {
        uint256 i = uint256((_i % 4) + 1);
        uint256 k = uint256((_k % 25) + 1);
        vm.assume(deposit > 1E20);
        vm.assume(deposit < 1E25);
        vm.assume(i > 1);
        vm.assume(k > 1);

        vm.startPrank(BASED_ADDRESS);
        pnl.setRate(0);
        vm.stopPrank();

        runDeposit(users, deposit, i, k);

        uint256 seniorTotal = gTranche.trancheBalances(1);
        uint256 juniorTotal = gTranche.trancheBalances(0);
        uint256 totalWithdrawnSenior;
        uint256 totalWithdrawnJunior;

        for (uint256 j; j < i; j++) {
            (uint256 withdrawnSenior, uint256 withdrawnJunior) = runWithdrawal(
                users[j],
                k
            );
            totalWithdrawnSenior += withdrawnSenior;
            totalWithdrawnJunior += withdrawnJunior;
        }

        assertApproxEqAbs(
            gTranche.trancheBalances(1),
            delta(seniorTotal, totalWithdrawnSenior),
            1E6
        );
        assertApproxEqAbs(
            gTranche.trancheBalances(0),
            delta(juniorTotal, totalWithdrawnJunior),
            1E6
        );
    }

    /// @dev Test depositing with approvals
    function testDepositWithPermitHappyDAI(uint256 juniorAmnt) public {
        vm.assume(juniorAmnt > 100e18);
        vm.assume(juniorAmnt < 10000000e18);
        uint256 seniorAmnt = juniorAmnt / 10;
        // Make new address and extract private key
        (address addr, uint256 key) = makeAddrAndKey("1337");
        // Give some DAI to the new address
        setStorage(addr, DAI.balanceOf.selector, address(DAI), 1000000000e18);
        uint256 initialSenior = gTranche.trancheBalances(1);
        uint256 initialJunior = gTranche.trancheBalances(0);

        vm.startPrank(addr);
        (uint8 v, bytes32 r, bytes32 s) = signPermitDAI(
            addr,
            address(gRouter),
            0,
            block.timestamp + 1000, // deadline
            key
        );
        // Deposit to Junior first
        gRouter.depositWithAllowedPermit(
            juniorAmnt,
            0,
            false,
            0,
            block.timestamp + 1000, // deadline
            0,
            v,
            r,
            s
        );
        // Bump nonce and deposit to Senior with new signature
        (uint8 v1, bytes32 r1, bytes32 s1) = signPermitDAI(
            addr,
            address(gRouter),
            1,
            block.timestamp + 1000, // deadline
            key
        );
        gRouter.depositWithAllowedPermit(
            seniorAmnt,
            0,
            true,
            0,
            block.timestamp + 1000, // deadline
            1,
            v1,
            r1,
            s1
        );
        vm.stopPrank();
        assertApproxEqRel(
            gTranche.trancheBalances(0),
            initialJunior + juniorAmnt,
            1e15
        );
        assertApproxEqRel(
            gTranche.trancheBalances(1),
            initialSenior + seniorAmnt,
            1e15
        );
    }

    function testDepositWithPermitCannotDepositSameSigDAI() public {
        (address addr, uint256 key) = makeAddrAndKey("1337");
        setStorage(addr, DAI.balanceOf.selector, address(DAI), 1000000000e18);
        uint256 initialSenior = gTranche.trancheBalances(1);
        uint256 initialJunior = gTranche.trancheBalances(0);

        uint256 depositAmountJr = 100e18;
        uint256 depositAmountSenior = 10e18;
        vm.startPrank(addr);
        (uint8 v, bytes32 r, bytes32 s) = signPermitDAI(
            addr,
            address(gRouter),
            0,
            block.timestamp + 1000,
            key
        );
        // Deposit to Junior first
        gRouter.depositWithAllowedPermit(
            depositAmountJr,
            0,
            false,
            0,
            block.timestamp + 1000,
            0,
            v,
            r,
            s
        );
        // Try to deposit with same signature and expect revert
        vm.expectRevert("Dai/invalid-permit");
        gRouter.depositWithAllowedPermit(
            depositAmountSenior,
            0,
            true,
            0,
            block.timestamp + 1000,
            1,
            v,
            r,
            s
        );
        vm.stopPrank();
    }

    function testDepositWithPermitZeroAmount() public {
        (address addr, uint256 key) = makeAddrAndKey("1337");
        setStorage(addr, DAI.balanceOf.selector, address(DAI), 1000000000e18);
        vm.startPrank(addr);
        (uint8 v, bytes32 r, bytes32 s) = signPermitDAI(
            addr,
            address(gRouter),
            0,
            block.timestamp + 1000,
            key
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.AmountIsZero.selector));
        gRouter.depositWithAllowedPermit(
            0,
            0,
            false,
            0,
            block.timestamp + 1000,
            0,
            v,
            r,
            s
        );
        vm.stopPrank;
    }

    function testDepositWithPermitHappyUSDC(uint256 juniorAmnt) public {
        vm.assume(juniorAmnt > 100e6);
        vm.assume(juniorAmnt < 10000000e6);

        uint256 seniorAmnt = juniorAmnt / 10;
        // Make new address and extract private key
        (address addr, uint256 key) = makeAddrAndKey("1337");
        // Give some USDC to the new address
        setStorage(addr, USDC.balanceOf.selector, address(USDC), 1000000000e18);
        uint256 initialSenior = gTranche.trancheBalances(1);
        uint256 initialJunior = gTranche.trancheBalances(0);

        vm.startPrank(addr);
        (uint8 v, bytes32 r, bytes32 s) = signPermitUSDC(
            addr,
            address(gRouter),
            juniorAmnt,
            0,
            block.timestamp + 1,
            key
        );
        // Deposit to Junior first
        gRouter.depositWithPermit(
            juniorAmnt,
            1,
            false,
            0,
            block.timestamp + 1,
            v,
            r,
            s
        );
        // Bump nonce and deposit to Senior with new signature
        (v, r, s) = signPermitUSDC(
            addr,
            address(gRouter),
            seniorAmnt,
            1,
            block.timestamp + 1,
            key
        );
        gRouter.depositWithPermit(
            seniorAmnt,
            1,
            true,
            0,
            block.timestamp + 1,
            v,
            r,
            s
        );
        assertApproxEqRel(
            gTranche.trancheBalances(0),
            initialJunior + (juniorAmnt * 1e12), // Convert to 18 decimals
            1e15
        );
        assertApproxEqRel(
            gTranche.trancheBalances(1),
            initialSenior + (seniorAmnt * 1e12), // Convert to 18 decimals
            1e15
        );
        vm.stopPrank();
    }

    function testDepositWithPermitCannotDepositSameSigUSDC() public {
        (address addr, uint256 key) = makeAddrAndKey("1337");
        setStorage(addr, USDC.balanceOf.selector, address(USDC), 1000000000e18);
        uint256 initialSenior = gTranche.trancheBalances(1);
        uint256 initialJunior = gTranche.trancheBalances(0);
        uint256 depositAmountJr = 100e6;
        uint256 depositAmountSenior = 10e6;
        vm.startPrank(addr);
        (uint8 v, bytes32 r, bytes32 s) = signPermitUSDC(
            addr,
            address(gRouter),
            depositAmountJr,
            0,
            block.timestamp + 1,
            key
        );
        // Deposit to Junior first
        gRouter.depositWithPermit(
            depositAmountJr,
            1,
            false,
            0,
            block.timestamp + 1,
            v,
            r,
            s
        );
        vm.expectRevert("EIP2612: invalid signature");
        // Try to deposit with same sig and expect revert
        gRouter.depositWithPermit(
            depositAmountJr,
            1,
            false,
            0,
            block.timestamp + 1,
            v,
            r,
            s
        );
        vm.stopPrank();
    }

    function testDepositWithPermitZeroAmountUSDC() public {
        (address addr, uint256 key) = makeAddrAndKey("1337");
        setStorage(addr, USDC.balanceOf.selector, address(USDC), 1000000000e18);
        vm.startPrank(addr);
        (uint8 v, bytes32 r, bytes32 s) = signPermitUSDC(
            addr,
            address(gRouter),
            0,
            0,
            block.timestamp + 1,
            key
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.AmountIsZero.selector));
        gRouter.depositWithPermit(0, 1, false, 0, block.timestamp + 1, v, r, s);
    }

    function testDepositWithdrawMulti() public {
        vm.startPrank(alice);

        setStorage(alice, DAI.balanceOf.selector, address(DAI), 100E20);
        gTranche.setApprovalForAll(address(gRouter), true);
        uint256 aliceDaiBalance = DAI.balanceOf(alice);

        DAI.approve(address(gRouter), MAX_UINT);

        gRouter.deposit(100E18, 0, false, 0);

        assertLt(DAI.balanceOf(alice), aliceDaiBalance);
        assertGt(gTranche.balanceOfWithFactor(alice, 0), 0);

        aliceDaiBalance = DAI.balanceOf(alice);
        gRouter.deposit(50E18, 0, true, 0);

        assertLt(DAI.balanceOf(alice), aliceDaiBalance);
        assertGt(gTranche.balanceOfWithFactor(alice, 1), 0);

        aliceDaiBalance = DAI.balanceOf(alice);
        uint256 alicePWRDBalance = gTranche.balanceOfWithFactor(alice, 1);
        gRouter.withdraw(10E18, 0, true, 0);

        assertGt(DAI.balanceOf(alice), aliceDaiBalance);
        assertLt(gTranche.balanceOfWithFactor(alice, 1), alicePWRDBalance);

        aliceDaiBalance = DAI.balanceOf(alice);
        uint256 aliceGVTBalance = gTranche.balanceOfWithFactor(alice, 0);
        gRouter.withdraw(10E16, 0, false, 0);

        assertGt(DAI.balanceOf(alice), aliceDaiBalance);
        assertLt(gTranche.balanceOfWithFactor(alice, 0), aliceGVTBalance);

        vm.stopPrank();
    }

    function testDepositWithdrawLegacy() public {
        vm.startPrank(alice);
        gTranche.setApprovalForAll(address(gRouter), true);
        setStorage(alice, DAI.balanceOf.selector, address(DAI), 100E20);

        uint256 aliceDaiBalance = DAI.balanceOf(alice);

        DAI.approve(address(gRouter), MAX_UINT);

        gRouter.depositGvt([uint256(100E18), 0, 0], 0, ZERO);

        assertLt(DAI.balanceOf(alice), aliceDaiBalance);
        assertGt(gTranche.balanceOfWithFactor(alice, 0), 0);

        aliceDaiBalance = DAI.balanceOf(alice);
        gRouter.depositPwrd([uint256(50E18), 0, 0], 0, ZERO);

        assertLt(DAI.balanceOf(alice), aliceDaiBalance);
        assertGt(gTranche.balanceOfWithFactor(alice, 1), 0);

        aliceDaiBalance = DAI.balanceOf(alice);
        uint256 alicePWRDBalance = gTranche.balanceOfWithFactor(alice, 1);
        gRouter.withdrawByStablecoin(true, 0, alicePWRDBalance, 0);

        assertGt(DAI.balanceOf(alice), aliceDaiBalance);
        assertLt(gTranche.balanceOfWithFactor(alice, 1), alicePWRDBalance);

        aliceDaiBalance = DAI.balanceOf(alice);
        uint256 aliceGVTBalance = gTranche.balanceOfWithFactor(alice, 0);
        gRouter.withdrawByStablecoin(false, 0, aliceGVTBalance, 0);

        assertGt(DAI.balanceOf(alice), aliceDaiBalance);
        assertLt(gTranche.balanceOfWithFactor(alice, 0), aliceGVTBalance);

        vm.stopPrank();
    }

    /// @dev Test depositing with zero amount should revert
    function testDepositZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AmountIsZero.selector));
        gRouter.deposit(0, 0, true, 123e18);
    }

    /// @dev Test withdrawing with zero amount should revert
    function testWithdrawZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AmountIsZero.selector));
        gRouter.withdraw(0, 0, true, 123e18);
    }
}
