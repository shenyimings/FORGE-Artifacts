pragma solidity =0.8.21;


library SigningTools
	{
	// The public address of the signer for the Airdorp whitelist and defautl AccessManager
	address constant public EXPECTED_SIGNER = 0x1234519DCA2ef23207E1CA7fd70b96f281893bAa;


	function _slice32(bytes memory array, uint index) internal pure returns (bytes32 result)
		{
		result = 0;

		for (uint i = 0; i < 32; i++)
			{
			uint8 temp = uint8(array[index+i]);
			result |= bytes32((uint(temp) & 0xFF) * 2**(8*(31-i)));
			}
		}


	// Verify that the messageHash was signed by the authoratative signer.
    function _verifySignature(bytes32 messageHash, bytes memory signature ) internal pure returns (bool)
    	{
		bytes32 r = _slice32(signature, 0);
		bytes32 s = _slice32(signature, 32);
		uint8 v = uint8(signature[64]);

		address recoveredAddress = ecrecover(messageHash, v, r, s);

        return (recoveredAddress == EXPECTED_SIGNER);
    	}
	}
