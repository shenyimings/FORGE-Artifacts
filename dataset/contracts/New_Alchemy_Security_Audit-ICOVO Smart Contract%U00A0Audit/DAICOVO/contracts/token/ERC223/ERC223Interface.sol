pragma solidity ^0.4.18;

/**
 * Released under the MIT license.
 * https://github.com/Dexaran/ERC223-token-standard/blob/master/LICENSE
*/

contract ERC223Interface {
    string public name;
    string public symbol;
    uint8 public decimals;

    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external constant returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value, bytes data) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

