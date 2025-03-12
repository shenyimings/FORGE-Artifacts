    //SPDX-License-Identifier: MIT
    pragma solidity 0.8.5;



    // ----------------------------------------------------------------------------

    // Contract function to receive approval and execute function in one call

    // Borrowed from MiniMeToken

    // ----------------------------------------------------------------------------

    abstract contract ApproveAndCallFallBack {

        function receiveApproval(address from, uint256 tokens, address token, bytes memory data) public virtual ;

    }

