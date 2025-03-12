// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../dev/Deployment.sol";


contract TestProposals is Deployment
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

		vm.prank(address(initialDistribution));
		salt.transfer(DEPLOYER, 100000000 ether);

		vm.startPrank( DEPLOYER );
		salt.transfer( alice, 10000000 ether );
		salt.transfer( DEPLOYER, 90000000 ether );
		vm.stopPrank();

		// Mint some USDS to the DEPLOYER and alice
		vm.startPrank( address(collateral) );
		usds.mintTo( DEPLOYER, 2000000 ether );
		usds.mintTo( alice, 1000000 ether );
		vm.stopPrank();
		}


    function setUp() public
    	{
    	vm.startPrank( DEPLOYER );
    	usds.approve( address(proposals), type(uint256).max );
    	salt.approve( address(staking), type(uint256).max );
    	vm.stopPrank();

    	vm.startPrank( alice );
    	usds.approve( address(proposals), type(uint256).max );
    	salt.approve( address(staking), type(uint256).max );
    	vm.stopPrank();

    	vm.startPrank( bob );
    	usds.approve( address(proposals), type(uint256).max );
    	salt.approve( address(staking), type(uint256).max );
    	vm.stopPrank();
    	}


	// A unit test that checks the proposeParameterBallot function with different input combinations. Verify that a new proposal gets created and that all necessary state changes occur.
	function testProposeParameterBallot() public {
		vm.startPrank( DEPLOYER );

        // Get initial state before proposing the ballot
        uint256 initialNextBallotId = proposals.nextBallotID();

        // Define a ballotName
        string memory ballotName = "parameter:1";

        // Ensure ballot with ballotName doesn't exist before proposing
        assertEq(proposals.openBallotsByName(ballotName), 0);

        // Call proposeParameterBallot
        proposals.proposeParameterBallot(1, "description" );

        // Check that the next ballot ID has been incremented
        assertEq(proposals.nextBallotID(), initialNextBallotId + 1);

        // Check that the ballot with ballotName now exists
        assert(proposals.openBallotsByName(ballotName) == 1);

        // Check that the proposed ballot is in the correct state
        uint256 ballotID = proposals.openBallotsByName(ballotName);
        Ballot memory ballot = proposals.ballotForID(ballotID);

        // Check that the proposed ballot parameters are correct
        assertTrue(ballot.ballotIsLive);
        assertEq(uint256(ballot.ballotType), uint256(BallotType.PARAMETER));
        assertEq(ballot.ballotName, ballotName);
        assertEq(ballot.address1, address(0));
        assertEq(ballot.number1, 1);
        assertEq(ballot.string1, "");
        assertEq(ballot.description, "description");
        assertEq(ballot.ballotMinimumEndTime, block.timestamp + daoConfig.ballotDuration());
    }


	// A unit test that tries to propose the same parameter ballot multiple times. This should test the requirement check in the _possiblyCreateProposal function.
	function testProposeSameBallotNameMultipleTimesAndForOpenBallot() public {
        // Using address alice for initial proposal
        vm.startPrank(DEPLOYER);

        // Proposing a ParameterBallot for the first time
        proposals.proposeParameterBallot(1, "description" );

        // Trying to propose the same ballot name again should fail
        vm.expectRevert("Cannot create a proposal similar to a ballot that is still open" );
        proposals.proposeParameterBallot(1, "description" );
        vm.stopPrank();

		// Make sure another user can't recreate the same ballot either
		vm.prank(alice);
        vm.expectRevert("Cannot create a proposal similar to a ballot that is still open" );
        proposals.proposeParameterBallot(1, "description" );

		vm.prank(alice);
    	staking.stakeSALT( 1000000 ether ); // Default minimum quorum is 1 million

		uint256 ballotID = 1;
		assertFalse( proposals.canFinalizeBallot(ballotID) );

        // Increasing block time by ballotDuration to allow for proposal finalization
        vm.warp(block.timestamp + daoConfig.ballotDuration());
		assertFalse( proposals.canFinalizeBallot(ballotID) );

		// Have alice cast some votes
		vm.prank( alice );
		proposals.castVote( ballotID, Vote.INCREASE );

		// Ballot shoudl be able to be finalized now
		assertTrue( proposals.canFinalizeBallot(ballotID) );

        // Finalize the ballot
        vm.prank( address(dao) );
        proposals.markBallotAsFinalized(ballotID);

        // Trying to propose for the already open (but finalized) ballot should succeed
        vm.prank( DEPLOYER );
        proposals.proposeParameterBallot(1, "description" );
    }


	// A unit test that verifies the proposeCountryInclusion and proposeCountryExclusion functions with different country names. Check that the appropriate country name gets stored in the proposal.
	function testProposeCountryInclusionExclusion() public {
        string memory inclusionBallotName = "include:us";
        string memory exclusionBallotName = "exclude:ca";
        string memory countryName1 = "us";
        string memory countryName2 = "ca";
        uint256 inclusionProposalCost = 5 * daoConfig.baseProposalCost();
        uint256 exclusionProposalCost = 5 * daoConfig.baseProposalCost();

        // Assert initial balances
        assertEq(usds.balanceOf(alice), 1000000 ether);
        assertEq(usds.balanceOf(bob), 0 ether);

       // Assert reverts if not enough balance
        vm.warp(block.timestamp + 10 days); // warp forward in time
        vm.startPrank(bob);
        vm.expectRevert( "ERC20: transfer amount exceeds balance" );
        proposals.proposeCountryInclusion(countryName1, "description" );
        vm.stopPrank();

        // Propose country inclusion
        vm.prank(alice);
        proposals.proposeCountryInclusion(countryName1, "description" );
        uint256 inclusionProposalId = proposals.openBallotsByName(inclusionBallotName);
        assertEq( inclusionProposalId, 1 );

        // Check proposal details
        Ballot memory inclusionProposal = proposals.ballotForID(inclusionProposalId);
        assertTrue(inclusionProposal.ballotIsLive);
        assertEq(uint256(inclusionProposal.ballotType), uint256(BallotType.INCLUDE_COUNTRY));
        assertEq(inclusionProposal.ballotName, inclusionBallotName);
        assertEq(inclusionProposal.string1, countryName1);

        // Assert Alice balance after proposing country inclusion
        assertEq(usds.balanceOf(alice), 1000000 ether - inclusionProposalCost);

        // Propose country exclusion
        vm.prank(alice);
        proposals.proposeCountryExclusion(countryName2, "description" );
        uint256 exclusionProposalId = proposals.openBallotsByName(exclusionBallotName);

        // Check proposal details
        Ballot memory exclusionProposal = proposals.ballotForID(exclusionProposalId);
        assertTrue(exclusionProposal.ballotIsLive);
        assertEq(uint256(exclusionProposal.ballotType), uint256(BallotType.EXCLUDE_COUNTRY));
        assertEq(exclusionProposal.ballotName, exclusionBallotName);
        assertEq(exclusionProposal.string1, countryName2);

        // Assert Alice balance after proposing country exclusion
        assertEq(usds.balanceOf(alice), 1000000 ether - inclusionProposalCost - exclusionProposalCost);
    }


	// A unit test that verifies the proposeSetContractAddress function. Test this function with different address values and verify that the new address gets stored in the proposal.
	function testProposeSetContractAddress() public {
        vm.startPrank(alice);

        // Check initial state
        uint256 initialProposalCount = proposals.nextBallotID() - 1;

        // Try to set an invalid address and expect a revert
        address newAddress = address(0);
        vm.expectRevert("Proposed address cannot be address(0)");
        proposals.proposeSetContractAddress( "contractName", newAddress, "description" );

        // Use a valid address
        newAddress = address(0x1111111111111111111111111111111111111112);
        proposals.proposeSetContractAddress("contractName", newAddress, "description" );

       vm.expectRevert("Cannot create a proposal similar to a ballot that is still open");
        proposals.proposeSetContractAddress("contractName", newAddress, "description" );

        // Check if a new proposal is created
        uint256 newProposalCount = proposals.nextBallotID() - 1;
        assertEq(newProposalCount, initialProposalCount + 1, "New proposal was not created");

        // Get the new proposal
        Ballot memory ballot = proposals.ballotForID(newProposalCount);

        // Check if the new proposal has the right new address
        assertEq(ballot.address1, newAddress, "New proposal has incorrect address");

        vm.stopPrank();
    }


	// A unit test that verifies the proposeWebsiteUpdate function. Check that the correct website URL gets stored in the proposal.
	function testProposeWebsiteUpdate() public {
        // Set up
        vm.startPrank(alice); // Switch to Alice for the test

        // Save off the current proposals.nextBallotID() before the proposeWebsiteUpdate call
        uint256 preNextBallotID = proposals.nextBallotID();

        // Create a ballot with the new website URL
        string memory newWebsiteURL = "https://www.newwebsite.com";
        proposals.proposeWebsiteUpdate(newWebsiteURL, "description" );

        // Verify the proposals.nextBallotID() has been incremented
        uint256 postNextBallotID = proposals.nextBallotID();
        assertEq(postNextBallotID, preNextBallotID + 1, "proposals.nextBallotID() should have incremented by 1");

		string memory ballotName = "setURL:https://www.newwebsite.com";

        // Verify the ballot ID associated with the ballotName
        uint256 ballotID = proposals.openBallotsByName(ballotName);
        assertEq(ballotID, preNextBallotID, "The ballot ID should match the preNextBallotID");

        // Retrieve the new ballot
        Ballot memory ballot = proposals.ballotForID(ballotID);

        // Verify the ballot details
        assertEq(uint256(ballot.ballotType), uint256(BallotType.SET_WEBSITE_URL), "Ballot type is incorrect");
        assertEq(ballot.string1, newWebsiteURL, "Website URL is incorrect");
        assertEq(ballot.ballotName, ballotName, "Ballot name is incorrect");
        assertTrue(ballot.ballotIsLive, "The ballot should be live");
    }


	// A unit test that verifies the proposeCallContract function. Try this function with different input values and verify the correct values get stored in the proposal.
	function testProposeCallContract() public {
        address contractAddress = address(0xBBBB);
        uint256 number = 12345;

        // Simulate a call from Alice
        vm.startPrank(alice);

		string memory ballotName = "callContract:0x000000000000000000000000000000000000bbbb";

        // Check initial state before proposal
        assertEq(proposals.openBallotsByName(ballotName), 0, "Ballot ID should be 0 before proposal");

        // Make the proposal
        proposals.proposeCallContract(contractAddress, number, "description" );

        // Check the proposal was made
        uint256 ballotID = proposals.openBallotsByName(ballotName);
        assertEq(ballotID, 1);

        // Check the proposal values
        Ballot memory ballot = proposals.ballotForID(ballotID);
        assertEq(ballot.ballotName, ballotName, "Ballot name should match");
        assertEq(uint256(ballot.ballotType), uint256(BallotType.CALL_CONTRACT), "Ballot type should be CALL_CONTRACT");
        assertEq(ballot.address1, contractAddress, "Contract address should match proposal");
        assertEq(ballot.number1, number, "Number should match proposal");
    }


	// A unit test for the _markBallotAsFinalized function that confirms if a ballot's status is updated correctly after finalization.
	function testMarkBallotAsFinalized() public {
        string memory ballotName = "parameter:2";

        vm.startPrank(DEPLOYER);
		proposals.proposeParameterBallot(2, "description" );

        uint256 ballotID = proposals.openBallotsByName(ballotName);
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, true);
		vm.stopPrank();

        // Act
        vm.prank( address(dao) );
        proposals.markBallotAsFinalized(ballotID);

        // Assert
        assertEq(proposals.ballotForID(ballotID).ballotIsLive, false);
        assertEq(proposals.openBallotsByName(ballotName), 0, "Ballot should have been cleared");
    }


	// A unit test that checks if the castVote function appropriately updates the votesCastForBallot mapping and proposals.totalVotesCastForBallot for the ballot. This should also cover situations where a user tries to vote without voting power and a situation where a user changes their vote.
	function testCastVote() public {
        string memory ballotName = "parameter:2";

        vm.prank(DEPLOYER);
		proposals.proposeParameterBallot(2, "description" );
		uint256 ballotID = proposals.openBallotsByName(ballotName);

        Vote userVote = Vote.YES;

        // User has voting power
        vm.startPrank(alice);
        uint256 votingPower = staking.userShareForPool(alice, PoolUtils.STAKED_SALT);
        assertEq( votingPower, 0, "Alice should not have any initial xSALT" );

        // Vote.YES is invalid for a Parameter type ballot
        vm.expectRevert( "Invalid VoteType for Parameter Ballot" );
		proposals.castVote(ballotID, userVote);

		// Alice has not staked SALT yet
        vm.expectRevert( "Staked SALT required to vote" );
        userVote = Vote.INCREASE;
		proposals.castVote(ballotID, userVote);

		// Stake some salt and vote again
		votingPower = 1000 ether;
		staking.stakeSALT( votingPower );
        proposals.castVote(ballotID, userVote);

		UserVote memory lastVote = proposals.lastUserVoteForBallot(ballotID, alice);

		assertEq(uint256(lastVote.vote), uint256(userVote), "User vote does not match");
		assertEq(lastVote.votingPower, votingPower, "Voting power is incorrect");

		assertEq(proposals.totalVotesCastForBallot(ballotID), votingPower, "Total votes for ballot is incorrect");
		assertEq(proposals.votesCastForBallot(ballotID, userVote), votingPower, "Votes cast for ballot is incorrect");

        // User changes their vote
        uint256 addedUserVotingPower = 200 ether;
		staking.stakeSALT( addedUserVotingPower );

        Vote newUserVote = Vote.DECREASE;
        proposals.castVote(ballotID, newUserVote);

        UserVote memory newLastVote = proposals.lastUserVoteForBallot(ballotID, alice);
        assertEq(uint256(newLastVote.vote), uint256(newUserVote), "New user vote does not match");
        assertEq(newLastVote.votingPower, votingPower + addedUserVotingPower, "New voting power is incorrect");

        assertEq(proposals.totalVotesCastForBallot(ballotID), votingPower + addedUserVotingPower, "Total votes for ballot is incorrect after vote change");
        assertEq(proposals.votesCastForBallot(ballotID, newUserVote), votingPower + addedUserVotingPower, "Votes cast for ballot is incorrect after vote change");
        assertEq(proposals.votesCastForBallot(ballotID, userVote), 0, "The old vote should have no votes cast");
    }


	// A unit test that checks if canFinalizeBallot function returns the correct boolean value under various conditions, including situations where a ballot can be finalized and where it cannot due to ballot not being live, minimum end time not being reached, or not meeting the required quorum.
	function testCanFinalizeBallot() public {
        string memory ballotName = "parameter:2";

		uint256 initialStake = 10000000 ether;

        vm.startPrank(alice);
        proposals.proposeParameterBallot(2, "description" );
        uint256 ballotID = proposals.openBallotsByName(ballotName);

		// Early ballot, no quorum
        bool canFinalizeBallotStillEarly = proposals.canFinalizeBallot(ballotID);

		// Ballot reached end time, no quorum
        vm.warp(block.timestamp + daoConfig.ballotDuration() + 1); // ballot end time reached

		vm.expectRevert( "SALT staked cannot be zero to determine quorum" );
		proposals.canFinalizeBallot(ballotID);
		vm.stopPrank();

		vm.prank(DEPLOYER);
		staking.stakeSALT( initialStake );

        bool canFinalizeBallotPastEndtime = proposals.canFinalizeBallot(ballotID);


        // Almost reach quorum
        vm.prank(alice);
        staking.stakeSALT(1110111 ether);

		// Default user has no access to the exchange, but can still vote
		vm.prank(DEPLOYER);
		salt.transfer(address(this), 1000 ether );

		salt.approve( address(staking), type(uint256).max);
		staking.stakeSALT( 1000 ether );
        proposals.castVote(ballotID, Vote.INCREASE);

        vm.startPrank(alice);
        proposals.castVote(ballotID, Vote.INCREASE);

        bool canFinalizeBallotAlmostAtQuorum = proposals.canFinalizeBallot(ballotID);

		// Reach quorum
        staking.stakeSALT(1 ether);

        // Recast vote to include new stake
        proposals.castVote(ballotID, Vote.DECREASE);

        bool canFinalizeBallotAtQuorum = proposals.canFinalizeBallot(ballotID);

        // Assert
        assertEq(canFinalizeBallotStillEarly, false, "Should not be able to finalize live ballot");
        assertEq(canFinalizeBallotPastEndtime, false, "Should not be able to finalize non-quorum ballot");
        assertEq(canFinalizeBallotAlmostAtQuorum, false, "Should not be able to finalize ballot if quorum is just beyond the minimum ");
        assertEq(canFinalizeBallotAtQuorum, true, "Should be able to finalize ballot if quorum is reached and past the minimum end time");
    }


	// A unit test for the requiredQuorumForBallotType function that confirms it returns the correct quorum requirement for each type of ballot.
	function testRequiredQuorumForBallotType() public {

		vm.startPrank(DEPLOYER);

		// 5 million staked. Default 10% will be 500k which does not meet the 1% of total supply minimum quorum.
		// So 1 million (1% of the totalSupply) will be used as the quorum
		staking.stakeSALT( 5000000 ether );
        assertEq(proposals.requiredQuorumForBallotType(BallotType.PARAMETER), 1000000 ether, "Not using the minimum 1% of totalSupply for quorum" );

		// 10 million total staked. Default 10% will be 1 million which meets the 1% of total supply minimum quorum.
		staking.stakeSALT( 5000000 ether );

        uint256 stakedSALT = staking.totalSharesForPool(PoolUtils.STAKED_SALT);
        uint256 baseBallotQuorumPercentTimes1000 = daoConfig.baseBallotQuorumPercentTimes1000();

        // Check quorum for Parameter ballot type
        uint256 expectedQuorum = (1 * stakedSALT * baseBallotQuorumPercentTimes1000) / (1000 * 100);
        assertEq(proposals.requiredQuorumForBallotType(BallotType.PARAMETER), expectedQuorum);

        // Check quorum for WhitelistToken ballot type
        expectedQuorum = (2 * stakedSALT * baseBallotQuorumPercentTimes1000) / (1000 * 100);
        assertEq(proposals.requiredQuorumForBallotType(BallotType.WHITELIST_TOKEN), expectedQuorum);

        // Check quorum for UnwhitelistToken ballot type
        expectedQuorum = (2 * stakedSALT * baseBallotQuorumPercentTimes1000) / (1000 * 100);
        assertEq(proposals.requiredQuorumForBallotType(BallotType.UNWHITELIST_TOKEN), expectedQuorum);

        // Check quorum for SendSalt ballot type
        expectedQuorum = (3 * stakedSALT * baseBallotQuorumPercentTimes1000) / (1000 * 100);
        assertEq(proposals.requiredQuorumForBallotType(BallotType.SEND_SALT), expectedQuorum);

        // Check quorum for CallContract ballot type
        expectedQuorum = (3 * stakedSALT * baseBallotQuorumPercentTimes1000) / (1000 * 100);
        assertEq(proposals.requiredQuorumForBallotType(BallotType.CALL_CONTRACT), expectedQuorum);

        // Check quorum for IncludeCountry ballot type
        expectedQuorum = (3 * stakedSALT * baseBallotQuorumPercentTimes1000) / (1000 * 100);
        assertEq(proposals.requiredQuorumForBallotType(BallotType.INCLUDE_COUNTRY), expectedQuorum);

        // Check quorum for ExcludeCountry ballot type
        expectedQuorum = (3 * stakedSALT * baseBallotQuorumPercentTimes1000) / (1000 * 100);
        assertEq(proposals.requiredQuorumForBallotType(BallotType.EXCLUDE_COUNTRY), expectedQuorum);

        // Check quorum for SetContract ballot type
        expectedQuorum = (3 * stakedSALT * baseBallotQuorumPercentTimes1000) / (1000 * 100);
        assertEq(proposals.requiredQuorumForBallotType(BallotType.SET_CONTRACT), expectedQuorum);

        // Check quorum for SetWebsiteUrl ballot type
        expectedQuorum = (3 * stakedSALT * baseBallotQuorumPercentTimes1000) / (1000 * 100);
        assertEq(proposals.requiredQuorumForBallotType(BallotType.SET_WEBSITE_URL), expectedQuorum);
    }


	// A unit test for the proposals.totalVotesCastForBallot function that confirms it returns the correct total votes for a given ballot.
   // A unit test that verifies if the totalVotesCastForBallot function correctly calculates the sum of all types of votes for a particular ballot.
	function testTotalVotesCastForBallot() public
        {
        string memory ballotName = "parameter:2";

		vm.startPrank(alice);
        proposals.proposeParameterBallot(2, "description" );

		uint256 ballotID = proposals.openBallotsByName(ballotName);
		staking.stakeSALT( 1000 ether );
        proposals.castVote(ballotID, Vote.INCREASE);

		salt.transfer( DEPLOYER, 2000 ether );
        vm.stopPrank();

        vm.startPrank( DEPLOYER );
		staking.stakeSALT( 2000 ether );
        proposals.castVote(ballotID, Vote.INCREASE);
        vm.stopPrank();

        assertEq(proposals.ballotForID(ballotID).ballotIsLive, true);
        assertEq(proposals.totalVotesCastForBallot(ballotID), 3000 ether);

        vm.startPrank( alice );
		staking.stakeSALT( 1000 ether );
        proposals.castVote(ballotID, Vote.DECREASE);
        vm.stopPrank();

        assertEq(proposals.totalVotesCastForBallot(ballotID), 4000 ether);
        }


	// A unit test that verifies the numberOfOpenBallotsForTokenWhitelisting function and the tokenWhitelistingBallotWithTheMostVotes function. This should include situations where there are multiple open ballots for token whitelisting, and should correctly identify the ballot with the most votes.
	function testTokenWhitelistingBallots() public {

		IERC20 wbtc = exchangeConfig.wbtc();
		IERC20 weth = exchangeConfig.weth();

//		console.log( "tokenHasBeenWhitelisted(): ", proposals.tokenHasBeenWhitelisted(wbtc) );

		vm.prank(address(dao));
		poolsConfig.whitelistPool(pools,  wbtc, weth );

        vm.startPrank(alice);
        vm.expectRevert( "The token has already been whitelisted" );
        proposals.proposeTokenWhitelisting( wbtc, "https://tokenIconURL", "This is a test token");
		vm.stopPrank();

		vm.prank(address(dao));
		poolsConfig.unwhitelistPool(pools, wbtc, weth );

        // Prepare a new whitelisting ballot
		uint256 initialStake = 10000000 ether;
		vm.prank(DEPLOYER);
		staking.stakeSALT( initialStake );

        vm.startPrank(alice);
        IERC20 testToken = new TestERC20("TEST", 18);
        staking.stakeSALT( 2222222 ether ); // less than minimum quorum for whitelisting (which is default 10% of the amount of staked SALT)
        proposals.proposeTokenWhitelisting(testToken, "https://tokenIconURL", "This is a test token");

		uint256 ballotID = 1;

        // Assert that the number of open ballots for token whitelisting has increased
        assertEq(proposals.numberOfOpenBallotsForTokenWhitelisting(), 1, "The number of open ballots for token whitelisting did not increase after a proposal");
        proposals.castVote(ballotID, Vote.YES);

        assertEq( proposals.totalVotesCastForBallot(ballotID), 2222222 ether, "Vote total is not what is expected" );

//		console.log( "QUORUM: ", requiredQuorumForBallotType( BallotType.WHITELIST_TOKEN ) );
//        console.log( "VOTES: ", proposals.totalVotesCastForBallot(ballotID) );
//
		// Shouldn't have enough votes for quorum yet
        assertEq(proposals.tokenWhitelistingBallotWithTheMostVotes(), 0, "The ballot shouldn't have enough votes for quorum yet");
		vm.stopPrank();

		// Have alice cast more votes for YES
		vm.startPrank(alice);
        staking.stakeSALT( 300000 ether );
        proposals.castVote(ballotID, Vote.YES);

        // The ballot should now be whitelistable
        assertEq(proposals.tokenWhitelistingBallotWithTheMostVotes(), ballotID, "Ballot should be whitelistable");

		// 10 million no votes will bring ballot to quorum, but no votes will now be more than yes votes
		vm.startPrank( DEPLOYER );
        proposals.castVote(ballotID, Vote.NO);
        assertEq(proposals.tokenWhitelistingBallotWithTheMostVotes(), 0, "NO > YES should mean no whitelisted ballot");


        // Create a second whitelisting ballot
        IERC20 testToken2 = new TestERC20("TEST", 18);
        proposals.proposeTokenWhitelisting(testToken2, "https://tokenIconURL", "This is a test token");
        assertEq(proposals.numberOfOpenBallotsForTokenWhitelisting(), 2, "The number of open ballots for token whitelisting did not increase after a second proposal");

		uint256 ballotID2 = 2;

		vm.startPrank( DEPLOYER );
        proposals.castVote(ballotID2, Vote.NO);
        proposals.castVote(ballotID2, Vote.YES);

//        console.log( "max id: ", proposals.tokenWhitelistingBallotWithTheMostVotes() );

        assertEq(proposals.tokenWhitelistingBallotWithTheMostVotes(), ballotID2, "The ballot with the most votes was not updated correctly after a vote");
    }



	// A unit test that verifies the proposeSendSALT function, checking if the proposal can be created, and ensuring that they can't send more than 5% of the existing balance.
	function testProposeSendSALT() public {

		uint256 daoInitialSaltBalance = 1000000 ether;

		vm.startPrank( DEPLOYER );
		salt.transfer( address(dao), daoInitialSaltBalance );
		vm.stopPrank();

		vm.startPrank( alice );


        // Test proposing to send an amount exceeding the limit
        uint256 excessiveAmount = daoInitialSaltBalance / 19; // > 5% of the initial balance

        vm.expectRevert("Cannot send more than 5% of the existing balance");
        proposals.proposeSendSALT(bob, excessiveAmount, "description" );


        // Test proposing to send an amount within the limit (less than 5% of the balance)
        uint256 validAmount = daoInitialSaltBalance / 21; // <5% of the initial balance
        proposals.proposeSendSALT( bob, validAmount, "description" );

        uint256 validBallotId = 1;
        Ballot memory validBallot = proposals.ballotForID(validBallotId);
        assertEq(validBallot.ballotIsLive, true, "The valid ballot should be live");
        assertEq(validBallot.number1, validAmount, "The proposed amount should be the same as the input amount");


        // Test only one sendSALT proposal being able to be pending at a time
        vm.expectRevert( "Cannot create a proposal similar to a ballot that is still open" );
        proposals.proposeSendSALT( DEPLOYER, validAmount, "description" );
    }


	// A unit test for the proposeTokenWhitelisting function that includes the situation where the maximum number of token whitelisting proposals are already pending.
	function testProposeTokenWhitelistingMaxPending() public {
        vm.startPrank(DEPLOYER);

        string memory tokenIconURL = "http://test.com/token.png";
        string memory tokenDescription = "Test Token for Whitelisting";
        uint256 maxPendingTokensForWhitelisting = daoConfig.maxPendingTokensForWhitelisting();

		IERC20 token;

        // Create the maximum number of token whitelisting proposals
        for(uint256 i = 0; i < maxPendingTokensForWhitelisting; i++)
        	{
        	token = new TestERC20("TEST", 18);

            proposals.proposeTokenWhitelisting(token, tokenIconURL, tokenDescription);
            }

        // Attempt to create another token whitelisting proposal beyond the maximum limit
		token = new TestERC20("TEST", 18);

        vm.expectRevert("The maximum number of token whitelisting proposals are already pending");
        proposals.proposeTokenWhitelisting(token, tokenIconURL, tokenDescription);
    }


	// A unit test that makes sures that none of the initial core tokens can be unwhitelisted
	function testUnwhitelistingCoreTokens() public {
		IERC20 wbtc = exchangeConfig.wbtc();
		IERC20 weth = exchangeConfig.weth();
		IERC20 dai = exchangeConfig.dai();

		vm.startPrank(address(dao));
		poolsConfig.whitelistPool(pools,  wbtc, weth );
		poolsConfig.whitelistPool(pools,  wbtc, dai );
		poolsConfig.whitelistPool(pools,  wbtc, salt );
		poolsConfig.whitelistPool(pools,  wbtc, usds );
		vm.stopPrank();

		vm.startPrank(DEPLOYER);

        vm.expectRevert("Cannot unwhitelist WBTC");
        proposals.proposeTokenUnwhitelisting(wbtc, "test", "test");

        vm.expectRevert("Cannot unwhitelist WETH");
        proposals.proposeTokenUnwhitelisting(weth, "test", "test");

        vm.expectRevert("Cannot unwhitelist DAI");
        proposals.proposeTokenUnwhitelisting(dai, "test", "test");

        vm.expectRevert("Cannot unwhitelist SALT");
        proposals.proposeTokenUnwhitelisting(salt, "test", "test");

        vm.expectRevert("Cannot unwhitelist USDS");
        proposals.proposeTokenUnwhitelisting(usds, "test", "test");
        }


	// A unit test that verifies the proposeTokenUnwhitelisting function. This should include situations where the token is not whitelisted and a situation where the token is whitelisted.
	function testProposeTokenUnwhitelisting() public {

		vm.startPrank( DEPLOYER );

        // Trying to unwhitelist an unwhitelisted token should fail.
        IERC20 newToken = new TestERC20("TEST", 18);
        vm.expectRevert("Can only unwhitelist a whitelisted token");
        proposals.proposeTokenUnwhitelisting( newToken, "test", "test");

		IERC20 wbtc = exchangeConfig.wbtc();
		IERC20 weth = exchangeConfig.weth();
		vm.stopPrank();

        // Whitelist the token (which will be paired with WBTC and WETH)
        vm.prank(address(dao));
		poolsConfig.whitelistPool(pools,  newToken, wbtc );
        vm.prank(address(dao));
		poolsConfig.whitelistPool(pools,  newToken, weth );

        // Unwhitelist the token and expect no revert
		vm.startPrank( DEPLOYER );
        proposals.proposeTokenUnwhitelisting(newToken, "test", "test");

        vm.expectRevert("Cannot create a proposal similar to a ballot that is still open");
        proposals.proposeTokenUnwhitelisting( newToken, "test", "test");

        // Get the ballot id
        uint256 ballotID = 1;
        assertEq(uint256(proposals.ballotForID(ballotID).ballotType), uint256(BallotType.UNWHITELIST_TOKEN));
        assertEq(proposals.ballotForID(ballotID).address1, address(newToken));


    }


	// A unit test that changes votes after unstaking SALT
	function testChangeVotesAfterUnstakingSALT() public {
    	vm.startPrank(alice);

    	address randomAddress = address(0x543210);

    	// Staking SALT
    	staking.stakeSALT(100000 ether);

    	// Create a proposal
    	proposals.proposeCallContract(randomAddress, 1000, "description" );

    	uint256 ballotID = 1;
    	assertEq(proposals.ballotForID(ballotID).ballotIsLive, true, "Ballot should be live after proposal");

    	// Vote YES
    	proposals.castVote(ballotID, Vote.YES);

    	// Assert vote has been cast
    	assertEq(uint256(proposals.lastUserVoteForBallot(ballotID, alice).vote), uint256(Vote.YES), "Vote should have been casted");
    	assertEq(proposals.lastUserVoteForBallot(ballotID, alice).votingPower, 100000 ether, "Vote should have been casted with 100000 ether voting power");

    	// Unstake SALT
    	staking.unstake(50000 ether, 2 );

    	// Vote NO
    	proposals.castVote(ballotID, Vote.NO);

    	// Assert vote has been changed and voting power decreased
    	assertEq(uint256(proposals.lastUserVoteForBallot(ballotID, alice).vote), uint256(Vote.NO), "Vote should have been changed to NO");
    	assertEq(proposals.lastUserVoteForBallot(ballotID, alice).votingPower, 50000 ether, "Vote should have been casted with 50000 ether voting power after unstaking");

    	// Unstake all remaining SALT
    	staking.unstake(50000 ether, 2 );

    	// Expect voting to fail due to lack of voting power
    	vm.expectRevert("Staked SALT required to vote");
    	proposals.castVote(ballotID, Vote.YES);
    }


	// A unit test with multiple users voting on a parameter ballot and verifying the vote totals
	function testParameterBallotVoting() public {
        // Test proposeParameterBallot function
        vm.startPrank(DEPLOYER);
        proposals.proposeParameterBallot(14, "description" );
        vm.stopPrank();

        uint256 ballotID = 1;
        Ballot memory ballot = proposals.ballotForID(ballotID);
        assertEq(ballot.ballotIsLive, true, "The ballot should be live.");

        // Test multiple users voting on the ballot

        // Voting by DEPLOYER
        vm.startPrank(DEPLOYER);
        staking.stakeSALT( 2000000 ether );


		vm.expectRevert( "Invalid VoteType for Parameter Ballot" );
        proposals.castVote(ballotID, Vote.YES);
		vm.expectRevert( "Invalid VoteType for Parameter Ballot" );
        proposals.castVote(ballotID, Vote.NO);

        proposals.castVote(ballotID, Vote.INCREASE);
        salt.transfer(bob, 1000000 ether);
        vm.stopPrank();

        // Voting by alice
        vm.startPrank(alice);
        staking.stakeSALT( 1000000 ether );
        proposals.castVote(ballotID, Vote.NO_CHANGE);
        vm.stopPrank();

		// Coting by bob
        vm.startPrank(bob);
        salt.approve( address(staking), type(uint256).max );
        salt.approve( address(proposals), type(uint256).max );
        staking.stakeSALT( 500000 ether );
        proposals.castVote(ballotID, Vote.NO_CHANGE);
        vm.stopPrank();

        // Verify vote totals
        uint256 increaseVotes = proposals.votesCastForBallot(ballotID, Vote.INCREASE);
        uint256 noChangeVotes = proposals.votesCastForBallot(ballotID, Vote.NO_CHANGE);
        uint256 totalVotes = proposals.totalVotesCastForBallot(ballotID);

        assertEq(increaseVotes, 2000000 ether, "INCREASE votes do not match the sum of votes.");
        assertEq(noChangeVotes, 1500000 ether, "NO_CHANGE votes do not match the sum of votes.");
        assertEq(totalVotes, increaseVotes + noChangeVotes, "Total votes do not match the sum of votes.");
    }


	// A unit test with multiple users voting on an approval ballot and verifying the vote totals
	function testApprovalBallotVoting() public {
        // Test proposeParameterBallot function
        vm.startPrank(DEPLOYER);
        proposals.proposeCountryInclusion( "USA", "description" );
        vm.stopPrank();

        uint256 ballotID = 1;
        Ballot memory ballot = proposals.ballotForID(ballotID);
        assertEq(ballot.ballotIsLive, true, "The ballot should be live.");

        // Test multiple users voting on the ballot

        // Voting by DEPLOYER
        vm.startPrank(DEPLOYER);
        staking.stakeSALT( 2500000 ether );

		vm.expectRevert( "Invalid VoteType for Approval Ballot" );
        proposals.castVote(ballotID, Vote.INCREASE);
		vm.expectRevert( "Invalid VoteType for Approval Ballot" );
        proposals.castVote(ballotID, Vote.NO_CHANGE);
		vm.expectRevert( "Invalid VoteType for Approval Ballot" );
        proposals.castVote(ballotID, Vote.DECREASE);

        proposals.castVote(ballotID, Vote.YES);

        staking.unstake(500000 ether, 12 );
        proposals.castVote(ballotID, Vote.YES);

        salt.transfer(bob, 1000000 ether);
        vm.stopPrank();

        // Voting by alice
        vm.startPrank(alice);
        staking.stakeSALT( 500000 ether );
        proposals.castVote(ballotID, Vote.NO);
        staking.stakeSALT( 500000 ether );
        proposals.castVote(ballotID, Vote.NO);
        vm.stopPrank();

		// Coting by bob
        vm.startPrank(bob);
        salt.approve( address(staking), type(uint256).max );
        salt.approve( address(proposals), type(uint256).max );
        staking.stakeSALT( 500000 ether );
        proposals.castVote(ballotID, Vote.NO);
        vm.stopPrank();

        // Verify vote totals
        uint256 yesVotes = proposals.votesCastForBallot(ballotID, Vote.YES);
        uint256 noVotes = proposals.votesCastForBallot(ballotID, Vote.NO);
        uint256 totalVotes = proposals.totalVotesCastForBallot(ballotID);

        assertEq(yesVotes, 2000000 ether, "YES votes do not match the sum of votes.");
        assertEq(noVotes, 1500000 ether, "NO votes do not match the sum of votes.");
        assertEq(totalVotes, yesVotes + noVotes, "Total votes do not match the sum of votes.");
    }


    // A unit test to verify that a user cannot cast a vote on a ballot that is not open for voting.
    function testUserCannotVoteOnClosedBallot() public {
        vm.startPrank( alice );

        // Alice proposes a parameter ballot
        proposals.proposeParameterBallot(20, "description" );
        uint256 ballotID = 1;

        // Alice casts a vote on the newly created ballot
        staking.stakeSALT( 1000000 ether );
        proposals.castVote(ballotID, Vote.INCREASE);

        // Close the ballot
        vm.expectRevert( "Only the DAO can mark a ballot as finalized" );
        proposals.markBallotAsFinalized( ballotID );
		vm.stopPrank();

        vm.prank( address(dao) );
        proposals.markBallotAsFinalized( ballotID );

        // Alice attempts to cast a vote on the closed ballot
        vm.prank( alice );
        vm.expectRevert("The specified ballot is not open for voting");
        proposals.castVote(ballotID, Vote.DECREASE);
    }


    // A unit test to verify that a user cannot cast an incorrect votetype on a Parameter Ballot
	function testIncorrectParameterVote() public {
        // Test proposeParameterBallot function
        vm.startPrank(DEPLOYER);
        proposals.proposeParameterBallot(16, "description" );
        vm.stopPrank();

        uint256 ballotID = 1;

        // Voting by DEPLOYER
        vm.startPrank(DEPLOYER);
        staking.stakeSALT( 2000000 ether );

		vm.expectRevert( "Invalid VoteType for Parameter Ballot" );
        proposals.castVote(ballotID, Vote.YES);
		vm.expectRevert( "Invalid VoteType for Parameter Ballot" );
        proposals.castVote(ballotID, Vote.NO);

        vm.stopPrank();
    }


	// A unit test to verify that a user cannot cast an incorrect votetype on an Approval Ballot
	function testIncorrectApprovalVote() public {
        // Test proposeParameterBallot function
        vm.startPrank(DEPLOYER);
        proposals.proposeCountryInclusion("USA", "description" );
        vm.stopPrank();

        uint256 ballotID = 1;

        // Voting by DEPLOYER
        vm.startPrank(DEPLOYER);
        staking.stakeSALT( 2000000 ether );

		vm.expectRevert( "Invalid VoteType for Approval Ballot" );
        proposals.castVote(ballotID, Vote.INCREASE);
		vm.expectRevert( "Invalid VoteType for Approval Ballot" );
        proposals.castVote(ballotID, Vote.NO_CHANGE);
		vm.expectRevert( "Invalid VoteType for Approval Ballot" );
        proposals.castVote(ballotID, Vote.DECREASE);
        vm.stopPrank();
    }


    // A unit test to verify that a user cannot propose a token whitelisting if the token has already been whitelisted.
	function testWhitelistingAlreadyWhitelisted() public {

		IERC20 wbtc = exchangeConfig.wbtc();
		IERC20 weth = exchangeConfig.weth();

		vm.prank(address(dao));
		poolsConfig.whitelistPool(pools,  wbtc, weth );

        vm.expectRevert( "The token has already been whitelisted" );
		vm.prank(DEPLOYER);
        proposals.proposeTokenWhitelisting( wbtc, "https://tokenIconURL", "This is a test token");
		}


    // A unit test to verify that a user cannot propose an approval ballot if there is already an open one.
	function testDuplicateApprovalBallot() public {
		// Test proposeParameterBallot function
		vm.startPrank(DEPLOYER);
		proposals.proposeCountryInclusion("USA", "description" );

		vm.expectRevert( "Cannot create a proposal similar to a ballot that is still open" );
		proposals.proposeCountryInclusion("USA", "description" );
		vm.stopPrank();

	}

    // A unit test to verify that a user cannot propose a parameter ballot if there is already an open one.
	function testDuplicateParameterBallot() public {
		// Test proposeParameterBallot function
		vm.startPrank(DEPLOYER);
		proposals.proposeParameterBallot(17, "description" );

		vm.expectRevert( "Cannot create a proposal similar to a ballot that is still open" );
		proposals.proposeParameterBallot(17, "description" );
		vm.stopPrank();

	}


	// A unit test to verify that a user cannot cast a vote after unstaking all their SALT.
    function testUserCannotVoteAfterUnstakingAllSALT() public {
        vm.startPrank(alice);
        // Alice stakes some SALT
        staking.stakeSALT(1000 ether);

        // Alice proposes a new ballot
        proposals.proposeParameterBallot(1, "description" );
        uint256 ballotID = proposals.openBallotsByName("parameter:1");

        // Alice casts a vote
        proposals.castVote(ballotID, Vote.INCREASE);

        // Alice unstakes all her SALT
        staking.unstake(1000 ether, 12);

        // Alice tries to cast a vote after unstaking all SALT
        vm.expectRevert("Staked SALT required to vote");
        proposals.castVote(ballotID, Vote.DECREASE);

        vm.stopPrank();
    }


	// A unit test to verify that the proposeSetContractAddress function does not allow a proposal to set a contract address to address(0).
	function testProposeSetContractAddressRejectsZeroAddress() public {
        vm.startPrank(alice);

        // Try to set an invalid address and expect a revert
        address newAddress = address(0);
        vm.expectRevert("Proposed address cannot be address(0)");
        proposals.proposeSetContractAddress("contractName", newAddress, "description" );

        vm.stopPrank();
    }


	// A unit test that checks the proposeSendSALT function does not allow a proposal to send SALT to address(0)
    function testProposeSendSALT2() public {
        vm.startPrank(DEPLOYER);

		salt.transfer( address(proposals), 1000000 ether );

        // Define an amount to propose
        uint256 amount = 1000 ether;

        // Try to propose sending SALT to address(0) and expect a revert
        vm.expectRevert("Cannot send SALT to address(0)");
        proposals.proposeSendSALT(address(0), amount, "description" );
    }


	// A unit test to verify that the proposeWebsiteUpdate function does not allow a proposal to update the website URL to an empty string.
    function testProposeWebsiteUpdateWithEmptyURL() public {
        vm.startPrank(DEPLOYER);

        // Attempt to propose an empty website URL
        string memory newWebsiteURL = "";

        // Expect a revert due to the website URL being empty
        vm.expectRevert("newWebsiteURL cannot be empty");
        proposals.proposeWebsiteUpdate(newWebsiteURL, "description" );
    }


	// A unit test that verifies if the createConfirmationProposal function creates a new proposal from the DAO and checks all necessary state changes.
	function testCreateConfirmationProposal() public {
        vm.startPrank(DEPLOYER);

        // Define a ballotName
        string memory ballotName = "setContract:1";
        BallotType ballotType = BallotType.SET_CONTRACT;
        address address1 = address(0x3333);
        uint256 number1 = 0;
        string memory string1 = "newContractAddress";
        string memory description = "description";

        // Ensure ballot with ballotName doesn't exist before proposing
        assertEq(proposals.openBallotsByName(ballotName), 0);

        // Call createConfirmationProposal
        vm.expectRevert( "Only the DAO can create a confirmation proposal" );
        proposals.createConfirmationProposal(ballotName, ballotType, address1, string1, description);
		vm.stopPrank();

		vm.prank(address(dao));
        proposals.createConfirmationProposal(ballotName, ballotType, address1, string1, description);


        // Check that the new ballot has been saved correctly
        uint256 ballotID = proposals.openBallotsByName(ballotName);
        Ballot memory ballot = proposals.ballotForID(ballotID);

        // Check that the proposed ballot parameters are correct
        assertTrue(ballot.ballotIsLive);
        assertEq(uint256(ballot.ballotType), uint256(ballotType));
        assertEq(ballot.ballotName, ballotName);
        assertEq(ballot.address1, address1);
        assertEq(ballot.number1, number1);
        assertEq(ballot.string1, string1);
        assertEq(ballot.description, description);
        assertEq(ballot.ballotMinimumEndTime, block.timestamp + daoConfig.ballotDuration());
    }


   // A unit test that checks if proposeWebsiteUpdate function does not allow proposal with the same web URL to be updated.
   function testProposeDuplicateWebsiteUpdate() public {
       vm.startPrank( DEPLOYER );

       // Propose a website update with a unique url
       string memory uniqueURL = "http://test.mysite.com";
       string memory description = "Test for proposeWebsiteUpdate function";
       proposals.proposeWebsiteUpdate(uniqueURL,description);

       // Trying to propose the same website URL should fail
       vm.expectRevert("Cannot create a proposal similar to a ballot that is still open");
       proposals.proposeWebsiteUpdate(uniqueURL, description);

       // Propose a new website update with a different URL
       string memory uniqueURL2 = "http://test2.mysite.com";
       proposals.proposeWebsiteUpdate(uniqueURL2, description);

       vm.stopPrank();
   }


   // A unit test that checks if the proposeTokenWhitelisting function creates proposals correctly, verifies that the proposal address is unique and different from address(0) and that the proposal's state changes appropriately.
   function testProposeTokenWhitelisting() public {
       vm.startPrank(DEPLOYER);

       // Get initial state before proposing the ballot
       uint256 initialNextBallotId = proposals.nextBallotID();

       // Define a ballotName
       address testTokenAddress = 0x1909B107ce8E4E1b43838371a290E13Bed3a1001;
       address testTokenAddress2 = 0x1909B107CE8e4e1b43838371a290E13BEd3a1002;
       string memory ballotName = "whitelist:0x1909b107ce8e4e1b43838371a290e13bed3a1001";

       // Ensure ballot with ballotName doesn't exist before proposing
       assertEq(proposals.openBallotsByName(ballotName), 0);

       // Call proposeTokenWhitelisting
       proposals.proposeTokenWhitelisting(TestERC20(testTokenAddress), "abc", "def");

       // Check that the next ballot ID has been incremented
       assertEq(proposals.nextBallotID(), initialNextBallotId + 1);

       // Check that the ballot with ballotName now exists
       assert(proposals.openBallotsByName(ballotName) == 1);

       // Check that the proposed ballot is in the correct state
       uint256 ballotID = proposals.openBallotsByName(ballotName);
       Ballot memory ballot = proposals.ballotForID(ballotID);

       // Check that the proposed ballot parameters are correct
       assertTrue(ballot.ballotIsLive);
       assertEq(uint256(ballot.ballotType), uint256(BallotType.WHITELIST_TOKEN));
       assertEq(ballot.ballotName, ballotName);
       assertEq(ballot.address1, testTokenAddress);
       assertEq(ballot.string1, "abc");
       assertEq(ballot.description, "def");
       assertEq(ballot.ballotMinimumEndTime, block.timestamp + daoConfig.ballotDuration());

       // Try proposing a ballot for the same token again - should fail
       vm.expectRevert("Cannot create a proposal similar to a ballot that is still open");
       proposals.proposeTokenWhitelisting(TestERC20(testTokenAddress), "", "");

       // Verify proposing a new ballot with a new token
       string memory ballotNameTwo = "whitelist:0x1909b107ce8e4e1b43838371a290e13bed3a1002";
       assertEq(proposals.openBallotsByName(ballotNameTwo), 0);
       proposals.proposeTokenWhitelisting(TestERC20(testTokenAddress2), "", "");
       assertEq(proposals.openBallotsByName(ballotNameTwo), 2);
       vm.stopPrank();

       // mark ballot as finalized
       vm.prank(address(dao));
       proposals.markBallotAsFinalized(1);

       vm.startPrank(DEPLOYER);

       // Verify ballot has been marked as finalized
       Ballot memory finalizedBallot = proposals.ballotForID(1);
       assertFalse(finalizedBallot.ballotIsLive);

       // Try proposing a ballot for the same token again - should pass as it has been marked finalized
       proposals.proposeTokenWhitelisting(TestERC20(testTokenAddress), "", "");

//       console.log( "proposals.openBallotsByName(ballotName): ", proposals.openBallotsByName(ballotName) );
       assertEq(proposals.openBallotsByName(ballotName), 3);

       vm.stopPrank();
		}


   // A unit test to verify that the winningParameterVote function correctly returns the vote with the highest count among Increase, Decrease, and No Change votes.
   function testWinningParameterVote() public {

   	   // Propose a new parameter ballot
       vm.startPrank( DEPLOYER );
       proposals.proposeParameterBallot(1, "description");
       salt.transfer(alice, 100 ether);
       salt.transfer(bob, 100 ether);
       vm.stopPrank();

       uint256 ballotID = 1;


       // Alice stakes some SALT
       vm.startPrank(alice);
       staking.stakeSALT(1 ether);
       vm.stopPrank();


       // Alice votes to INCREASE
       vm.startPrank(alice);
       proposals.castVote(ballotID, Vote.INCREASE);
       vm.stopPrank();

       // Assert the winning vote is INCREASE
       assertEq(uint(proposals.winningParameterVote(ballotID)), uint(Vote.INCREASE));

       // Bob stakes some SALT
       vm.startPrank(bob);
       staking.stakeSALT(2 ether);
       vm.stopPrank();

       // Bob votes to DECREASE
       vm.startPrank(bob);
       proposals.castVote(ballotID, Vote.DECREASE);
       vm.stopPrank();

       // Assert the winning vote is DECREASE
       assertEq(uint(proposals.winningParameterVote(ballotID)), uint(Vote.DECREASE));

       // Bob changes his vote to NO_CHANGE
       vm.startPrank(bob);
       proposals.castVote(ballotID, Vote.NO_CHANGE);
       vm.stopPrank();

       // Assert the winning vote is now NO_CHANGE
       assertEq(uint(proposals.winningParameterVote(ballotID)), uint(Vote.NO_CHANGE));

       // DEPLOYER stakes some SALT
       vm.startPrank(DEPLOYER);
       staking.stakeSALT(3 ether);
       vm.stopPrank();

       // DEPLOYER votes to DECREASE
       vm.startPrank(DEPLOYER);
       proposals.castVote(ballotID, Vote.DECREASE);
       vm.stopPrank();

       // Assert the winning vote is DECREASE
       assertEq(uint(proposals.winningParameterVote(ballotID)), uint(Vote.DECREASE));
   }


   // A unit test that checks the ballotIsApproved function to verify if it correctly decides if the ballot is approved or not based on the number of yes and no votes.
   	function testBallotIsApproved() public {
   		// Initialize some parameters
   		uint256 ballotID = 1;
   		uint256 stakeAmount = 1000000 ether;

   		// Stake some SALT from Alice's account
   		vm.prank(alice);
   		staking.stakeSALT(stakeAmount);

   		// Propose a ballot
   		vm.prank(DEPLOYER);
   		proposals.proposeCountryInclusion("usa", "proposed ballot");

   		// Casting a vote YES
   		vm.prank(alice);
   		proposals.castVote( ballotID, Vote.YES );

   		// Now, we allow some time to pass in order to finalize the ballot
   		vm.warp(block.timestamp + daoConfig.ballotDuration());

   		// We finalize the ballot
   		vm.prank( address(dao) );
   		proposals.markBallotAsFinalized(ballotID);

   		// Check if the ballot is approved
   		bool approved = proposals.ballotIsApproved(ballotID);

   		// The ballot should be approved
   		assertTrue(approved);
   	}


    // A unit test for the proposeCountryInclusion and proposeCountryExclusion functions to verify they don't allow an empty country name.
    function testProposeCountryInclusionExclusionEmptyName() public {
        string memory emptyCountryName = "";

        // Proposing country inclusion with empty country name should fail
        vm.startPrank(alice);
        vm.expectRevert("Country cannot be empty");
        proposals.proposeCountryInclusion(emptyCountryName, "description");
        vm.stopPrank();

        // Proposing country exclusion with empty country name should fail
        vm.startPrank(alice);
        vm.expectRevert("Country cannot be empty");
        proposals.proposeCountryExclusion(emptyCountryName, "description");
        vm.stopPrank();
    }


    // A unit test that checks if the requiredQuorumForBallotType function gives an error when the amount of SALT staked is zero.
    function testRequiredQuorumForBallotTypeWithZeroStakedSalt() public {

        uint256 totalStaked = staking.totalSharesForPool(PoolUtils.STAKED_SALT);

        // Assert that total staked SALT is zero
        assertEq(totalStaked, 0);

        // expect a revert on getting required quorum for any ballot
        vm.expectRevert("SALT staked cannot be zero to determine quorum");
        proposals.requiredQuorumForBallotType(BallotType.PARAMETER);
    }


    // A unit test to verify that the ballotForID function correctly returns the ballot for a given ballot ID.
    function testBallotForID() public {
        // Propose a ballot
        vm.startPrank(DEPLOYER);
        proposals.proposeParameterBallot(2, "testBallotForID");
        uint256 expectedBallotID = 1; // The original test setup function nextBallotID = 1
        assertEq(proposals.nextBallotID(), expectedBallotID + 1);

        // Retrieve the ballot
        Ballot memory retrievedBallot = proposals.ballotForID(expectedBallotID);

        // Assert the retrieved ballot
        assertTrue(retrievedBallot.ballotIsLive);
        assertEq(retrievedBallot.ballotID, expectedBallotID);
        assertEq(uint256(retrievedBallot.ballotType), uint256(BallotType.PARAMETER));
        assertEq(retrievedBallot.ballotName, "parameter:2");
        assertEq(retrievedBallot.address1, address(0));
        assertEq(retrievedBallot.number1, 2);
        assertEq(retrievedBallot.string1, "");
        assertEq(retrievedBallot.description, "testBallotForID");
        assertEq(retrievedBallot.ballotMinimumEndTime, block.timestamp + daoConfig.ballotDuration());

        // Clear the ballot
        vm.startPrank(address(dao));
        proposals.markBallotAsFinalized(expectedBallotID);
        vm.stopPrank();

        // Finalized ballots still exist
        Ballot memory retrievedBallot2 = proposals.ballotForID(expectedBallotID);
        assertEq(retrievedBallot2.ballotID, expectedBallotID);
    }


    // A unit test to verify that proposeCallContract function refuses any proposals to call a contract at address(0).
    function testProposeCallContractZeroAddressRejection() public {
        vm.startPrank(DEPLOYER);

        // Try to propose a contract call to address(0)
        vm.expectRevert("Contract address cannot be address(0)");
        proposals.proposeCallContract(address(0), 10, "Should Fail");
        vm.stopPrank();
    }


	// A unit test that checks openBallotsForTokenWhitelisting() under various conditions
	function testOpenBallotsForTokenWhitelisting() public {

        vm.startPrank(alice);
        IERC20 testToken = new TestERC20("TEST", 18);
        proposals.proposeTokenWhitelisting(testToken, "https://tokenIconURL", "This is a test token");

        // Assert that the number of open ballots for token whitelisting has increased
        assertEq(proposals.numberOfOpenBallotsForTokenWhitelisting(), 1, "The number of open ballots for token whitelisting did not increase after a proposal");
		uint256[] memory ballotIDs = proposals.openBallotsForTokenWhitelisting();
		assertEq( ballotIDs.length, 1 );
		assertEq( ballotIDs[0], 1 );

        // Create a second whitelisting ballot
        IERC20 testToken2 = new TestERC20("TEST", 18);
        proposals.proposeTokenWhitelisting(testToken2, "https://tokenIconURL", "This is a test token");

        assertEq(proposals.numberOfOpenBallotsForTokenWhitelisting(), 2, "The number of open ballots for token whitelisting did not increase after a second proposal");
		ballotIDs = proposals.openBallotsForTokenWhitelisting();
		assertEq( ballotIDs.length, 2 );
		assertEq( ballotIDs[0], 1 );
		assertEq( ballotIDs[1], 2 );
		vm.stopPrank();
   }


	// A unit test that checks openBallots() under various conditions
	function testOpenBallots() public {

        vm.startPrank(alice);
        IERC20 testToken = new TestERC20("TEST", 18);
        proposals.proposeTokenWhitelisting(testToken, "https://tokenIconURL", "This is a test token");

        // Assert that the number of open ballots for token whitelisting has increased
        assertEq(proposals.numberOfOpenBallotsForTokenWhitelisting(), 1, "The number of open ballots for token whitelisting did not increase after a proposal");
		uint256[] memory ballotIDs = proposals.openBallots();
		assertEq( ballotIDs.length, 1 );
		assertEq( ballotIDs[0], 1 );

        // Create a second whitelisting ballot
        IERC20 testToken2 = new TestERC20("TEST", 18);
        proposals.proposeTokenWhitelisting(testToken2, "https://tokenIconURL", "This is a test token");

        assertEq(proposals.numberOfOpenBallotsForTokenWhitelisting(), 2, "The number of open ballots for token whitelisting did not increase after a second proposal");
		ballotIDs = proposals.openBallots();
		assertEq( ballotIDs.length, 2 );
		assertEq( ballotIDs[0], 1 );
		assertEq( ballotIDs[1], 2 );


		uint256[] memory ballotIDs2 = proposals.openBallotsForTokenWhitelisting();
		assertEq( ballotIDs2.length, 2 );
		assertEq( ballotIDs2[0], 1 );
		assertEq( ballotIDs2[1], 2 );


		// Create a third ballot
		proposals.proposeCountryInclusion("USA", "description" );

		ballotIDs = proposals.openBallots();
		assertEq( ballotIDs.length, 3 );
		assertEq( ballotIDs[0], 1 );
		assertEq( ballotIDs[1], 2 );
		assertEq( ballotIDs[2], 3 );
		vm.stopPrank();


		// Remove the second whitelisting ballot
		vm.prank(address(dao));
		proposals.markBallotAsFinalized(2);

		ballotIDs2 = proposals.openBallotsForTokenWhitelisting();
		assertEq( ballotIDs2.length, 1 );
		assertEq( ballotIDs2[0], 1 );


		ballotIDs = proposals.openBallots();
		assertEq( ballotIDs.length, 2 );
		assertEq( ballotIDs[0], 1 );
		assertEq( ballotIDs[1], 3 );
    }
   }





