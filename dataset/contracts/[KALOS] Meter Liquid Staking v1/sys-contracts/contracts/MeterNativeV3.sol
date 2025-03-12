pragma solidity ^0.8.0;

import "./NewMeterNative.sol";
import "./IMeterNativeV3.sol";

contract MeterNativeV3 is NewMeterNative, IMeterNativeV3{

    constructor () { }
    
    // Bucket related

    /**
     * this func creates a bucket with `owner`'s balance, voted to `candidateAddr`
     * returns a new bucket ID, and error string (default "")
     */
    function native_bucket_open(address owner, address candidateAddr, uint256 amount) public pure returns (bytes32, string memory){ }

    /**
     * this func adds more balance to the designated bucket with `owner`'s fund 
     * returns an error string (default "")
     */
    function native_bucket_deposit(address owner, bytes32 bucketID, uint256 amount) public pure returns (string memory){ }

    /**
     * this func sub balances from designated bucket, and the `recipient` will receive the fund after bucket's matureTime
     * returns the sub bucketID and error string (default "")
     */
    function native_bucket_withdraw(address owner, bytes32 bucketID, uint256 amount, address recipient) public pure returns (bytes32, string memory){ }

    /**
     * this func closes the designated bucket, and `owner` will receive fund after bucket's matureTime
     */
    function native_bucket_close(address owner, bytes32 bucketID) public pure returns (string memory){ }
    
    function native_bucket_update_candidate(address owner, bytes32 bucketID, address newCandidateAddr) public pure returns (string memory) {}
}

