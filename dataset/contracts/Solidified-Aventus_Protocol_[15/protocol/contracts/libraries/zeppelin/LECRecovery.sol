pragma solidity 0.5.12;

 /**
  * @title Eliptic curve signature operations
  *
  * @dev Code adapted from OpenZeppelin's:
  * https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/ECRecovery.sol, Commit: ad12381 (on 9 May)
  *
  * @dev Based on https://gist.github.com/axic/5b33912c6f61ae6fd96d6c4a47afde6d
  */

 library LECRecovery {

   /**
    * @dev Recover signer address from a message by using their signature
    * @param _hash bytes32 message, the hash is the signed message. What is recovered is the signer address.
    * @param _sig bytes signature, the signature is generated using web3.eth.sign()
    */
   function recover(bytes32 _hash, bytes memory _sig)
     internal
     pure
     returns (address)
   {
     _hash = toEthSignedMessageHash(_hash);
     bytes32 r;
     bytes32 s;
     uint8 v;

     // Check the signature length
     if (_sig.length != 65)
       return (address(0));

     // Divide the signature in r, s and v variables
     // ecrecover takes the signature parameters, and the only way to get them
     // currently is to use assembly.
     // solium-disable-next-line security/no-inline-assembly
     assembly {
       r := mload(add(_sig, 32))
       s := mload(add(_sig, 64))
       v := byte(0, mload(add(_sig, 96)))
     }

     // See: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/cryptography/ECDSA.sol
     if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0)
      return address(0);
      
     // Version of signature should be 27 or 28, but 0 and 1 are also possible versions
     if (v < 27)
       v += 27;

     // If the version is correct return the signer address
     require (v == 27 || v == 28, "Incorrect signature version");
      // solium-disable-next-line arg-overflow
     return ecrecover(_hash, v, r, s);
   }

   /**
    * toEthSignedMessageHash
    * @dev prefix a bytes32 value with "\x19Ethereum Signed Message:"
    * @dev and hash the result
    */
   function toEthSignedMessageHash(bytes32 _hash)
     private
     pure
     returns (bytes32)
   {
     // 32 is the length in bytes of hash,
     // enforced by the type signature above
     return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash));
   }
 }
