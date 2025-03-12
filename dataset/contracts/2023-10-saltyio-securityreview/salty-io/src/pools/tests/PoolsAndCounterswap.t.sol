// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../dev/Deployment.sol";


contract TestPoolsAndCounterswap is Deployment
	{
	address public alice = address(0x1111);
	address public bob = address(0x2222);
	address public charlie = address(0x3333);

	address public counterswapAddress = Counterswap.WETH_TO_SALT;


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

		finalizeBootstrap();

		vm.prank(address(daoVestingWallet));
		salt.transfer(DEPLOYER, 1000000 ether);
		}


	function setUp() public
		{
		vm.startPrank(DEPLOYER);
		salt.transfer(address(dao), 1000000 ether );
		weth.transfer(address(dao), 1000000 ether );

		// Create SALT/WETH liquidity
		vm.startPrank(address(dao));
		salt.approve( address(pools), type(uint256).max );
		weth.approve( address(pools), type(uint256).max );

		salt.transfer(alice, 1000 ether);
		weth.transfer(alice, 1000 ether);

		pools.addLiquidity( salt, weth, 1000 ether, 2000 ether, 0, block.timestamp);
		vm.stopPrank();

		vm.startPrank(alice);
		salt.approve( address(pools), type(uint256).max );
		weth.approve( address(pools), type(uint256).max );
		vm.stopPrank();
		}


	function _prepareCounterswap() internal
		{
		// Establish the average price in PoolStats by placing a normal swap
		vm.startPrank(alice);
		pools.depositSwapWithdraw( salt, weth, 10 ether, 0, block.timestamp );
		vm.warp( block.timestamp + 5 minutes );
		vm.stopPrank();

		vm.prank(address(dao));
		weth.transfer(address(upkeep), 10000 ether);

		vm.startPrank(address(upkeep));
		weth.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(counterswapAddress, weth, 100 ether);
		vm.stopPrank();
		}


	// A unit test to check that counterswap behaves as expected with whitelisted pairs.
	function testSuccessfulCounterswap() public
		{
		_prepareCounterswap();

		// Initial stats
		uint256 startingDeposited = pools.depositedBalance( counterswapAddress, weth );
		(uint256 startingReserve0, uint256 startingReserve1) = pools.getPoolReserves( weth, salt );

		// Try a successful counterswap from SALT->WETH (which will happen inside of the depositSwapWithdraw transaction)
		vm.prank(alice);
		uint256 wethOut = pools.depositSwapWithdraw( salt, weth, 10 ether, 0, block.timestamp );

		// Determine how much of the WETH deposited into the Counterswap contract was used
		uint256 usedWETHFromCounterswap = startingDeposited - pools.depositedBalance( counterswapAddress, weth );
		uint256 wethThatShouldStillBeDepositedInCounterswap = 100 ether - usedWETHFromCounterswap;

		assertEq( usedWETHFromCounterswap, wethOut, "Incorrect usedWETHFromCounterswap" );
		assertEq( pools.depositedBalance( counterswapAddress, weth ), wethThatShouldStillBeDepositedInCounterswap );

		// Check the updated token balances deposited into the Pools contract itself are correct
		assertEq( pools.depositedBalance( counterswapAddress, weth), wethThatShouldStillBeDepositedInCounterswap );

		// Counterswap should have acquire the SALT from the user's trade
		assertEq( pools.depositedBalance( counterswapAddress, salt), 10 ether );

		// Reserves should have remained essentially the same (as the counterswap undid the user's swap within the same transaction)
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves( weth, salt );
		assertEq( reserve0, startingReserve0, "Incorrect reserve0" );
		assertEq( reserve1, startingReserve1 - 1, "Incorrect reserve1" );
		}


	// A unit test to check that counterswap is not executed when the current prices of the tokens are not favorable compared to the recent average ratio fo the two tokens.
	function testCounterswapWithUnfavorablePrice() public
		{
		_prepareCounterswap();

		// Initial stats
		uint256 startingDeposited = pools.depositedBalance( counterswapAddress, weth );

		// Try with prices that are not favorable compared to the recent average
		vm.warp( block.timestamp + 5 minutes );

		vm.prank(alice);
		// Trading in the same direction as the counterswap we want to perform is not good for the exchange rate for the intended swap
		pools.depositSwapWithdraw( weth, salt, 100 ether, 0, block.timestamp );

		startingDeposited = pools.depositedBalance( counterswapAddress, weth );
		vm.warp( block.timestamp + 5 minutes );

		vm.prank(alice);
		pools.depositSwapWithdraw( salt, weth, 10 ether, 0, block.timestamp );

		uint256 usedWETHFromCounterswap = startingDeposited - pools.depositedBalance( counterswapAddress, weth );
		assertEq( usedWETHFromCounterswap, 0, "Counterswap should not have been used when token prices are not favorable" );
		assertEq( pools.depositedBalance( counterswapAddress, weth), startingDeposited );
		assertEq( pools.depositedBalance( counterswapAddress, salt), 0 );
		}


	// A unit test to check that counterswap is not executed when the user's swapAmountOut is larger than the amount deposited in the Counterswap contract
	function testCounterswapWithExcessiveSwapAmount() public
		{
		_prepareCounterswap();

		// Initial stats
		uint256 startingDeposited = pools.depositedBalance( counterswapAddress, weth );
		vm.warp( block.timestamp + 5 minutes );

		vm.prank(alice);

		// Trade is in the correct direciton and prices should be good, but the user's amountOut is larger than what we have deposited for coutnerswap
		pools.depositSwapWithdraw( salt, weth, 200 ether, 0, block.timestamp );

		uint256 usedWETHFromCounterswap = startingDeposited - pools.depositedBalance( counterswapAddress, weth );
		assertEq( usedWETHFromCounterswap, 0, "Counterswap should not have been used for an excessively large swap" );

		assertEq( pools.depositedBalance( counterswapAddress, weth), startingDeposited );
		assertEq( pools.depositedBalance( counterswapAddress, salt), 0 );
		}
	}