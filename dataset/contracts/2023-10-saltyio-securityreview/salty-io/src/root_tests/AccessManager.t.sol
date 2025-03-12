// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../dev/Deployment.sol";


contract TestAccessManager is Deployment
	{
	constructor()
		{
		accessManager = new AccessManager(dao);

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();
		}


	// A unit test where the DAO address is set to address(0) upon contract creation to ensure that it reverts as expected.
	function testCreateAccessManagerWithZeroAddress() public
    	{
    	IDAO zeroAddressDAO = IDAO(address(0));

    	vm.expectRevert("_dao cannot be address(0)");
    	new AccessManager(zeroAddressDAO);
    	}


	// A unit test where a user does not grant access and the walletHasAccess is checked to verify that the user does not have access.
	function testUserWithoutAccess( address user ) public
    	{
    	bool access = accessManager.walletHasAccess(user);
    	if ( user == address(0x1111) )
    		return;
    	if ( user == address(0x2222) )
    		return;
    	if ( user == address(0x3333) )
    		return;
    	if ( user == DEPLOYER )
    		return;
    	if ( user == address(this) )
    		return;

    	assertFalse(access, "User without granted access should not have access");
    	}


	// A unit test in which a DAO is used to initialize the AccessManager contract. Check that the dao state variable in the AccessManager contract is correctly set to the address of the DAO contract.
	function testDaoAddressInAccessManager() public
    	{
    	// Initialize new AccessManager with the DAO contract
    	AccessManager newAccessManager = new AccessManager(dao);

    	// Check that the dao state variable in the AccessManager contract is correctly set to the address of the DAO contract
    	assertEq(address(newAccessManager.dao()), address(dao), "DAO address not correctly set in AccessManager");
    	}


	// A  unit test where the DAO tries to call excludedCountriesUpdated and the geoVersion is checked before and after the function call to ensure it increments correctly.
	function testDaoCallsExcludedCountriesUpdated() public
    	{
    	// Get the initial geoVersion
    	uint256 initialGeoVersion = accessManager.geoVersion();

    	// DAO calls excludedCountriesUpdated
    	vm.prank(address(dao));
    	accessManager.excludedCountriesUpdated();

    	// Get the new geoVersion
    	uint256 newGeoVersion = accessManager.geoVersion();

    	// Check that the geoVersion incremented correctly
    	assertEq(newGeoVersion, initialGeoVersion + 1, "geoVersion did not increment correctly");
    	}


	// A unit test where an address other than the DAO tries to call excludedCountriesUpdated to ensure it reverts as expected.
	function testNonDaoCallsExcludedCountriesUpdated() public
    	{
    	// Non-DAO address tries to call excludedCountriesUpdated
    	IDAO fakeDAO = IDAO(address(this));
    	accessManager = new AccessManager(fakeDAO);

		// Shouldn't revert
    	accessManager.excludedCountriesUpdated();

		// Should revert
    	vm.expectRevert("AccessManager.excludedCountriedUpdated only callable by the DAO");

		vm.prank( address(0x123));
    	accessManager.excludedCountriesUpdated();
    	}


	// A unit test where a user grants access to their wallet using grantAccess, and walletHasAccess is called to verify that the access was correctly granted.
	function testGrantAccess() public
    	{
    	address user = address(this);

    	// Check that the access was correctly granted
    	bool access = accessManager.walletHasAccess(user);
    	assertEq(access, true, "Access not correctly granted");
    	}


	// A unit test where a user grants access, then attempts to grant access again, and walletHasAccess is checked to verify that the user still has access and the function call does not revert.
	function testGrantAccessTwice() public
    	{
    	address alice = address(0x1111);
    	grantAccessAlice();

    	// Check that the user still has access
    	bool access = accessManager.walletHasAccess(alice);
    	assertEq(access, true, "Access not correctly granted after granting access twice");
    	}


	// A unit test where a user grants access, the DAO calls excludedCountriesUpdated, then the user grants access again, and walletHasAccess is checked to verify that the user has access under the new geoVersion.
	function testAccessWithGeoVersionUpdate() public
		{
		address alice = address(0x1111);
		assertEq(accessManager.walletHasAccess(alice), true, "Alice should start with access");

		// DAO updates the list of excluded countries
		vm.prank(address(dao));
		accessManager.excludedCountriesUpdated();

		assertEq(accessManager.walletHasAccess(alice), false, "There should not be access after geoVersion update");

		// User grants access again
		bytes memory sig = abi.encodePacked(hex"8b213e0ebbb653419203488db6b2ea3dcd35067906b813aee2e2ae20db4218233a72959b5aa61d2e1673aac95a75ac46cb80d93630f7b2d98de5e7344e6f14821c");
		vm.prank( address(0x1111) );
		accessManager.grantAccess(sig);

		// Check that the user still has access under the new geoVersion
		assertEq(accessManager.walletHasAccess(alice), true, "Access not correctly granted after geoVersion update");
		}


	// A unit test where the DAO calls excludedCountriesUpdated, a user grants access, the DAO calls excludedCountriesUpdated again, and walletHasAccess is checked to verify that the user does not have access under the new geoVersion.
	function testAccessRevocationWithGeoVersionUpdate() public
    	{
    	address user = address(this);

    	// DAO updates the list of excluded countries
		vm.prank(address(dao));
    	accessManager.excludedCountriesUpdated();

    	// User grants access to their wallet
//    	accessManager.grantAccess();

    	// DAO updates the list of excluded countries again
		vm.prank(address(dao));
    	accessManager.excludedCountriesUpdated();

    	// Check that the user does not have access under the new geoVersion
    	bool access = accessManager.walletHasAccess(user);
    	assertEq(access, false, "Access incorrectly granted after geoVersion update");
    	}



	// A unit test where multiple users grant access, the DAO calls excludedCountriesUpdated, some users grant access again, and walletHasAccess is checked for each user to verify that the ones who granted access again have access under the new geoVersion, and the others do not.
	function testAccessStatusAfterMultipleUpdates() public
    	{
    	address alice = address(0x1111);
		address bob = address(0x2222);
		address charlie = address(0x3333);

    	// DAO updates the list of excluded countries
    	vm.prank(address(dao));
    	accessManager.excludedCountriesUpdated();

    	// Some users grant access to Alice and Charlie
		bytes memory sig = abi.encodePacked(hex"8b213e0ebbb653419203488db6b2ea3dcd35067906b813aee2e2ae20db4218233a72959b5aa61d2e1673aac95a75ac46cb80d93630f7b2d98de5e7344e6f14821c");
		vm.prank( address(0x1111) );
		accessManager.grantAccess(sig);

		sig = abi.encodePacked(hex"21b0ce1a5fefbdbe547f7cc3774c70e1464e36e2826afad8508c90e9fd05abd8363f04b93ba09c530ff09dc5d6ad0551a36fa8637ac82bf764f1e3fbf7090c981c");
		vm.prank( address(0x3333) );
		accessManager.grantAccess(sig);

    	// Check that the users who granted access again have access under the new geoVersion
    	assertEq(accessManager.walletHasAccess(alice), true, "Alice should have access");
    	assertEq(accessManager.walletHasAccess(charlie), true, "Charlie should have access");

    	// Check that the user who did not grant access again does not have access under the new geoVersion
    	assertEq(accessManager.walletHasAccess(bob), false, "Bob should not have access");
    	}


	// A unit test where excludedCountriesUpdated is called twice in succession and verify geoVersion increments correctly on both operations.
	 function testGeoVersionIncrement() public
        {
            // Get the initial geoVersion
            uint256 initialGeoVersion = accessManager.geoVersion();

            // DAO calls excludedCountriesUpdated first time
            vm.prank(address(dao));
            accessManager.excludedCountriesUpdated();

            // Get the updated geoVersion
            uint256 updatedGeoVersion = accessManager.geoVersion();

            // Check that the geoVersion incremented correctly
            assertEq(updatedGeoVersion, initialGeoVersion + 1, "geoVersion did not increment correctly after first update");

            // DAO calls excludedCountriesUpdated second time
            vm.prank(address(dao));
            accessManager.excludedCountriesUpdated();

            // Get the new updated geoVersion
            uint256 newUpdatedGeoVersion = accessManager.geoVersion();

            // Check that the geoVersion incremented correctly again
            assertEq(newUpdatedGeoVersion, updatedGeoVersion + 1, "geoVersion did not increment correctly after second update");
        }


	function bytes32ToHexString(bytes32 input) internal pure returns (string memory) {
			bytes memory lookup = "0123456789abcdef";
			bytes memory result = new bytes(64);
			for (uint i = 0; i < 32; i++) {
				uint8 currentByte = uint8(input[i]);
				uint8 hi = uint8(currentByte / 16);
				uint8 lo = currentByte - 16 * hi;
				result[i*2] = lookup[hi];
				result[i*2+1] = lookup[lo];
			}
			return string(result);
		}


	function slice32(bytes memory array, uint index) internal pure returns (bytes32 result)
		{
		result = 0;

		for (uint i = 0; i < 32; i++)
			{
			uint8 temp = uint8(array[index+i]);
			result |= bytes32((uint(temp) & 0xFF) * 2**(8*(31-i)));
			}
		}


    // A unit test to check that the verify signer method is working properly
	function testVerifySigner() public
		{
		// Signed hash
		// geoVersion: 5
		// wallet: 0x73107dA86708c2DAd0D91388fB057EeE3E2581aF
		// expectedSigner: 0x1234519dca2ef23207e1ca7fd70b96f281893baa
		// hash: 9b978b40988bf1671fc95b11a0dc27fd55a7cb99ca5b3c095527d3ba1737ca5f21488b1963c6cff3d27ee2423b20df6c70960bc8fe270450cf01212311af75561c

		uint256 geoVersion = 5;
		address wallet = 0x73107dA86708c2DAd0D91388fB057EeE3E2581aF;

		bytes memory sig = abi.encodePacked(hex"fe5516272a193c8bb439c68336de6dbbdfdec1e346703f4f2e4f202a64b094697f4602626407e82b565cf1af407e50a6bf1c5143fb8c32eb7760cdc5434321f31b");

		bytes32 r = slice32(sig, 0);
		bytes32 s = slice32(sig, 32);
		uint8 v = uint8(sig[64]);

//		console.log( "R: ", bytes32ToHexString(r) );
//		console.log( "S: ", bytes32ToHexString(s) );
//		console.log( "V: ", v );

		bytes32 messageHash = keccak256(abi.encodePacked(geoVersion, wallet));
//		console.log( "MESSAGE HASH: ", bytes32ToHexString(messageHash) );

		address recoveredAddress = ecrecover(messageHash, v, r, s);
//		console.log( "RECOVERED ADDRESS: ", recoveredAddress );

		assertEq( recoveredAddress, 0x1234519DCA2ef23207E1CA7fd70b96f281893bAa, "Incorrect recovered address" );
		}
    }

