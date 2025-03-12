// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../dev/Deployment.sol";
import "./TestCallReceiver.sol";


contract TestDAO is Deployment
	{
	// User wallets for testing
    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);


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
		salt.transfer(DEPLOYER, 15000000 ether);

		// Mint some USDS to the DEPLOYER and alice
		vm.startPrank( address(collateral) );
		usds.mintTo( DEPLOYER, 2000000 ether );
		usds.mintTo( alice, 1000000 ether );
		vm.stopPrank();

		vm.prank( DEPLOYER );
		salt.transfer( alice, 10000000 ether );
		}


    function setUp() public
    	{
    	vm.startPrank( DEPLOYER );
    	usds.approve( address(dao), type(uint256).max );
    	salt.approve( address(staking), type(uint256).max );
    	usds.approve( address(proposals), type(uint256).max );
    	vm.stopPrank();

    	vm.startPrank( alice );
    	usds.approve( address(dao), type(uint256).max );
    	salt.approve( address(staking), type(uint256).max );
    	usds.approve( address(proposals), type(uint256).max );
    	vm.stopPrank();
    	}



	function _parameterValue( Parameters.ParameterTypes parameter ) internal view returns (uint256)
		{
		if ( parameter == Parameters.ParameterTypes.maximumWhitelistedPools )
			return poolsConfig.maximumWhitelistedPools();

		else if ( parameter == Parameters.ParameterTypes.minUnstakeWeeks )
			return stakingConfig.minUnstakeWeeks();
		else if ( parameter == Parameters.ParameterTypes.maxUnstakeWeeks )
			return stakingConfig.maxUnstakeWeeks();
		else if ( parameter == Parameters.ParameterTypes.minUnstakePercent )
			return stakingConfig.minUnstakePercent();
		else if ( parameter == Parameters.ParameterTypes.modificationCooldown )
			return stakingConfig.modificationCooldown();

		else if ( parameter == Parameters.ParameterTypes.rewardsEmitterDailyPercentTimes1000 )
			return rewardsConfig.rewardsEmitterDailyPercentTimes1000();
		else if ( parameter == Parameters.ParameterTypes.emissionsWeeklyPercentTimes1000 )
			return rewardsConfig.emissionsWeeklyPercentTimes1000();
		else if ( parameter == Parameters.ParameterTypes.stakingRewardsPercent )
			return rewardsConfig.stakingRewardsPercent();
		else if ( parameter == Parameters.ParameterTypes.percentRewardsSaltUSDS )
			return rewardsConfig.percentRewardsSaltUSDS();

		else if ( parameter == Parameters.ParameterTypes.rewardPercentForCallingLiquidation )
			return stableConfig.rewardPercentForCallingLiquidation();
		else if ( parameter == Parameters.ParameterTypes.maxRewardValueForCallingLiquidation )
			return stableConfig.maxRewardValueForCallingLiquidation();
		else if ( parameter == Parameters.ParameterTypes.minimumCollateralValueForBorrowing )
			return stableConfig.minimumCollateralValueForBorrowing();
		else if ( parameter == Parameters.ParameterTypes.initialCollateralRatioPercent )
			return stableConfig.initialCollateralRatioPercent();
		else if ( parameter == Parameters.ParameterTypes.minimumCollateralRatioPercent )
			return stableConfig.minimumCollateralRatioPercent();

		else if ( parameter == Parameters.ParameterTypes.bootstrappingRewards )
			return daoConfig.bootstrappingRewards();
		else if ( parameter == Parameters.ParameterTypes.percentPolRewardsBurned )
			return daoConfig.percentPolRewardsBurned();
		else if ( parameter == Parameters.ParameterTypes.baseBallotQuorumPercentTimes1000 )
			return daoConfig.baseBallotQuorumPercentTimes1000();
		else if ( parameter == Parameters.ParameterTypes.ballotDuration )
			return daoConfig.ballotDuration();
		else if ( parameter == Parameters.ParameterTypes.baseProposalCost )
			return daoConfig.baseProposalCost();
		else if ( parameter == Parameters.ParameterTypes.maxPendingTokensForWhitelisting )
			return daoConfig.maxPendingTokensForWhitelisting();
		else if ( parameter == Parameters.ParameterTypes.arbitrageProfitsPercentPOL )
			return daoConfig.arbitrageProfitsPercentPOL();
		else if ( parameter == Parameters.ParameterTypes.upkeepRewardPercent )
			return daoConfig.upkeepRewardPercent();

		else if ( parameter == Parameters.ParameterTypes.maximumPriceFeedPercentDifferenceTimes1000 )
			return priceAggregator.maximumPriceFeedPercentDifferenceTimes1000();
		else if ( parameter == Parameters.ParameterTypes.setPriceFeedCooldown )
			return priceAggregator.setPriceFeedCooldown();

		require(false, "Invalid ParameterType" );
		return 0;
		}


	function _checkFinalizeIncreaseParameterBallot( uint256 parameterNum  ) internal {

		uint256 ballotID = parameterNum + 1;
		uint256 originalValue = _parameterValue( Parameters.ParameterTypes( parameterNum ) );

        proposals.proposeParameterBallot(parameterNum, "description" );
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, true, "Parameter Ballot not correctly created");

        proposals.castVote(ballotID, Vote.INCREASE);

        // Increase block time to finalize the ballot
        vm.warp(block.timestamp + 11 days );

        // Test Parameter Ballot finalization
        dao.finalizeBallot(ballotID);
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, false, "Parameter Ballot not correctly finalized");

		uint256 newValue = _parameterValue( Parameters.ParameterTypes( parameterNum ) );

		if ( parameterNum != 9 )
			assert( newValue > originalValue );
    }


	function _checkFinalizeNoChangeParameterBallot( uint256 parameterNum  ) internal {

		uint256 ballotID = parameterNum + 1;
		uint256 originalValue = _parameterValue( Parameters.ParameterTypes( parameterNum ) );

        proposals.proposeParameterBallot(parameterNum, "description" );
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, true, "Parameter Ballot not correctly created");

        proposals.castVote(ballotID, Vote.NO_CHANGE);

        // Increase block time to finalize the ballot
        vm.warp(block.timestamp + 11 days );

        // Test Parameter Ballot finalization
        dao.finalizeBallot(ballotID);
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, false, "Parameter Ballot not correctly finalized");

		uint256 newValue = _parameterValue( Parameters.ParameterTypes( parameterNum ) );

		assert( newValue == originalValue );
    }


	function _checkFinalizeDecreaseParameterBallot( uint256 parameterNum  ) internal {

		uint256 ballotID = parameterNum + 1;
		uint256 originalValue = _parameterValue( Parameters.ParameterTypes( parameterNum ) );

        proposals.proposeParameterBallot(parameterNum, "description" );
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, true, "Parameter Ballot not correctly created");

        proposals.castVote(ballotID, Vote.DECREASE);

        // Increase block time to finalize the ballot
        vm.warp(block.timestamp + 11 days );

        // Test Parameter Ballot finalization
        dao.finalizeBallot(ballotID);
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, false, "Parameter Ballot not correctly finalized");

		uint256 newValue = _parameterValue( Parameters.ParameterTypes( parameterNum ) );

		if ( parameterNum != 1 )
		if ( parameterNum != 9 )
		if ( parameterNum != 13 )
			assert( newValue < originalValue );
    }


	// A unit test to test all parameters and that a successful INCREASE vote has the expected effects
    function testFinalizeIncreaseParameterBallots() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 5000000 ether );

    	for( uint256 i = 0; i < 24; i++ )
	 		_checkFinalizeIncreaseParameterBallot( i );
    	}


	// A unit test to test all parameters and that a successful DECREASE vote has the expected effects
    function testFinalizeDecreaseParameterBallots() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 5000000 ether );

    	for( uint256 i = 0; i < 24; i++ )
	 		_checkFinalizeDecreaseParameterBallot( i );
    	}


	// A unit test to test all parameters and that a successful NO_CHANGE vote has the expected effects
    function testFinalizeNoChangeParameterBallots() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 5000000 ether );

    	for( uint256 i = 0; i < 24; i++ )
	 		_checkFinalizeNoChangeParameterBallot( i );
    	}


	function _voteForAndFinalizeBallot( uint256 ballotID, Vote vote ) internal
		{
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, true, "Ballot not correctly created");

        proposals.castVote(ballotID, vote);

        // Increase block time to finalize the ballot
        vm.warp(block.timestamp + 11 days );

        // Test Parameter Ballot finalization
        dao.finalizeBallot(ballotID);
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, false, "Ballot not correctly finalized");
		}


	// A unit test to test that finalizing an approved whitelist token ballot has the desired effect
    function testWhitelistTokenApproved() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

       	IERC20 token = new TestERC20("TEST", 18);

        proposals.proposeTokenWhitelisting( token, "", "" );

		uint256 ballotID = 1;
        proposals.castVote(ballotID, Vote.YES);

        // Increase block time to finalize the ballot
        vm.warp(block.timestamp + 11 days );

        // Test Parameter Ballot finalization
		salt.transfer( address(dao), 199999 ether );

		vm.expectRevert( "Whitelisting is not currently possible due to insufficient bootstrapping rewards" );
        dao.finalizeBallot(ballotID);

		salt.transfer( address(dao), 5 ether );

    	uint256 startingBalanceDAO = salt.balanceOf(address(dao));
        dao.finalizeBallot(ballotID);

		// Check for the effects of the vote
		assertTrue( poolsConfig.tokenHasBeenWhitelisted(token, wbtc, weth), "Token not whitelisted" );

		// Check to see that the bootstrapping rewards have been sent
		bytes32[] memory poolIDs = new bytes32[](2);
		(poolIDs[0],) = PoolUtils._poolID(token,wbtc);
		(poolIDs[1],) = PoolUtils._poolID(token,weth);

		uint256[] memory pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools( poolIDs );

		assertEq( pendingRewards[0], daoConfig.bootstrappingRewards() );
		assertEq( pendingRewards[1], daoConfig.bootstrappingRewards() );

		uint256 sentFromDAO = startingBalanceDAO - salt.balanceOf(address(dao));
		assertEq( sentFromDAO, daoConfig.bootstrappingRewards() * 2 );
    	}


	// A unit test to test that finalizing a denied whitelist token ballot has the desired effect
    function testWhitelistTokenDenied() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

       	IERC20 token = new TestERC20("TEST", 18);
		salt.transfer( address(dao), 1000000 ether );

        proposals.proposeTokenWhitelisting( token, "", "description"  );
		_voteForAndFinalizeBallot(1, Vote.NO);

		// Check for the effects of the vote
		assertFalse( poolsConfig.tokenHasBeenWhitelisted(token, wbtc, weth), "Token should not be whitelisted" );
    	}


	// A unit test to test that finalizing an approved whitelist token ballot has the desired effect
    function testUnwhitelistTokenApproved() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

       	IERC20 token = new TestERC20("TEST", 18);
		salt.transfer( address(dao), 1000000 ether );

        proposals.proposeTokenWhitelisting( token, "", "" );
		_voteForAndFinalizeBallot(1, Vote.YES);

        proposals.proposeTokenUnwhitelisting( token, "", "" );
		_voteForAndFinalizeBallot(2, Vote.YES);

		// Check for the effects of the vote
		assertFalse( poolsConfig.tokenHasBeenWhitelisted(token, wbtc, weth), "Token should not be whitelisted" );
    	}


	// A unit test to test that finalizing a denied whitelist token ballot has the desired effect
    function testUnwhitelistTokenDenied() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

       	IERC20 token = new TestERC20("TEST", 18);
		salt.transfer( address(dao), 1000000 ether );

        proposals.proposeTokenWhitelisting( token, "", "" );
		_voteForAndFinalizeBallot(1, Vote.YES);

        proposals.proposeTokenUnwhitelisting( token, "", "" );
		_voteForAndFinalizeBallot(2, Vote.NO);

		// Check for the effects of the vote
		assertTrue( poolsConfig.tokenHasBeenWhitelisted(token, wbtc, weth), "Token not whitelisted" );
    	}


	// A unit test to test that finalizing an approved send SALT ballot has the desired effect
    function testSendSaltApproved() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

		salt.transfer( address(dao), 1000000 ether );

        proposals.proposeSendSALT( bob, 123 ether, "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		// Check for the effects of the vote
		assertEq( salt.balanceOf( bob ), 123 ether, "Bob didn't receive SALT" );
    	}


	// A unit test to test that finalizing a denied send SALT ballot has the desired effect
    function testSendSaltDenied() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

		salt.transfer( address(dao), 1000000 ether );

        proposals.proposeSendSALT( bob, 123 ether, "description" );
		_voteForAndFinalizeBallot(1, Vote.NO);

		// Check for the effects of the vote
		assertEq( salt.balanceOf( bob ), 0, "Bob shouldn't receive SALT" );
    	}


	// A unit test to test that finalizing an approved call contract ballot has the desired effect
    function testCallContractApproved() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

		TestCallReceiver testReceiver = new TestCallReceiver();

        proposals.proposeCallContract( address(testReceiver), 123, "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		// Check for the effects of the vote
		assertEq( testReceiver.value(), 123, "Receiver didn't receive the call" );
    	}


	// A unit test to test that finalizing a denied call contract ballot has the desired effect
    function testCallContractDenied() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

		TestCallReceiver testReceiver = new TestCallReceiver();

        proposals.proposeCallContract( address(testReceiver), 123, "description" );
		_voteForAndFinalizeBallot(1, Vote.NO);

		// Check for the effects of the vote
		assertTrue( testReceiver.value() != 123, "Receiver shouldn't receive the call" );
    	}


	// A unit test to test that finalizing an approved include country ballot has the desired effect
    function testIncludeCountryApproved() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeCountryExclusion( "US", "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		assertTrue( dao.countryIsExcluded( "US" ), "US should be excluded" );
		vm.stopPrank();

		// GeoVersion is now 1 and effectively has cleared access
		bytes memory sig = abi.encodePacked(hex"8b213e0ebbb653419203488db6b2ea3dcd35067906b813aee2e2ae20db4218233a72959b5aa61d2e1673aac95a75ac46cb80d93630f7b2d98de5e7344e6f14821c");
		vm.prank( alice );
		accessManager.grantAccess(sig);


        vm.startPrank(alice);
        proposals.proposeCountryInclusion( "US", "description" );
		_voteForAndFinalizeBallot(2, Vote.YES);

		assertFalse( dao.countryIsExcluded( "US" ), "US shouldn't be excluded" );
    	}


	// A unit test to test that finalizing a denied include country ballot has the desired effect
    function testIncludeCountryDenied() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeCountryExclusion( "US", "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		assertTrue( dao.countryIsExcluded( "US" ), "US should be excluded" );
		vm.stopPrank();

		// GeoVersion is now 1 and effectively has cleared access
		bytes memory sig = abi.encodePacked(hex"8b213e0ebbb653419203488db6b2ea3dcd35067906b813aee2e2ae20db4218233a72959b5aa61d2e1673aac95a75ac46cb80d93630f7b2d98de5e7344e6f14821c");
		vm.prank( alice );
		accessManager.grantAccess(sig);


        vm.startPrank(alice);
        proposals.proposeCountryInclusion( "US", "description" );
		_voteForAndFinalizeBallot(2, Vote.NO);

		assertTrue( dao.countryIsExcluded( "US" ), "US should be excluded" );
    	}


	// A unit test to test that finalizing an approved exclude country ballot has the desired effect
    function testExcludeCountryApproved() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeCountryExclusion( "US", "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		assertTrue( dao.countryIsExcluded( "US" ), "US should be excluded" );
    	}


	// A unit test to test that finalizing a denied exclude country ballot has the desired effect
    function testExcludeCountryDenied() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeCountryExclusion( "US", "description" );
		_voteForAndFinalizeBallot(1, Vote.NO);

		assertFalse( dao.countryIsExcluded( "US" ), "US shouldn't be excluded" );
    	}


	function _contractForName( string memory contractName ) internal view returns (address)
		{
		bytes32 nameHash = keccak256(bytes(contractName));

		if ( nameHash == keccak256(bytes("accessManager" )))
			return address(exchangeConfig.accessManager());
		if ( nameHash == keccak256(bytes("stakingRewardsEmitter" )))
			return address(exchangeConfig.stakingRewardsEmitter());
		if ( nameHash == keccak256(bytes("liquidityRewardsEmitter" )))
			return address(exchangeConfig.liquidityRewardsEmitter());
		if ( nameHash == keccak256(bytes("priceFeed1" )))
			return address(priceAggregator.priceFeed1());
		if ( nameHash == keccak256(bytes("priceFeed2" )))
			return address(priceAggregator.priceFeed2());
		if ( nameHash == keccak256(bytes("priceFeed3" )))
			return address(priceAggregator.priceFeed3());

		return address(0);
		}


    function _checkSetContractApproved( uint256 ballotID, string memory contractName, address newAddress) internal
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeSetContractAddress( contractName, newAddress, "description" );
		_voteForAndFinalizeBallot(ballotID, Vote.YES);

		// Above finalization should create a confirmation ballot
		_voteForAndFinalizeBallot(ballotID + 1, Vote.YES);

		assertEq( _contractForName(contractName), newAddress, "Contract address should have changed" );
		vm.stopPrank();
    	}


	// A unit test to test that finalizing an approved setContract ballot works with all possible contract options
	function testSetContractApproved() public
		{
		_checkSetContractApproved( 1, "stakingRewardsEmitter", address(0x1231233 ) );
		_checkSetContractApproved( 3, "liquidityRewardsEmitter", address(0x1231234 ) );
		_checkSetContractApproved( 5, "priceFeed1", address(0x1231236 ) );
		vm.warp(block.timestamp + 60 days);
		_checkSetContractApproved( 7, "priceFeed2", address(0x1231237 ) );
		vm.warp(block.timestamp + 60 days);
		_checkSetContractApproved( 9, "priceFeed3", address(0x1231238 ) );

		// Done last to prevent access issues
		_checkSetContractApproved( 11, "accessManager", address( new AccessManager(dao) ) );
		}


    function _checkSetContractDenied1( uint256 ballotID, string memory contractName, address newAddress) internal
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeSetContractAddress( contractName, newAddress, "description" );
		_voteForAndFinalizeBallot(ballotID, Vote.NO);

		assertFalse( _contractForName(contractName) == newAddress, "Contract address should not have changed" );
		vm.stopPrank();
    	}


	// A unit test to test that  with all possible contract options, finalizing a setContract ballot has no effect when the initial ballot fails
	function testSetContractDenied1() public
		{
		_checkSetContractDenied1( 1, "priceFeed", address(0x1231231 ) );
		_checkSetContractDenied1( 2, "accessManager", address( new AccessManager(dao) ) );
		_checkSetContractDenied1( 3, "stakingRewardsEmitter", address(0x1231233 ) );
		_checkSetContractDenied1( 4, "liquidityRewardsEmitter", address(0x1231234 ) );
		_checkSetContractDenied1( 5, "priceFeed1", address(0x1231236 ) );
		_checkSetContractDenied1( 6, "priceFeed2", address(0x1231237 ) );
		_checkSetContractDenied1( 7, "priceFeed3", address(0x1231238 ) );
		}


    function _checkSetContractDenied2( uint256 ballotID, string memory contractName, address newAddress) internal
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeSetContractAddress( contractName, newAddress, "description" );
		_voteForAndFinalizeBallot(ballotID, Vote.YES);

		// Above finalization should create a confirmation ballot
		_voteForAndFinalizeBallot(ballotID + 1, Vote.NO);

		assertFalse( _contractForName(contractName) == newAddress, "Contract address should not have changed" );
		vm.stopPrank();
    	}


	// A unit test to test that  with all possible contract options, finalizing a setContract ballot has no effect when the confirm ballot fails
	function testSetContractDenied2() public
		{
		_checkSetContractDenied2( 1, "accessManager", address( new AccessManager(dao) ) );
		_checkSetContractDenied2( 3, "stakingRewardsEmitter", address(0x1231233 ) );
		_checkSetContractDenied2( 5, "liquidityRewardsEmitter", address(0x1231234 ) );
		_checkSetContractDenied2( 7, "priceFeed1", address(0x1231236 ) );
		_checkSetContractDenied2( 9, "priceFeed2", address(0x1231237 ) );
		_checkSetContractDenied2( 11, "priceFeed3", address(0x1231238 ) );
		}


	// A unit test to test that finalizing an approved websiteUpdate ballot has the desired effect
    function testSetWebsiteApproved() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeWebsiteUpdate( "websiteURL",  "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		// Above finalization should create a confirmation ballot
		_voteForAndFinalizeBallot(2, Vote.YES);

		assertEq( dao.websiteURL(), "websiteURL", "Website URL should have changed" );
		vm.stopPrank();
    	}


	// A unit test to test that finalizing a websiteUpdate ballot in which the initial ballot fails has no effect
    function testSetWebsiteDenied1() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeWebsiteUpdate( "websiteURL",  "description" );
		_voteForAndFinalizeBallot(1, Vote.NO);

		assertEq( dao.websiteURL(), "", "Website URL should not have changed" );
		vm.stopPrank();
    	}


	// A unit test to test that finalizing a websiteUpdate ballot in which the confirmation ballot fails has no effect
    function testSetWebsiteDenied2() public
    	{
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );

        proposals.proposeWebsiteUpdate( "websiteURL",  "description" );
		_voteForAndFinalizeBallot(1, Vote.YES);

		// Above finalization should create a confirmation ballot
		_voteForAndFinalizeBallot(2, Vote.NO);

		assertEq( dao.websiteURL(), "", "Website URL should not have changed" );
		vm.stopPrank();
    	}


	// A unit test to check the constructor of the contract.
	function testDAOConstructor() public {

        vm.startPrank(DEPLOYER);
        DAO testDAO = new DAO(pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator, liquidityRewardsEmitter );

        assertEq(address(testDAO.pools()), address(pools), "Pools contract address mismatch");
        assertEq(address(testDAO.proposals()), address(proposals), "Proposals contract address mismatch");
        assertEq(address(testDAO.exchangeConfig()), address(exchangeConfig), "ExchangeConfig contract address mismatch");
        assertEq(address(testDAO.poolsConfig()), address(poolsConfig), "PoolsConfig contract address mismatch");
        assertEq(address(testDAO.stakingConfig()), address(stakingConfig), "StakingConfig contract address mismatch");
        assertEq(address(testDAO.rewardsConfig()), address(rewardsConfig), "RewardsConfig contract address mismatch");
        assertEq(address(testDAO.stableConfig()), address(stableConfig), "StableConfig contract address mismatch");
        assertEq(address(testDAO.daoConfig()), address(daoConfig), "DAOConfig contract address mismatch");
        assertEq(address(testDAO.priceAggregator()), address(priceAggregator), "PriceAggregator contract address mismatch");
        assertEq(address(testDAO.liquidityRewardsEmitter()), address(liquidityRewardsEmitter), "LiquidityRewardsEmitter contract address mismatch");

        vm.stopPrank();
    }


	// A unit test to validate the finalizeBallot function with ballots that should not yet be finalizable.
	function testFinalizeBallotWithNotFinalizableBallots() public {
        vm.startPrank(alice);
        staking.stakeSALT(5 ether);

        // Propose a parameter ballot
        proposals.proposeParameterBallot(0, "description");

        // Get the ballot ID
        uint256 ballotID = 1;

        // Assert that the ballot is live
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, true, "Parameter Ballot not correctly created");

        // Cast a vote
        proposals.castVote(ballotID, Vote.INCREASE);

        // Try to finalize the ballot immediately (should not be possible, hence expecting a revert)
        vm.expectRevert("The ballot is not yet able to be finalized");
        dao.finalizeBallot(ballotID);

        vm.warp( block.timestamp + 11 days );

		// No quorum yet
        vm.expectRevert("The ballot is not yet able to be finalized");
        dao.finalizeBallot(ballotID);

		// Should work
        staking.stakeSALT(5000000 ether);
        proposals.castVote(ballotID, Vote.INCREASE);

        dao.finalizeBallot(ballotID);

		// Shouldn't work
        vm.expectRevert("The ballot is not yet able to be finalized");
        dao.finalizeBallot(ballotID);
        }


	// A unit test which checks that you can still see ballots after they are finalized
	function testFinalizedBallotsStillVisible() public {
        vm.startPrank(alice);
        staking.stakeSALT(5000000 ether);

        // Propose a parameter ballot
        proposals.proposeParameterBallot(0, "description");

        // Get the ballot ID
        uint256 ballotID = 1;
        vm.warp( block.timestamp + 11 days );

	    proposals.castVote(ballotID, Vote.INCREASE);

        dao.finalizeBallot(ballotID);

        Ballot memory ballot = proposals.ballotForID(ballotID);
        assertEq( ballot.ballotID, ballotID );
        }


	// A unit test to test that withdrawArbitrageProfits works as expected and sends the correct amount to the Upkeep contract
	function testWithdrawArbitrageProfits() public {
        // Initial setup
        uint256 initialBalance = weth.balanceOf(address(exchangeConfig.upkeep()));

		vm.prank(address(DEPLOYER));
		weth.transfer(address(dao), 1000 ether);

        vm.startPrank(address(dao));
        weth.approve(address(pools), 1000 ether);
        pools.deposit(weth, 1000 ether);

        uint256 depositedWETH = pools.depositedBalance(address(dao), weth);
        assertEq( depositedWETH, 1000 ether, "DAO should have 1000 ether deposited" );
        vm.stopPrank();

        // Call the function
        vm.prank(address(upkeep));
        dao.withdrawArbitrageProfits(weth);

        uint256 expectedBalance = initialBalance + depositedWETH;

        // Check the result
        uint256 finalBalance = weth.balanceOf(address(exchangeConfig.upkeep()));
        assertEq(finalBalance, expectedBalance, "The final balance is not correct");
    }


	// A unit test to validate that formPOL works correctly and changes balances as expected
	function testFormPOL() public {

		assertEq( pools.getUserLiquidity(address(dao), salt, usds), 0 );

		uint256 saltAmount = 10 ether;
        uint256 usdsAmount = 5 ether;

        uint256 initialDaoSaltBalance = salt.balanceOf(address(dao));
        uint256 initialDaoUsdsBalance = usds.balanceOf(address(dao));

		assertEq( initialDaoSaltBalance, 0 );
		assertEq( initialDaoUsdsBalance, 0 );

		vm.startPrank(DEPLOYER);
        salt.transfer(address(dao), saltAmount);
        usds.transfer(address(dao), usdsAmount);
        vm.stopPrank();

        vm.expectRevert( "DAO.formPOL is only callable from the Upkeep contract" );
        dao.formPOL(liquidity, salt, usds);

        vm.prank(address(upkeep));
        dao.formPOL(liquidity, salt, usds);

        assertEq(salt.balanceOf(address(dao)), 0, "DAO SALT balance incorrect after formPOL");
        assertEq(usds.balanceOf(address(dao)), 0, "DAO USDS balance incorrect after formPOL");

		(bytes32 poolID,) = PoolUtils._poolID(salt,usds);
		assertTrue( liquidity.userShareForPool(address(dao), poolID) > 0 );
    }


	// A unit test to validate that unauthorized users cannot call functions restricted to the Upkeep contract
	function testUnauthorizedAccessToUpkeepFunctions() public
    	{
    	vm.startPrank(bob);

    	vm.expectRevert("DAO.withdrawArbitrageProfits is only callable from the Upkeep contract");
    	dao.withdrawArbitrageProfits( weth );

    	vm.expectRevert("DAO.formPOL is only callable from the Upkeep contract");
    	dao.formPOL(liquidity, salt, usds);

    	vm.expectRevert("DAO.sendSaltToSaltRewards is only callable from the Upkeep contract");
    	dao.sendSaltToSaltRewards( salt, saltRewards, 1000 ether );

    	vm.expectRevert("DAO.processRewardsFromPOL is only callable from the Upkeep contract");
    	dao.processRewardsFromPOL( liquidity, salt, usds );

    	vm.stopPrank();
    	}



    // A unit test to check if a non-excluded country, countryIsExcluded returns false
    function testCountryIsExcluded() public
        {
        string memory nonExcludedCountry = "Canada";

        bool result = dao.countryIsExcluded(nonExcludedCountry);

        assertEq(result, false, "The country should not be excluded");
        }


    // A unit test to validate that SALT tokens are burned as expected by the processRewardsFromPOL function
    function testProcessRewardsFromPOL() public {

		// DAO needs to form some SALT/USDS liquidity to receive some rewards
		vm.prank(address(daoVestingWallet));
		salt.transfer(address(dao), 1000 ether);

		vm.prank(address(collateral));
		usds.mintTo(address(dao), 1000 ether);

		assertEq( salt.balanceOf(address(dao)), 1000 ether );
		assertEq( usds.balanceOf(address(dao)), 1000 ether );

		// Have the DAO form SALT/USDS liquidity with the SALT and USDS that it has
		vm.prank(address(upkeep));
		dao.formPOL(liquidity, salt, usds);

		// Pass time to allow the liquidityRewardsEmitter to emit rewards
    	vm.warp( block.timestamp + 1 days );

		bytes32[] memory poolIDs = new bytes32[](1);
		(poolIDs[0],) = PoolUtils._poolID(salt, weth);

		uint256[] memory pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(poolIDs);
   		upkeep.performUpkeep();
		uint256[] memory pendingRewards2 = liquidityRewardsEmitter.pendingRewardsForPools(poolIDs);

		uint256 distributedRewards = pendingRewards[0] - pendingRewards2[0];

//		console.log( "distributedRewards: ", distributedRewards );
//		console.log( "totalSupply: ", salt.totalSupply() );
//		console.log( "burned: ", salt.totalBurned() );
//		console.log( "liquidity: ", address(liquidity) );
//		console.log( "team: ", salt.balanceOf(teamWallet) );

		assertEq( distributedRewards, 5555555555555555555555 );
		assertEq( salt.balanceOf(teamWallet), 555555555555555555555 );
		assertEq( salt.totalBurned(), 3750000000000000000000 );
   		}


	// A unit test to test that sending SALT to SaltRewards works as expected
	function testSendSALTSaltRewards() public {
        vm.prank(DEPLOYER);

        salt.transfer(address(saltRewards), 10 ether);
        assertEq(salt.balanceOf(address(saltRewards)), 10 ether, "Sending SALT to SaltRewards did not adequately adjust the SaltReward's SALT balance.");

        vm.prank(alice);
        salt.transfer(address(dao), 10 ether);

		vm.prank(address(upkeep));
        dao.sendSaltToSaltRewards(salt, saltRewards, 5 ether);
        assertEq(salt.balanceOf(address(saltRewards)), 15 ether, "DAO sending SALT to SaltRewards did not adequately adjust the SaltRewards's SALT balance.");
    }


    // A unit test to validate the functionality of sufficientBootstrappingRewardsExistForWhitelisting
	function testSufficientBootstrappingRewardsExistForWhitelisting() public {

        // Initial SALT balance of DAO is 0 ether

        // Test when SALT balance in DAO contract is insufficient for whitelisting
        assertEq(dao.sufficientBootstrappingRewardsExistForWhitelisting(), false, "DAO should have insufficient bootstrapping rewards");

		uint256 bootstrappingRewards = daoConfig.bootstrappingRewards();

        vm.prank(DEPLOYER);
        salt.transfer(address(dao), bootstrappingRewards * 2 - 1);

		// Still insufficient
        assertEq(dao.sufficientBootstrappingRewardsExistForWhitelisting(), false, "DAO should still have insufficient bootstrapping rewards");

        vm.prank(DEPLOYER);
        salt.transfer(address(dao), 2);

		// Sufficient
        assertEq(dao.sufficientBootstrappingRewardsExistForWhitelisting(), true, "DAO should have sufficient bootstrapping rewards");
    }


	// A unit test to validate that geo exclusion succeeds
	function testGeoExclusionYes1() public
    	{
    	vm.startPrank(address(bootstrapBallot));

		uint256[] memory dummyYes = new uint256[](5);
		uint256[] memory dummyNo = new uint256[](5);

		dummyYes[0] = 2;
		dummyNo[0] = 1;

		assertFalse( dao.countryIsExcluded( "USA") );

    	dao.initialGeoExclusion(dummyYes, dummyNo);

		assertTrue( dao.countryIsExcluded( "USA") );
    	}


	// A unit test to validate that geo exclusion fails
	function testGeoExclusionNo1() public
    	{
    	vm.startPrank(address(bootstrapBallot));

		uint256[] memory dummyYes = new uint256[](5);
		uint256[] memory dummyNo = new uint256[](5);

		dummyYes[0] = 1;
		dummyNo[0] = 2;

		assertFalse( dao.countryIsExcluded( "USA") );

    	dao.initialGeoExclusion(dummyYes, dummyNo);

		assertFalse( dao.countryIsExcluded( "USA") );
    	}





	// A unit test to validate that geo exclusion succeeds
	function testGeoExclusionYes2() public
    	{
    	vm.startPrank(address(bootstrapBallot));

		uint256[] memory dummyYes = new uint256[](5);
		uint256[] memory dummyNo = new uint256[](5);

		dummyYes[1] = 2;
		dummyNo[1] = 1;

		assertFalse( dao.countryIsExcluded( "CAN") );

    	dao.initialGeoExclusion(dummyYes, dummyNo);

		assertTrue( dao.countryIsExcluded( "CAN") );
    	}


	// A unit test to validate that geo exclusion fails
	function testGeoExclusionNo2() public
    	{
    	vm.startPrank(address(bootstrapBallot));

		uint256[] memory dummyYes = new uint256[](5);
		uint256[] memory dummyNo = new uint256[](5);

		dummyYes[1] = 1;
		dummyNo[1] = 2;

		assertFalse( dao.countryIsExcluded( "CAN") );

    	dao.initialGeoExclusion(dummyYes, dummyNo);

		assertFalse( dao.countryIsExcluded( "CAN") );
    	}





	// A unit test to validate that geo exclusion succeeds
	function testGeoExclusionYes3() public
    	{
    	vm.startPrank(address(bootstrapBallot));

		uint256[] memory dummyYes = new uint256[](5);
		uint256[] memory dummyNo = new uint256[](5);

		dummyYes[2] = 2;
		dummyNo[2] = 1;

		assertFalse( dao.countryIsExcluded( "GBR") );

    	dao.initialGeoExclusion(dummyYes, dummyNo);

		assertTrue( dao.countryIsExcluded( "GBR") );
    	}


	// A unit test to validate that geo exclusion fails
	function testGeoExclusionNo3() public
    	{
    	vm.startPrank(address(bootstrapBallot));

		uint256[] memory dummyYes = new uint256[](5);
		uint256[] memory dummyNo = new uint256[](5);

		dummyYes[2] = 1;
		dummyNo[2] = 2;

		assertFalse( dao.countryIsExcluded( "GBR") );

    	dao.initialGeoExclusion(dummyYes, dummyNo);

		assertFalse( dao.countryIsExcluded( "GBR") );
    	}




	// A unit test to validate that geo exclusion succeeds
    	function testGeoExclusionYes4() public
        	{
        	vm.startPrank(address(bootstrapBallot));

    		uint256[] memory dummyYes = new uint256[](5);
    		uint256[] memory dummyNo = new uint256[](5);

    		dummyYes[3] = 2;
    		dummyNo[3] = 1;

    		assertFalse( dao.countryIsExcluded( "CHN") );
    		assertFalse( dao.countryIsExcluded( "CUB") );
    		assertFalse( dao.countryIsExcluded( "IND") );
    		assertFalse( dao.countryIsExcluded( "PAK") );
    		assertFalse( dao.countryIsExcluded( "RUS") );

        	dao.initialGeoExclusion(dummyYes, dummyNo);

    		assertTrue( dao.countryIsExcluded( "CHN") );
    		assertTrue( dao.countryIsExcluded( "CUB") );
    		assertTrue( dao.countryIsExcluded( "IND") );
    		assertTrue( dao.countryIsExcluded( "PAK") );
    		assertTrue( dao.countryIsExcluded( "RUS") );
        	}


    	// A unit test to validate that geo exclusion fails
    	function testGeoExclusionNo4() public
        	{
        	vm.startPrank(address(bootstrapBallot));

    		uint256[] memory dummyYes = new uint256[](5);
    		uint256[] memory dummyNo = new uint256[](5);

    		dummyYes[3] = 1;
    		dummyNo[3] = 2;

    		assertFalse( dao.countryIsExcluded( "CHN") );
    		assertFalse( dao.countryIsExcluded( "CUB") );
    		assertFalse( dao.countryIsExcluded( "IND") );
    		assertFalse( dao.countryIsExcluded( "PAK") );
    		assertFalse( dao.countryIsExcluded( "RUS") );

        	dao.initialGeoExclusion(dummyYes, dummyNo);

    		assertFalse( dao.countryIsExcluded( "CHN") );
    		assertFalse( dao.countryIsExcluded( "CUB") );
    		assertFalse( dao.countryIsExcluded( "IND") );
    		assertFalse( dao.countryIsExcluded( "PAK") );
    		assertFalse( dao.countryIsExcluded( "RUS") );
        	}


