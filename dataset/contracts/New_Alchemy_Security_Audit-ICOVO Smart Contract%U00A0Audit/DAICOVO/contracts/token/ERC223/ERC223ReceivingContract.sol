pragma solidity ^0.4.18;

/**
 * Released under the MIT license.
 * https://github.com/Dexaran/ERC223-token-standard/blob/master/LICENSE
*/


/**
 * @title Contract that will work with ERC223 tokens.
 */
 
contract ERC223ReceivingContract { 
/**
 * @dev Standard ERC223 function that will handle incoming token transfers.
 *
 * @param _from  Token sender address.
 * @param _value Amount of tokens.
 * @param _data  Transaction metadata.
 */
    function tokenFallback(address _from, uint _value, bytes _data) public;
}
