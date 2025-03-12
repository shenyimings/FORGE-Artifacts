// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../dev/Deployment.sol";


contract TestExchangeConfig is Deployment
	{
    address public constant alice = address(0x1111);


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
		}


    // A unit test to check the ExchangeConfig constructor when it is supplied with an invalid null address for one or more parameters. Verify that the function reverts with the correct error message.
    function testConstructorWithInvalidNullAddresses() public
    		{
    		IERC20 fakeIERC20 = IERC20(address(12345));
    		IUSDS fakeUSDS = IUSDS(address(23456));

    		// Test with _salt as zero address
    		vm.expectRevert("_salt cannot be address(0)");
    		new ExchangeConfig(ISalt(address(0)), fakeIERC20, fakeIERC20, fakeIERC20, fakeUSDS, alice);

    		// Test with _wbtc as zero address
    		vm.expectRevert("_wbtc cannot be address(0)");
    		new ExchangeConfig(salt, IERC20(address(0)), fakeIERC20, fakeIERC20, fakeUSDS, alice);

    		// Test with _weth as zero address
    		vm.expectRevert("_weth cannot be address(0)");
    		new ExchangeConfig(salt, fakeIERC20, IERC20(address(0)), fakeIERC20, fakeUSDS, alice);

    		// Test with _dai as zero address
    		vm.expectRevert("_dai cannot be address(0)");
    		new ExchangeConfig(salt, fakeIERC20, fakeIERC20, IERC20(address(0)), fakeUSDS, alice);

    		// Test with _usds as zero address
    		vm.expectRevert("_usds cannot be address(0)");
    		new ExchangeConfig(salt, fakeIERC20, fakeIERC20, fakeIERC20, IUSDS(address(0)), alice);

    		// Test with _teamWallet as zero address
    		vm.expectRevert("_teamWallet cannot be address(0)");
    		new ExchangeConfig(salt, fakeIERC20, fakeIERC20, fakeIERC20, fakeUSDS, address(0));
    		}


    // A unit test to check the setDAO function when it is called by an address other than the owner. Verify that the function reverts with the correct error message.
	function testSetDAOAsNonOwner() public
        {
        vm.prank(DEPLOYER);
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet);

		vm.expectRevert("Ownable: caller is not the owner" );
		exchangeConfig.setDAO(IDAO(address(0x2222)));
        }


    // A unit test to check the setDAO function when called by the owner and the dao state variable has not been set yet. Ensure that the dao state variable is correctly set.
    function testSetDAO() public
        {
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet);

        // Initialize an instance of the DAO
        IDAO _dao = IDAO(address(0x1111));

        // Call `setDAO` function with the initialized _dao instance
        exchangeConfig.setDAO(_dao);

        // Assert that the `dao` state variable is now equal to the _dao instance
        assertEq( address(exchangeConfig.dao()), address(_dao) );

        // Calling `setDAO` again should throw an error
        vm.expectRevert("setDAO can only be called once");
        exchangeConfig.setDAO(_dao);
        }


    // A unit test to check the setUpkeep function when it is called by an address other than the owner. Verify that the function reverts with the correct error message.
	function testSetUpkeepAsNonOwner() public
        {
        vm.prank(DEPLOYER);
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet);

		vm.expectRevert("Ownable: caller is not the owner" );
		exchangeConfig.setUpkeep(IUpkeep(address(0x2222)));
        }


    // A unit test to check the setUpkeep function when called by the owner and the upkeep state variable has not been set yet. Ensure that the upkeep state variable is correctly set.
    function testSetUpkeep() public
        {
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet);

        // Initialize an instance of Upkeep
        IUpkeep _upkeep = IUpkeep(address(0x1111));

        // Call `setUpkeep` function with the initialized _upkeep instance
        exchangeConfig.setUpkeep(_upkeep);

        // Assert that the `upkeep` state variable is now equal to the _upkeep instance
        assertEq( address(exchangeConfig.upkeep()), address(_upkeep) );

        // Calling `setUpkeep` again should throw an error
        vm.expectRevert("setUpkeep can only be called once");
        exchangeConfig.setUpkeep(_upkeep);
        }



    // A unit test to check the setVestingWallets function when it is called by an address other than the owner. Verify that the function reverts with the correct error message.
	function testSetVestingWalletsAsNonOwner() public
        {
        vm.prank(DEPLOYER);
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet);

		vm.expectRevert("Ownable: caller is not the owner" );
		exchangeConfig.setVestingWallets(address(0x2222), address(0x2223));
        }


    // A unit test to check the setInitialDistribution function when it is called by an address other than the owner. Verify that the function reverts with the correct error message.
	function testSetInitialDistributionAsNonOwner() public
        {
        vm.prank(DEPLOYER);
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet);

		vm.expectRevert("Ownable: caller is not the owner" );
		exchangeConfig.setInitialDistribution(IInitialDistribution(address(0x2222)));
        }



    // A unit test to check the setAccessManager function when it is called by an address other than the owner. Verify that the function reverts with the correct error message.
	function testSetAccessManagerAsNonOwner() public
        {
        vm.prank(DEPLOYER);
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet);

		vm.expectRevert("Ownable: caller is not the owner" );
		exchangeConfig.setAccessManager(IAccessManager(address(0x2222)));
        }



    // A unit test to check the setStakingRewardsEmitter function when it is called by an address other than the owner. Verify that the function reverts with the correct error message.
	function testSetStakingRewardsEmitterAsNonOwner() public
        {
        vm.prank(DEPLOYER);
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet);

		vm.expectRevert("Ownable: caller is not the owner" );
		exchangeConfig.setStakingRewardsEmitter(IRewardsEmitter(address(0x2222)));
        }


    // A unit test to check the setLiquidityRewardsEmitter function when it is called by an address other than the owner. Verify that the function reverts with the correct error message.
	function testSetLiquidityRewardsEmitterAsNonOwner() public
        {
        vm.prank(DEPLOYER);
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet);

		vm.expectRevert("Ownable: caller is not the owner" );
		exchangeConfig.setLiquidityRewardsEmitter(IRewardsEmitter(address(0x2222)));
        }









    // A unit test to check the setVestingWallets function when called by the owner and the vestingWallets state variables have not been set yet. Ensure that the vestingWallets state variables are correctly set.
    function testSetVestingWallets() public
    {
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet);

        // Addresses for vesting wallets
        address teamVestingWalletAddr = address(0x1111);
        address daoVestingWalletAddr = address(0x1112);

        // Call `setVestingWallets` function with the initialized addresses
        exchangeConfig.setVestingWallets(teamVestingWalletAddr, daoVestingWalletAddr);

        // Assert that the `daoVestingWallet` and `teamVestingWallet` state variable are now equal to the initialized addresses
        assertEq(exchangeConfig.daoVestingWallet(), daoVestingWalletAddr);
        assertEq(exchangeConfig.teamVestingWallet(), teamVestingWalletAddr);

        // Calling `setVestingWallets` again should throw an error
        vm.expectRevert("setVestingWallets can only be called once");
        exchangeConfig.setVestingWallets(address(0x2222), address(0x2223));
    }

    // A unit test to check the setInitialDistribution function when called by the owner and the initialDistribution state variable has not been set yet. Ensure that the initialDistribution state variable is correctly set.
    function testSetInitialDistribution() public
    {
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet);

        // Initialize an instance of the InitialDistribution
        IInitialDistribution _initDist = IInitialDistribution(address(0x1111));

        // Call `setInitialDistribution` function with the initialized _initDist instance
        exchangeConfig.setInitialDistribution(_initDist);

        // Assert that the `initialDistribution` state variable is now equal to the _initDist instance
        assertEq(address(exchangeConfig.initialDistribution()), address(_initDist));

        // Calling `setInitialDistribution` again should throw an error
        vm.expectRevert("setInitialDistribution can only be called once");
        exchangeConfig.setInitialDistribution(_initDist);
    }

    // A unit test to check the setAccessManager function when called by the owner and the accessManager state variable has not been set yet. Ensure that the accessManager state variable is correctly set.
    function testSetAccessManager() public
    {
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet);

        // Initialize an instance of the AccessManager
        IAccessManager _accessManager = IAccessManager(address(0x1111));

        // Call `setAccessManager` function with the initialized _accessManager instance
        exchangeConfig.setAccessManager(_accessManager);

        // Assert that the `accessManager` state variable is now equal to the _accessManager instance
        assertEq(address(exchangeConfig.accessManager()), address(_accessManager));
    }

    // A unit test to check the setStakingRewardsEmitter function when called by the owner and the stakingRewardsEmitter state variable has not been set yet. Ensure that the stakingRewardsEmitter state variable is correctly set.
    function testSetStakingRewardsEmitter() public
    {
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet);

        // Initialize an instance of the StakingRewardsEmitter
        IRewardsEmitter _rewardsEmitter = IRewardsEmitter(address(0x1111));

        // Call `setStakingRewardsEmitter` function with the initialized _rewardsEmitter instance
        exchangeConfig.setStakingRewardsEmitter(_rewardsEmitter);

        // Assert that the `stakingRewardsEmitter` state variable is now equal to the _rewardsEmitter instance
        assertEq(address(exchangeConfig.stakingRewardsEmitter()), address(_rewardsEmitter));
    }

    // A unit test to check the setLiquidityRewardsEmitter function when called by the owner and the liquidityRewardsEmitter state variable has not been set yet. Ensure that the liquidityRewardsEmitter state variable is correctly set.
    function testSetLiquidityRewardsEmitter() public
    {
        exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet);

        // Initialize an instance of the StakingRewardsEmitter
        IRewardsEmitter _rewardsEmitter = IRewardsEmitter(address(0x1111));

        // Call `setLiquidityRewardsEmitter` function with the initialized _rewardsEmitter instance
        exchangeConfig.setLiquidityRewardsEmitter(_rewardsEmitter);

        // Assert that the `liquidityRewardsEmitter` state variable is now equal to the _rewardsEmitter instance
        assertEq(address(exchangeConfig.liquidityRewardsEmitter()), address(_rewardsEmitter));
    }


    // A unit test to test that proposeTeamWallet works as expected
    function testProposeTeamWallet() public
    	{
        // Initialize a random address
        address randomAddr = address(0x1234);

        // Update teamWallet to a random address
        vm.prank(teamWallet);
        exchangeConfig.proposeTeamWallet(randomAddr);

        // Assert that the teamWallet state variable is now equal to the random address
        assertEq(exchangeConfig.proposedTeamWallet(), randomAddr);
    }


    // A unit test to check the setTeamWallet function when it is called by an address other than the current teamWallet. Verify that the function reverts with the correct error message.
    function testSetTeamWalletCalledByOtherThanTeamWallet() public {
        // Call function with Prank
        vm.prank(address(0x2345));

        // Expect function to revert with correct message
        vm.expectRevert("Only the current team can change the teamWallet");
        exchangeConfig.proposeTeamWallet(address(0x1234));
    }


    // A unit test to check the walletHasAccess function when the given wallet address is the DAO address. Verify that the function returns true.
    function testWalletHasAccessDAOWallet() public {
    	// Call `walletHasAccess` function with DAO address
        assertTrue(exchangeConfig.walletHasAccess(address(dao)));
    }



    // A unit test to check the walletHasAccess function when the given wallet address is not the DAO address and the accessManager contract allows access for this wallet. Verify that the function returns true.
    function testWalletHasAccessNonDAOWalletAllowedByAccessManager() public {

    	// Give access to the user
		bytes memory sig = abi.encodePacked(hex"140e05ee4a808d731d7a8d72d685f7335c13b502823a4ff504fb894b96b230a277a693cc4d7ad68065776e05d9b7159fdb193912611d3c3c39abffe6f0e73bbf1c");
		vm.prank( address(0x1234) );
		accessManager.grantAccess(sig);


    	// Call `walletHasAccess` function with a non-DAO address which is allowed by accessManager
    	assertTrue(exchangeConfig.walletHasAccess(address(0x1234)));
    }


    // A unit test to check the walletHasAccess function when the given wallet address is not the DAO address and the accessManager contract does not allow access for this wallet. Verify that the function returns false.
    function testWalletHasAccessNonDAOWalletNotAllowedByAccessManager() public {
    	// Call `walletHasAccess` function with a non-DAO address which is not allowed by accessManager
    	assertFalse(exchangeConfig.walletHasAccess(address(0x1234)));
    }


    // A unit test to test that confirmTeamWallet works as expected
    function testConfirmTeamWallet() public
    	{
        // Initialize a random address
        address randomAddr = address(0x1234);

        // Update teamWallet to a random address
        vm.prank(teamWallet);
        exchangeConfig.proposeTeamWallet(randomAddr);

        assertEq(exchangeConfig.proposedTeamWallet(), randomAddr);

		vm.expectRevert( "Only the proposed teamWallet can confirm the teamWallet change" );
		exchangeConfig.confirmTeamWallet();

        vm.prank(randomAddr);
        exchangeConfig.confirmTeamWallet();

        // Assert that the teamWallet state variable is now equal to the random address
        assertEq(exchangeConfig.teamWallet(), randomAddr);
        }
	}
