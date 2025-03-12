pragma solidity 0.6.8;

import "./BEP20.sol";

contract HawkToken is BEP20('Hawk Token', 'HAW') {
    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }    

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}