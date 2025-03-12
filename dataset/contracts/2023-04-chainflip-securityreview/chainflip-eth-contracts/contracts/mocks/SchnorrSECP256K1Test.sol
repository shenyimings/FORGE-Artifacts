pragma solidity ^0.8.0;

import "../abstract/SchnorrSECP256K1.sol";

/**
 * @title    SchnorrSECP256K1Test
 * @notice   A contract that implements SchnorrSECP256K1 and exposes
 *           testVerifySignature for the purpose of testing it, since
 *           we want the contract used in production (SchnorrSECP256K1)
 *           to be abstract and have testVerifySignature internal
 */
contract SchnorrSECP256K1Test is SchnorrSECP256K1 {
    /**
     * @notice   Exposes the testVerifySignature fcn from SchnorrSECP256K1
     *           so that it's public and callable directly
     */
    function testVerifySignature(
        uint256 msgHash,
        uint256 signature,
        uint256 signingPubKeyX,
        uint8 pubKeyYParity,
        address nonceTimesGeneratorAddress
    ) external pure returns (bool) {
        return verifySignature(msgHash, signature, signingPubKeyX, pubKeyYParity, nonceTimesGeneratorAddress);
    }
}
