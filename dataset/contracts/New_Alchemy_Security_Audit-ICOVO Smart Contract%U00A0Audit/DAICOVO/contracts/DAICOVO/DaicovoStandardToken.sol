pragma solidity ^0.4.18;

import "../token/ERC20/ERC20Standard.sol";
import "../token/ERC223/ERC223Interface.sol";
import "../token/ERC223/ERC223ReceivingContract.sol";
import "../token/extentions/MintableToken.sol";

/**
 * @title DAICOVO standard ERC20, ERC223 compliant token
 * @dev Inherited ERC20 and ERC223 token functionalities.
 * @dev Extended with forceTransfer() function to support compatibility
 * @dev with exisiting apps which expects ERC20 token's transfer function berhavior.
 */
contract DaicovoStandardToken is ERC20Standard, ERC223Standard, MintableToken {

    function DaicovoStandardToken(string _name, string _symbol, uint8 _decimals) public {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    /**
     * @dev It provides an ERC20 compatible transfer function without checking of
     * @dev target address whether it's contract or EOA address.
     * @param _to    Receiver address.
     * @param _value Amount of tokens that will be transferred.
     */
    function forceTransfer(address _to, uint _value) external returns(bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }
}