// A unit test to validate that geo exclusion succeeds
	function testGeoExclusionYes5() public
    	{
    	vm.startPrank(address(bootstrapBallot));

		uint256[] memory dummyYes = new uint256[](5);
		uint256[] memory dummyNo = new uint256[](5);

		dummyYes[4] = 2;
		dummyNo[4] = 1;

		assertFalse( dao.countryIsExcluded( "AFG") );
		assertFalse( dao.countryIsExcluded( "IRN") );
		assertFalse( dao.countryIsExcluded( "PRK") );
		assertFalse( dao.countryIsExcluded( "SYR") );
		assertFalse( dao.countryIsExcluded( "VEN") );

    	dao.initialGeoExclusion(dummyYes, dummyNo);

		assertTrue( dao.countryIsExcluded( "AFG") );
		assertTrue( dao.countryIsExcluded( "IRN") );
		assertTrue( dao.countryIsExcluded( "PRK") );
		assertTrue( dao.countryIsExcluded( "SYR") );
		assertTrue( dao.countryIsExcluded( "VEN") );
    	}


	// A unit test to validate that geo exclusion fails
	function testGeoExclusionNo5() public
    	{
    	vm.startPrank(address(bootstrapBallot));

		uint256[] memory dummyYes = new uint256[](5);
		uint256[] memory dummyNo = new uint256[](5);

		dummyYes[4] = 1;
		dummyNo[4] = 2;

		assertFalse( dao.countryIsExcluded( "AFG") );
		assertFalse( dao.countryIsExcluded( "IRN") );
		assertFalse( dao.countryIsExcluded( "PRK") );
		assertFalse( dao.countryIsExcluded( "SYR") );
		assertFalse( dao.countryIsExcluded( "VEN") );

    	dao.initialGeoExclusion(dummyYes, dummyNo);

		assertFalse( dao.countryIsExcluded( "AFG") );
		assertFalse( dao.countryIsExcluded( "IRN") );
		assertFalse( dao.countryIsExcluded( "PRK") );
		assertFalse( dao.countryIsExcluded( "SYR") );
		assertFalse( dao.countryIsExcluded( "VEN") );
    	}



    }

