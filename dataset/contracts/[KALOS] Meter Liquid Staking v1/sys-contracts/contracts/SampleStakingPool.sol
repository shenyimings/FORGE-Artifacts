// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (port from token/ERC20/extensions/draft-ERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * Sample code for Staking Pool on Meter depends on ScriptEngine
 */
import "./ScriptEngine.sol";
import "./MeterGovERC20Permit.sol";

contract SampleStakingPool{
    ScriptEngine scriptEngine = ScriptEngine(0x63726970742d656E67696E652D61646472657373);
    MeterGovERC20Permit MTRG = MeterGovERC20Permit(0x228ebBeE999c6a7ad74A6130E81b12f9Fe237Ba3);
    bytes32 public poolBucketID;

    function init(address candidate, uint256 amount) public returns (bytes32){
        require(poolBucketID==bytes32(0), "pool already initialized");
        MTRG.transferFrom(msg.sender, address(this), amount);
        poolBucketID = scriptEngine.bucketOpen(candidate, amount);
        return poolBucketID;
    }

    function deposit(uint256 amount) public {
        require(poolBucketID!=bytes32(0), "pool is not initialized");
        MTRG.transferFrom(msg.sender, address(this), amount);
        return scriptEngine.bucketDeposit(poolBucketID, amount);
    }

    function withdraw(uint256 amount, address recipient) public returns (bytes32 ){
        require(poolBucketID!=bytes32(0), "pool is not initialized");
        return scriptEngine.bucketWithdraw(poolBucketID, amount, recipient);
    }

    function destroy() public {
        require(poolBucketID!=bytes32(0), "pool is not initialized");
        return scriptEngine.bucketClose(poolBucketID);
    }

    function updateCandidate(address newCandidateAddr) public{
        require(poolBucketID!=bytes32(0), "pool is not initialized");
        return scriptEngine.bucketUpdateCandidate(poolBucketID, newCandidateAddr);
    }
}