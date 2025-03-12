pragma solidity 0.4.24;

import "../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol";
import "./VreoToken.sol";


/// @title VreoTokenBounty
/// @author Sicos et al.
contract VreoTokenBounty is Ownable {

    VreoToken public token;

    /// @dev Constructor
    /// @param _token A VreoToken
    constructor(VreoToken _token) public {
        require(address(_token) != address(0));

        token = _token;
    }

    /// @dev Distribute tokens
    /// @param _recipients A list of addresses of bounty recipients
    /// @param _amounts A list of bounty amounts 
    function distributeTokens(address[] _recipients, uint[] _amounts) public onlyOwner {
        require(_recipients.length == _amounts.length);

        for (uint i = 0; i < _recipients.length; ++i) {
            token.transfer(_recipients[i], _amounts[i]);
        }
    }

}
