// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.15;

contract TimeService {

    function getTimestamp() external view returns(uint256){
        return block.timestamp;                                    
    }

}
