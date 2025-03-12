pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

///@title Frens Merkle Prover
///@author 0xWildhare and the Frens team
///@dev this gives the Frens Multisig a way to mark a pool as exiting (and then no longer charge fees) This should be replaced by a decentralized alternative

import "./interfaces/IStakingPool.sol";
import "./interfaces/IFrensOracle.sol";
import "./interfaces/IFrensStorage.sol";

contract FrensOracle is IFrensOracle {

    //sets a validator public key (which is associated with a pool) as exiting
    mapping(bytes => bool) public isExiting;

    IFrensStorage frensStorage;

    constructor(IFrensStorage frensStorage_) {
        frensStorage = frensStorage_;
    }

    ///@dev called by the staking pool to check if the validator is exiting
    function checkValidatorState(address poolAddress) external view returns(bool) {
        IStakingPool pool = IStakingPool(poolAddress);
        bytes memory pubKey = pool.pubKey();
        return isExiting[pubKey];
    }

    ///@dev allows multisig (guardian) to set a pool as exiting. 
   function setExiting(bytes memory pubKey, bool _isExiting) external {
        require(msg.sender == frensStorage.getGuardian(), "must be guardian");
        isExiting[pubKey] = _isExiting;
   }
    
}