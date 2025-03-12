// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
import "../utilities/Initializable.sol";
import "../utilities/Context.sol";



/* Contract module which allows children to implement an emergency stop mechanism that can be triggered by an authorized account.
        - This module is used through inheritance. 
        - It will make available the modifiers `whenNotPaused` and `whenPaused`, which can be applied to the functions of your contract. 
        - Note that they will not be pausable by simply including this module, only once the modifiers are put in place.              
*/
abstract contract Pausable is Initializable, Context {
    
    // Emitted when the pause is triggered by `account`.
    event Paused(address account);

    // Emitted when the pause is lifted by `account`.
    event Unpaused(address account);

    bool private _paused;


    // Initializes the contract in unpaused state.
    function __Pausable_init() internal initializer {
        __Context_init_unchained();
        __Pausable_init_unchained();
    }
    
    
    // Initializes the contract in unpaused state.
    function __Pausable_init_unchained() internal initializer {
        _paused = false;
    }


    // Returns true if the contract is paused, and false otherwise.
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    
    // Modifier to make a function callable only when the contract is not paused. (The contract must not be paused)
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }


    // Modifier to make a function callable only when the contract is paused. (The contract must be paused)
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }


    // Triggers stopped state. (The contract must not be paused)
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }


    // Returns to normal state. (The contract must be paused)
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }    
    
    uint256[49] private __gap;
}