// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (port from token/ERC20/extensions/draft-ERC20Permit.sol)

pragma solidity ^0.8.0;


/**
 * Implementation of ScriptEngine system contract that depends on MeterNativeV3
 */

import "./IMeterNativeV3.sol";

contract ScriptEngine  {
    IMeterNativeV3 _meterTracker =
        IMeterNativeV3(0x0000000000000000004D657465724e6174697665);


    /**
     * this func create a bucket from msg.sender, voted to candidate
     * will revert if any error happens
     */
    function bucketOpen(address candidate, uint256 amount) public returns (bytes32 bktID) {
        string memory errMsg;
        (bktID,errMsg) = _meterTracker.native_bucket_open(msg.sender, candidate, amount);
        require((keccak256(abi.encodePacked((errMsg))) == keccak256(abi.encodePacked(("")))), errMsg);
    }

    /**
     * this func adds more value to the designated bucket owned by msg.sender
     * will revert if any error happens
     */
    function bucketDeposit( bytes32 bucketID, uint256 amount) public {
        string memory errMsg = _meterTracker.native_bucket_deposit(msg.sender, bucketID, amount);
        require((keccak256(abi.encodePacked((errMsg))) == keccak256(abi.encodePacked(("")))), errMsg);
    }

    /**
     * this func withdraw value from the designated bucket owned by msg.sender, createsa sub bucket to `recipient`
     * `recipient` will receive funds after bucket mature time
     * will revert if any error happens
     */
    function bucketWithdraw( bytes32 bucketID, uint256 amount, address recipient) public returns (bytes32 newBktID){
        string memory errMsg;
        (newBktID, errMsg) = _meterTracker.native_bucket_withdraw(msg.sender, bucketID, amount, recipient);
        require((keccak256(abi.encodePacked((errMsg))) == keccak256(abi.encodePacked(("")))), errMsg);
    }

    /**
     * this func withdraw all value from the designated bucket owned by msg.sender, and completely close this bucket
     * `owner` will receive funds after bucket mature time
     * will revert if any error happens
     */
    function bucketClose( bytes32 bucketID) public {
        string memory errMsg = _meterTracker.native_bucket_close(msg.sender, bucketID);
        require((keccak256(abi.encodePacked((errMsg))) == keccak256(abi.encodePacked(("")))), errMsg);
    }
    /**
     * this func set candidate for the designated bucket owned by msg.sender
     * will revert if any error happens
     */
    function bucketUpdateCandidate(bytes32 bucketID, address newCandidateAddr) public{
        string memory errMsg = _meterTracker.native_bucket_update_candidate(msg.sender, bucketID, newCandidateAddr);
        require((keccak256(abi.encodePacked((errMsg))) == keccak256(abi.encodePacked(("")))), errMsg);
    }

    function boundedMTRG() public view returns (uint256){
        return _meterTracker.native_mtrg_locked_get(msg.sender);
    }
}
