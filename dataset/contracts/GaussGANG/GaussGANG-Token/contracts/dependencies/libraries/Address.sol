// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;



// Collection of functions related to the address type.
library Address {
    
    /*  Returns true if `account` is a contract.

            - It is unsafe to assume that an address for which this function returns
                false is an externally-owned account (EOA) and not a contract.
     
            - Among others, `isContract` will return false for the following
                types of addresses:
     
                - an externally-owned account
                - a contract in construction
                - an address where a contract will be created
                - an address where a contract lived, but was destroyed
    */
    function isContract(address account) internal view returns (bool) {
        
        // This method relies on extcodesize, which returns 0 for contracts in construction,
        //  since the code is only stored at the end of the constructor execution.
        uint256 size;
        
        assembly {
            size := extcodesize(account)
        }
        
        return size > 0;
    }

    
    // Replacement for Solidity's `transfer`: sends `amount` jager to `recipient`, forwarding all available gas and reverting on errors.
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, 'Address: insufficient balance');

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }


    /*  Performs a Solidity function call using a low level `call`. A 'plaincall' is an unsafe replacement for a function call: use this function instead.
            - If `target` reverts with a revert reason, it is bubbled up by this function (like regular Solidity function calls).
            - Returns the raw returned data.
     
            Requirements:
                - `target` must be a contract.
                - calling `target` with `data` must not revert.
    */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, 'Address: low-level call failed');
    }


    //  Same as `functionCall`, but with `errorMessage` as a fallback revert reason when `target` reverts.
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }


    /*  Same as 'functionCall`, but also transferring `value` jager to `target`.
     
        Requirements:
            - the calling contract must have an BNB balance of at least `value`.
            - the called Solidity function must be `payable`.

    */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }


    // Same as `functionCallWithValue`, but with `errorMessage` as a fallback revert reason when `target` reverts.
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {        
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    
    
    // Same as `functionCall`, but performing a static call.
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }


    // Same as `functionCall` with `errorMessage`, but performing a static call.
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }


    // Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the revert reason using the provided one.
    function verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) internal pure returns (bytes memory) {
        
        if (success) {
            return returndata;
        } 
        
        else {
            
            // Look for revert reason and bubble it up if present.
            if (returndata.length > 0) {

                // The easiest way to bubble the revert reason is using memory via assembly.
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } 
            
            else {
                revert(errorMessage);
            }
        }
    }
}