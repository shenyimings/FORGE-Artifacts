// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../dev/Deployment.sol";


contract USDSTest is Deployment
	{
	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			initializeContracts();

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();


		priceAggregator.performUpkeep();

		finalizeBootstrap();
		}


	// // A unit test in which the collateral address is set for the first time. This test should validate that the collateral address is correctly updated and can only be set once.
	function testSetContractsOnlyOnce() public
		{
		address _collateral = address(0x5555);
		address _pools = address(0x6666);
		address _exchangeConfig = address(0x7777);

		// New USDS in case Collateral was set in the deployed version already
		usds = new USDS(wbtc, weth);

		// Initial set up
		assertEq(address(usds.collateral()), address(0));
		assertEq(address(usds.pools()), address(0));
		assertEq(address(usds.exchangeConfig()), address(0));

		usds.setContracts( ICollateral(_collateral), IPools(_pools), IExchangeConfig(_exchangeConfig) );

		assertEq(address(usds.collateral()), address(_collateral));
		assertEq(address(usds.pools()), address(_pools));
		assertEq(address(usds.exchangeConfig()), address(_exchangeConfig));

		address invalid = address(0xdead);

		vm.expectRevert("Ownable: caller is not the owner");
		usds.setContracts( ICollateral(invalid), IPools(invalid), IExchangeConfig(invalid) );

		// Validate that the addresses did not change
		assertEq(address(usds.collateral()), address(_collateral));
		assertEq(address(usds.pools()), address(_pools));
		assertEq(address(usds.exchangeConfig()), address(_exchangeConfig));
	}


	// A unit test where a different address attempts to call the mintTo function. This test should validate that only the collateral address is allowed to mint tokens.
	function testOnlyCollateralCanMint() public {
        address otherAddress = address(0x6666);
        address wallet = address(0x7777);
        uint256 mintAmount = 1 ether;

        // Try minting from the collateral address
        vm.prank(address(collateral));
        usds.mintTo(wallet, mintAmount);
        assertEq(usds.balanceOf(wallet), mintAmount);

        // Try minting from a different address
        vm.expectRevert("USDS.mintTo is only callable from the Collateral contract");
        vm.prank(otherAddress);
        usds.mintTo(wallet, mintAmount);

        // Validate that the balance did not increase
        assertEq(usds.balanceOf(wallet), mintAmount);
    }


	// A unit test where an attempt is made to burn more USD than is available in the contract.
	function testBurnMoreThanAvailable() public {
        uint256 usdsToBurn = 2 ether; // Amount greater than current balance

        assertEq(usds.usdsThatShouldBeBurned(), 0 ether);

        // Try burning more than available
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(usdsToBurn);

        // Validate that the amount that should be burnt is set correctly
        assertEq(usds.usdsThatShouldBeBurned(), usdsToBurn);
}


   // A unit test where a different address attempts to call the shouldBurnMoreUSDS function. This test should validate that only the collateral address is allowed to signal the contract to burn tokens.
   function testOnlyCollateralCanSignalBurn2() public {
		   address otherAddress = address(0x6666);
		   uint256 amountToBurn = 1 ether;

		   vm.prank(address(collateral));
		   usds.shouldBurnMoreUSDS(amountToBurn);
		   assertEq(usds.usdsThatShouldBeBurned(), amountToBurn);

		   // Try signalling burn from a non-collateral address
		   vm.expectRevert("USDS.shouldBurnMoreUSDS is only callable from the Collateral contract");
		   vm.prank(otherAddress);
		   usds.shouldBurnMoreUSDS(amountToBurn);
   }


	// A unit test where a different address attempts to call the mintTo function. This test should validate that only the collateral address is allowed to mint tokens.
	function testOnlyCollateralCanMint2() public {
        address otherAddress = address(0x6666);
        address wallet = address(0x7777);
        uint256 mintAmount = 1 ether;

        // Set up a new instance of USDS and set collateral
        // Mint from the collateral address
        vm.prank(address(collateral));
        usds.mintTo(wallet, mintAmount);
        assertEq(usds.balanceOf(wallet), mintAmount);

        // Attempt to mint from a different address
        vm.expectRevert("USDS.mintTo is only callable from the Collateral contract");
        vm.prank(otherAddress);
        usds.mintTo(wallet, mintAmount);

        // Validate that the balance did not increase
        assertEq(usds.balanceOf(wallet), mintAmount);
    }


	// A unit test where a different address attempts to call the shouldBurnMoreUSDS function. This test should validate that only the collateral address is allowed to signal the contract to burn tokens.
	function testOnlyCollateralCanSignalBurn() public {
        address otherAddress = address(0x6666);
        uint256 burnAmount = 1 ether;

        // Set up a new instance of USDS and set collateral
        // Signal burn from the collateral address
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(burnAmount);
        assertEq(usds.usdsThatShouldBeBurned(), burnAmount);

        // Attempt to signal burn from a different address
        vm.expectRevert("USDS.shouldBurnMoreUSDS is only callable from the Collateral contract");
        vm.prank(otherAddress);
        usds.shouldBurnMoreUSDS(burnAmount);
    }


	// A unit test where a call is made to mintTo function without calling the setCollateral function first. This test will validate that before the mint operation can be made, the Collateral contract has to be set.
    function testMintWithoutSettingCollateral() public {
        address wallet = address(0x7777);
        uint256 mintAmount = 1 ether;

        // Try minting without setting the collateral address first
        vm.expectRevert("USDS.mintTo is only callable from the Collateral contract");
        usds.mintTo(wallet, mintAmount);

        // Validate that the balance did not increase
        assertEq(usds.balanceOf(wallet), 0);
    }


	// A unit test where a call is made to shouldBurnMoreUSDS function without calling the setCollateral function first. This test will validate that before the burn operation can be made, the Collateral contract has to be set.
    function testShouldBurnMoreUSDSWithoutCollateralSet() public {
        uint256 usdsToBurn = 1 ether;

        // New USDS instance in case Collateral was set in the deployed version already
    	USDS newUSDS = new USDS(wbtc, weth);

        // Expect revert as the Collateral contract is not set yet
        vm.expectRevert("USDS.shouldBurnMoreUSDS is only callable from the Collateral contract");
        newUSDS.shouldBurnMoreUSDS(usdsToBurn);
    }

	// A unit test to check if an incorrect or zero address is provided to the constructor of USDS. The test should fail since these addresses would be invalid.
    function testInvalidAddressInConstructor() public {
        address zeroAddress = address(0);
        address wbtcAddress = address(0x1111); // Suppose this is a valid wbtc address
        address wethAddress = address(0x2222); // Suppose this is a valid weth address

        // Test with zero address as wbtc
        vm.expectRevert("_wbtc cannot be address(0)");
        USDS newUSDS = new USDS( IERC20(zeroAddress), IERC20(wethAddress));

        // Test with zero address as weth
        vm.expectRevert("_weth cannot be address(0)");
        newUSDS = new USDS( IERC20(wbtcAddress), IERC20(zeroAddress));
    }


	// A unit test which tries to mint USDS to a zero address. The test should fail since minting to zero addresses should be prohibited.
    function testMintToZeroAddress() public {
        address zeroAddress = address(0);
        uint256 mintAmount = 1 ether;

        // Attempt to mint to a zero address
        vm.expectRevert("Cannot mint to address(0)");
        vm.prank(address(collateral));
        usds.mintTo(zeroAddress, mintAmount);
    }


	// A unit test which tries to mint a zero amount of USDS. The test should not increase the total supply of the USDS.
    function testMintZeroUSDS() public {
        address wallet = address(0x7777);
        uint256 zeroAmount = 0 ether;

        // Store the total supply before minting
        uint256 totalSupplyBeforeMint = usds.totalSupply();

        // Try minting zero USDS from the collateral address
        vm.prank(address(collateral));
        vm.expectRevert( "Cannot mint zero USDS" );
        usds.mintTo(wallet, zeroAmount);

        // The balance of the wallet should not increase
        assertEq(usds.balanceOf(wallet), 0 ether);

        // The total supply of USDS should not increase
        assertEq(usds.totalSupply(), totalSupplyBeforeMint);
    }


	// A unit test to check for integer overflow/underflow in burn, and mint functions.
	// A unit test to check for integer overflow/underflow in burn, mint, and swap functions.
    function testCheckForIntegerOverflowUnderflow() public {
        vm.startPrank(address(collateral));

        uint256 maxUint = type(uint256).max;
        address wallet = address(0x7777);

        // Test overflow in mintTo function
        usds.mintTo(wallet, maxUint);

        vm.expectRevert();
        usds.mintTo(wallet, 1);
        vm.stopPrank();

        // Test underflow in shouldBurnMoreUSDS function
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(maxUint);

        vm.expectRevert();
        usds.shouldBurnMoreUSDS(1);
    }


	// A unit test that checks setting usdsToBurn to very small and very large values to test edge cases.
    function testSetUsdsToBurnEdgeCases() public {
        uint256 smallAmount = 1;  // smallest non-zero value
        uint256 largeAmount = 10**30 * 1 ether;  // arbitrarily large value

        // Test with very small amount
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(smallAmount);
        assertEq(usds.usdsThatShouldBeBurned(), smallAmount);

        // Test with very large amount
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(largeAmount);
        assertEq(usds.usdsThatShouldBeBurned(), smallAmount + largeAmount);
    }


	//	A unit test that burns 0 amount. Total supply should not change.
	function testBurnZeroAmount() public {
        uint256 initialSupply = usds.totalSupply();
        uint256 burnAmount = 0 ether;

        // Prank as the collateral contract to pass the sender check
        vm.prank(address(collateral));
        usds.shouldBurnMoreUSDS(burnAmount);

        // Perform upkeep which should burn the indicated amount
        vm.prank(address(upkeep));
        usds.performUpkeep();

        // Check that the total supply did not change
        assertEq(usds.totalSupply(), initialSupply);
    }


	// A unit test that mints USDS to multiple user accounts from the collateral contract. It should mint different amounts of USDS to multiple user accounts with validations after each minting operation.
	function testMintUSDSMultipleAccounts() public {
        // Define the user accounts and the amount of USDS to mint to each account
        address[] memory users = new address[](3);
        users[0] = address(0x1111); // alice
        users[1] = address(0x2222); // bob
        users[2] = address(0x3333); // charlie

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 3 ether;
        amounts[1] = 2 ether;
        amounts[2] = 1 ether;

        // Mint USDS to each user account from the collateral contract
        vm.startPrank(address(collateral));
        for(uint i = 0; i < users.length; i++)
        	{
            usds.mintTo(users[i], amounts[i]);
            assertEq(usds.balanceOf(users[i]), amounts[i]);
        	}
	    }


	// A unit test where a call is made to performUpkeep from an address that is not the DAO. This test should validate that only the DAO address can call this function.
	function testPerformUpkeepOnlyByDAO() public {
        // Trying to call performUpkeep from an address that is not the Upkeep contract
        vm.startPrank(address(0xdeadbeef));
        vm.expectRevert("USDS.performUpkeep is only callable from the Upkeep contract");
        usds.performUpkeep();
        vm.stopPrank();
    }


	// A unit test that mimics liquidation, and performs upkeep with the amount of usdsToBurn less that the amount of USDS deposited for counterswap
	function testPerformUpkeepWithSufficientUSDSToBurn() public {
        uint256 wbtcAmount = 5 ether;
        uint256 wethAmount = 3 ether;
        uint256 usdsToBurn = 2 ether;
        uint256 depositedUSDS = 3 ether;

        // Send WBTC and WETH to USDS to mimic WBTC/WETH liquidity colalteral that was liquidated
        vm.startPrank( DEPLOYER );
        wbtc.transfer(address(usds), wbtcAmount);
        weth.transfer(address(usds), wethAmount);
        vm.stopPrank();

		// Deposit USDS directly to act like USDS that was a result of counterswaps
		vm.startPrank( address(collateral) );
		usds.mintTo( Counterswap.WBTC_TO_USDS, depositedUSDS / 2 );
		usds.mintTo( Counterswap.WETH_TO_USDS, depositedUSDS / 2 );
		vm.stopPrank();

		vm.startPrank(Counterswap.WBTC_TO_USDS);
		usds.approve( address(pools), depositedUSDS / 2 );
		pools.deposit( usds, depositedUSDS / 2 );
		vm.stopPrank();

		vm.startPrank(Counterswap.WETH_TO_USDS);
		usds.approve( address(pools), depositedUSDS / 2 );
		pools.deposit( usds, depositedUSDS / 2 );
		vm.stopPrank();

		// Verify the USDS deposits
        assertEq(pools.depositedBalance(Counterswap.WBTC_TO_USDS, usds), depositedUSDS / 2);
        assertEq(pools.depositedBalance(Counterswap.WETH_TO_USDS, usds), depositedUSDS / 2);

		// Mimic liquidation calling shouldBurnMoreUSDS
        vm.prank( address(collateral) );
        usds.shouldBurnMoreUSDS(usdsToBurn);

        // Simulate the DAO address calling performUpkeep
        vm.prank(address(upkeep));
        usds.performUpkeep();

        // performUpkeep should have transfer all WBTC and WETH in the contract to the correct counterswap addresses
        assertEq(pools.depositedBalance(Counterswap.WBTC_TO_USDS, wbtc), wbtcAmount);
        assertEq(pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), wethAmount);

        // Check that the USDS balances for the counterswap addresses has been reduced
        // USDS would have been removed from the WBTC_TO_USDS first and then from the WETH_TO_USDS address
        assertEq(pools.depositedBalance(Counterswap.WBTC_TO_USDS, usds), 0);
        assertEq(pools.depositedBalance(Counterswap.WETH_TO_USDS, usds), 1 ether);

        // Check that USDS was burned
        assertEq(usds.totalSupply(), depositedUSDS - usdsToBurn);
        assertEq(usds.usdsThatShouldBeBurned(), 0);
    }


	// A unit test that mimics liquidation, and performs upkeep with the amount of usdsToBurn greater that the amount of USDS deposited for counterswap
	function testPerformUpkeepWithInsufficientUSDSToBurn() public {
        uint256 wbtcAmount = 5 ether;
        uint256 wethAmount = 3 ether;
        uint256 usdsToBurn = 8 ether;
        uint256 depositedUSDS = 3 ether;

        // Send WBTC and WETH to USDS to mimic WBTC/WETH liquidity colalteral that was liquidated
        vm.startPrank( DEPLOYER );
        wbtc.transfer(address(usds), wbtcAmount);
        weth.transfer(address(usds), wethAmount);
        vm.stopPrank();

		// Deposit USDS directly to act like USDS that was a result of counterswaps
		vm.startPrank( address(collateral) );
		usds.mintTo( Counterswap.WBTC_TO_USDS, depositedUSDS / 2 );
		usds.mintTo( Counterswap.WETH_TO_USDS, depositedUSDS / 2 );
		vm.stopPrank();

		vm.startPrank(Counterswap.WBTC_TO_USDS);
		usds.approve( address(pools), depositedUSDS / 2 );
		pools.deposit( usds, depositedUSDS / 2 );
		vm.stopPrank();

		vm.startPrank(Counterswap.WETH_TO_USDS);
		usds.approve( address(pools), depositedUSDS / 2 );
		pools.deposit( usds, depositedUSDS / 2 );
		vm.stopPrank();

		// Verify the USDS deposits
        assertEq(pools.depositedBalance(Counterswap.WBTC_TO_USDS, usds), depositedUSDS / 2);
        assertEq(pools.depositedBalance(Counterswap.WETH_TO_USDS, usds), depositedUSDS / 2);

		// Mimic liquidation calling shouldBurnMoreUSDS
        vm.prank( address(collateral) );
        usds.shouldBurnMoreUSDS(usdsToBurn);

        // Simulate the DAO address calling performUpkeep
        vm.prank(address(upkeep));
        usds.performUpkeep();

        // performUpkeep should have transfer all WBTC and WETH in the contract to the correct counterswap addresses
        assertEq(pools.depositedBalance(Counterswap.WBTC_TO_USDS, wbtc), wbtcAmount);
        assertEq(pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), wethAmount);

        // Check that the USDS balances for the counterswap addresses has been reduced
        // USDS would have been completely removed from both WBTC_TO_USDS and WETH_TO_USDS as the usdsToBurn is excessive
        assertEq(pools.depositedBalance(Counterswap.WBTC_TO_USDS, usds), 0);
        assertEq(pools.depositedBalance(Counterswap.WETH_TO_USDS, usds), 0);

        // Check that USDS was burned
        assertEq(usds.totalSupply(), 0);
        assertEq(usds.usdsThatShouldBeBurned(), usdsToBurn - depositedUSDS);
    }


	// A unit test where an invalid address tries to call setContracts function. This test should validate that only the contract owner can set the contract dependencies.
	function testInvalidAddressSetContracts() public {
            address invalid = address(0xBEEF);
        	address _collateral = address(0x5555);
    		address _pools = address(0x6666);
    		address _exchangeConfig = address(0x7777);

            // New USDS in case Collateral was set in the deployed version already
            usds = new USDS(wbtc, weth);

            // Prank the call to come from invalid address
            vm.prank(invalid);

            // Expect revert as the invalid address is not the contract owner
            vm.expectRevert("Ownable: caller is not the owner");
            usds.setContracts( ICollateral(_collateral), IPools(_pools), IExchangeConfig(_exchangeConfig));

            // Validate that the contracts did not change
            assertEq(address(usds.collateral()), address(0));
            assertEq(address(usds.pools()), address(0));
            assertEq(address(usds.exchangeConfig()), address(0));
        }


	// A unit test to verify the withdrawal of USDS tokens from previous counterswaps in performUpkeep function. This test should validate that the withdrawal logic is correctly retrieving USDS tokens based on previous counterswaps.
	function testCounterswapAndBurn() public {

		// Arbitrary test amount to burn
    	uint256 amountToBurn = 1 ether;

		vm.prank(address(collateral));
		usds.shouldBurnMoreUSDS(amountToBurn);

		assertEq( usds.usdsThatShouldBeBurned(), amountToBurn );


		vm.prank(address(collateral));
		usds.mintTo(DEPLOYER, 10000000 ether);

    	// Deposit WBTC and WETH to the contract
    	vm.startPrank(DEPLOYER);
    	IERC20(wbtc).transfer(address(usds), 100 * 10**8 );
    	IERC20(weth).transfer(address(usds), 100 ether);

    	// Liquidity for counterswap pools
    	wbtc.approve(address(pools), type(uint256).max);
    	weth.approve(address(pools), type(uint256).max);
    	usds.approve(address(pools), type(uint256).max);

    	pools.addLiquidity(wbtc, usds, 100 *10**8, 1000000 ether, 0, block.timestamp );
    	pools.addLiquidity(weth, usds, 100 ether, 100000 ether, 0, block.timestamp );
    	vm.stopPrank();

    	// Perform upkeep to deposit WBTC and WETH to the corresponding counterswap and withdraw USDS
    	vm.prank(address(upkeep));
    	usds.performUpkeep();

		vm.startPrank(DEPLOYER);
		// First swap will establish the ema of the reserves in each pool
		pools.depositSwapWithdraw(usds, wbtc, 1000 ether, 0, block.timestamp);
		pools.depositSwapWithdraw(usds, weth, 1000 ether, 0, block.timestamp);

		// Second swap will make the reserve favorable for counterswap (in comparison to the ema)
		pools.depositSwapWithdraw(usds, wbtc, 100 ether, 0, block.timestamp);
		pools.depositSwapWithdraw(usds, weth, 100 ether, 0, block.timestamp);
		vm.stopPrank();

		assertEq( usds.usdsThatShouldBeBurned(), amountToBurn );

		uint256 usdsSupply = usds.totalSupply();

    	vm.prank(address(upkeep));
    	usds.performUpkeep();

		// All the specified USDS should have been burned
		assertEq( usds.usdsThatShouldBeBurned(), 0 );

		// Make sure the correct amount was burned
		uint256 amountBurned = usdsSupply - usds.totalSupply();
		assertEq( amountBurned, amountToBurn );
    }


	// A unit test to verify the withdrawal of USDS tokens from previous counterswaps in performUpkeep function. This test should validate that the withdrawal logic is correctly retrieving USDS tokens based on previous counterswaps.
	function testCounterswapAndInsufficientBurn() public {

		// Arbitrary test amount to burn
    	uint256 amountToBurn = 1000 ether;

		vm.prank(address(collateral));
		usds.shouldBurnMoreUSDS(amountToBurn);

		assertEq( usds.usdsThatShouldBeBurned(), amountToBurn );


		vm.prank(address(collateral));
		usds.mintTo(DEPLOYER, 10000000 ether);

    	// Deposit WBTC and WETH to the contract
    	vm.startPrank(DEPLOYER);
    	IERC20(wbtc).transfer(address(usds), 100 * 10**8 );
    	IERC20(weth).transfer(address(usds), 100 ether);

    	// Liquidity for counterswap pools
    	wbtc.approve(address(pools), type(uint256).max);
    	weth.approve(address(pools), type(uint256).max);
    	usds.approve(address(pools), type(uint256).max);

    	pools.addLiquidity(wbtc, usds, 100 *10**8, 1000000 ether, 0, block.timestamp );
    	pools.addLiquidity(weth, usds, 100 ether, 100000 ether, 0, block.timestamp );
    	vm.stopPrank();

    	// Perform upkeep to deposit WBTC and WETH to the corresponding counterswap and withdraw USDS
    	vm.prank(address(upkeep));
    	usds.performUpkeep();

		vm.startPrank(DEPLOYER);
		// First swap will establish the ema of the reserves in each pool
		pools.depositSwapWithdraw(usds, wbtc, 100 ether, 0, block.timestamp);
		pools.depositSwapWithdraw(usds, weth, 100 ether, 0, block.timestamp);

		// Second swap will make the reserve favorable for counterswap (in comparison to the ema)
		pools.depositSwapWithdraw(usds, wbtc, 10 ether, 0, block.timestamp);
		pools.depositSwapWithdraw(usds, weth, 10 ether, 0, block.timestamp);
		vm.stopPrank();

		assertEq( usds.usdsThatShouldBeBurned(), amountToBurn );

		uint256 usdsSupply = usds.totalSupply();

    	vm.prank(address(upkeep));
    	usds.performUpkeep();

		uint256 amountBurned = usdsSupply - usds.totalSupply();
		assertEq( usds.usdsThatShouldBeBurned(), amountToBurn - amountBurned );
    }


	// A unit test which tries to call shouldBurnMoreUSDS with zero value. This test should validate that it doesn't affect usdsThatShouldBeBurned.
	function testShouldBurnMoreUSDSWithZeroValue() public {
		uint256 usdsToBurn = 0 ether;

		// Initial set up
		assertEq(usds.usdsThatShouldBeBurned(), 0 ether);

		// Call shouldBurnMoreUSDS with zero value
		vm.prank(address(collateral));
		usds.shouldBurnMoreUSDS(usdsToBurn);

		// Validate that it does not affect usdsThatShouldBeBurned
		assertEq(usds.usdsThatShouldBeBurned(), 0 ether);
	}


	// A unit test which tries to call setContracts after ownership has been renounced. The test should fail since only the owner should be able to set these contracts.
	function testSetContractsAfterRenouncingOwnership() public {
        address _collateral = address(0x5555);
        address _pools = address(0x6666);
        address _exchangeConfig = address(0x7777);

        // New USDS instance
        USDS newUSDS = new USDS(wbtc, weth);

        // Set up contracts
        newUSDS.setContracts(ICollateral(_collateral), IPools(_pools), IExchangeConfig(_exchangeConfig));

        assertEq(address(newUSDS.collateral()), _collateral);
        assertEq(address(newUSDS.pools()), _pools);
        assertEq(address(newUSDS.exchangeConfig()), _exchangeConfig);

        _collateral = address(0x8888);
        _pools = address(0x9999);
        _exchangeConfig = address(0xAAAA);

        vm.expectRevert("Ownable: caller is not the owner");
        newUSDS.setContracts(ICollateral(_collateral), IPools(_pools), IExchangeConfig(_exchangeConfig));

        assertEq(address(newUSDS.collateral()), address(0x5555)); // these addresses should not have changed
        assertEq(address(newUSDS.pools()), address(0x6666)); // these addresses should not have changed
        assertEq(address(newUSDS.exchangeConfig()), address(0x7777)); // these addresses should not have changed
    }


	// A unit test to validate if the initial supply of USDS is zero.
	function testInitialTotalSupplyIsZero() public
    {
        // Verify initial USDS supply
        assertEq(usds.totalSupply(), 0 ether, "Initial USDS supply is not zero");
    }


	// A unit test to verify if performUpkeep correctly burns USDS tokens when there is no remaining balance to burn in Counterswap. This test should validate that all USDS tokens in the contract are burned regardless of the balance in Counterswap.
	function testPerformUpkeepBurnsAllUSDSInContract() public {

        uint256 initialBalance = 10 ether;
        uint256 initialUsdsToBurn = 10 ether;

        // Send tokens to the contract
        vm.startPrank(address(collateral));
        usds.mintTo(address(usds), initialBalance);
        usds.shouldBurnMoreUSDS(initialUsdsToBurn);
        vm.stopPrank();

        // Check initial balances and burn amount
        assertEq(usds.usdsThatShouldBeBurned(), initialUsdsToBurn);
        assertEq(usds.balanceOf(address(usds)), initialBalance);

    	vm.prank(address(upkeep));
    	usds.performUpkeep();

//		uint256 amountBurned = usdsSupply - usds.totalSupply();
//		console.log( "amountBurned: ", amountBurned );

        // All tokens should be burned
        assertEq(usds.balanceOf(address(usds)), 0);

        // No more tokens should be marked to burn
        assertEq(usds.usdsThatShouldBeBurned(), 0);
    }


	// A unit test to verify if performUpkeep correctly burns USDS tokens when there are remaining balance to burn in Counterswap.
	function testPerformUpkeepInsufficientUSDS() public {

        uint256 initialBalance = 10 ether;
        uint256 initialUsdsToBurn = 30 ether;

        // Send tokens to the contract
        vm.startPrank(address(collateral));
        usds.mintTo(address(usds), initialBalance);
        usds.shouldBurnMoreUSDS(initialUsdsToBurn);
        vm.stopPrank();

        // Check initial balances and burn amount
        assertEq(usds.usdsThatShouldBeBurned(), initialUsdsToBurn);
        assertEq(usds.balanceOf(address(usds)), initialBalance);

        // Perform upkeep
        vm.prank(address(exchangeConfig.upkeep()));
        usds.performUpkeep();

        // All tokens should be burned
        assertEq(usds.balanceOf(address(usds)), 0);

        // No more tokens should be marked to burn
        assertEq(usds.usdsThatShouldBeBurned(), 20 ether);
    }


	// A unit test to verify if performUpkeep correctly burns USDS tokens when there is excess burnable balance in Counterswap.
	function testPerformUpkeepExcessUSDS() public {

        uint256 initialBalance = 30 ether;
        uint256 initialUsdsToBurn = 10 ether;

        // Send tokens to the contract
        vm.startPrank(address(collateral));
        usds.mintTo(address(usds), initialBalance);
        usds.shouldBurnMoreUSDS(initialUsdsToBurn);
        vm.stopPrank();

        // Check initial balances and burn amount
        assertEq(usds.usdsThatShouldBeBurned(), initialUsdsToBurn);
        assertEq(usds.balanceOf(address(usds)), initialBalance);

        // Perform upkeep
        vm.prank(address(exchangeConfig.upkeep()));
        usds.performUpkeep();

        // All tokens should be burned
        assertEq(usds.balanceOf(address(usds)), 20 ether);

        // No more tokens should be marked to burn
        assertEq(usds.usdsThatShouldBeBurned(), 0 ether);
    }


	// A unit test which checks the performUpkeep behavior when there is no WBTC or WETH balance in the contract and usdsThatShouldBeBurned is zero. It should validate that no operation will be performed under this scenario.
	function testPerformUpkeepWithoutFundsOrBurn() public {
        // Arrange: Ensure no WBTC balance
        assertEq(wbtc.balanceOf(address(usds)), 0);

        // Arrange: Ensure no WETH balance
        assertEq(weth.balanceOf(address(usds)), 0);

        // Arrange: Ensure no USDS that should be burned
        assertEq(usds.usdsThatShouldBeBurned(), 0 ether);

        // Act: Perform Upkeep
        vm.prank(address(exchangeConfig.upkeep()));
        usds.performUpkeep();

        // Assert: Still no WBTC balance
        assertEq(wbtc.balanceOf(address(usds)), 0);

        // Assert: Still no WETH balance
        assertEq(weth.balanceOf(address(usds)), 0);

        // Assert: Still no USDS that should be burned
        assertEq(usds.usdsThatShouldBeBurned(), 0 ether);
    }


	// A unit test that checks the scenario when _withdrawUSDSFromCounterswap is called with zero remainingUSDSToBurn. In this case, the function should not affect the Counterswap balance and the returned value should be zero.
	function testCounterswapAndNothingToBurn() public {

		// Arbitrary test amount to burn
    	uint256 amountToBurn = 0;

		vm.prank(address(collateral));
		usds.shouldBurnMoreUSDS(amountToBurn);

		assertEq( usds.usdsThatShouldBeBurned(), amountToBurn );


		vm.prank(address(collateral));
		usds.mintTo(DEPLOYER, 10000000 ether);

    	// Deposit WBTC and WETH to the contract
    	vm.startPrank(DEPLOYER);
    	IERC20(wbtc).transfer(address(usds), 100 * 10**8 );
    	IERC20(weth).transfer(address(usds), 100 ether);

    	// Liquidity for counterswap pools
    	wbtc.approve(address(pools), type(uint256).max);
    	weth.approve(address(pools), type(uint256).max);
    	usds.approve(address(pools), type(uint256).max);

    	pools.addLiquidity(wbtc, usds, 100 *10**8, 1000000 ether, 0, block.timestamp );
    	pools.addLiquidity(weth, usds, 100 ether, 100000 ether, 0, block.timestamp );
    	vm.stopPrank();

    	// Perform upkeep to deposit WBTC and WETH to the corresponding counterswap and withdraw USDS
    	vm.prank(address(upkeep));
    	usds.performUpkeep();

		vm.startPrank(DEPLOYER);
		// First swap will establish the ema of the reserves in each pool
		pools.depositSwapWithdraw(usds, wbtc, 1000 ether, 0, block.timestamp);
		pools.depositSwapWithdraw(usds, weth, 1000 ether, 0, block.timestamp);

		// Second swap will make the reserve favorable for counterswap (in comparison to the ema)
		pools.depositSwapWithdraw(usds, wbtc, 100 ether, 0, block.timestamp);
		pools.depositSwapWithdraw(usds, weth, 100 ether, 0, block.timestamp);
		vm.stopPrank();

		assertEq( usds.usdsThatShouldBeBurned(), amountToBurn );

		uint256 usdsSupply = usds.totalSupply();

    	vm.prank(address(upkeep));
    	usds.performUpkeep();

		// None  USDS should be been burned
		assertEq( usds.usdsThatShouldBeBurned(), 0 );

		// Make sure that nothing was burned
		uint256 amountBurned = usdsSupply - usds.totalSupply();
		assertEq( amountBurned, 0 );
    }
	}
