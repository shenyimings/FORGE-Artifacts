// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import './pasuable.sol';
import './IERC20Metadata.sol';
import './ownable.sol';
import './ERC20.sol';
import './burnable.sol';
import './locker.sol';

     /**
     * CIRI Callers
     */

contract CIRI is Pausable, Ownable, Burnable, Lockable, ERC20 {
    uint256 private constant _initialSupply = 10_000_000_000e18;

    constructor() ERC20("CIRI", "CIRI") {
        _mint(_msgSender(), _initialSupply);
    }

    /**
     * @dev lock and pause before transfer token
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        super._beforeTokenTransfer(from, to, amount);

        require(!isLocked(from), "Lockable: token transfer from locked account");
        require(!isLocked(to), "Lockable: token transfer to locked account");
        require(!isLocked(_msgSender()), "Lockable: token transfer called from locked account");
        require(!paused(), "Pausable: token transfer while paused");
      
    }

    /**
     * @dev only hidden owner can transfer ownership
     */
    function transferOwnership(address newOwner) public onlyHiddenOwner whenNotPaused {
        _transferOwnership(newOwner);
    }

    /**
     * @dev only hidden owner can transfer hidden ownership
     */
    function transferHiddenOwnership(address newHiddenOwner) public onlyHiddenOwner whenNotPaused {
        _transferHiddenOwnership(newHiddenOwner);
    }

    /**
     * @dev only owner can add burner
     */
    function addBurner(address account) public onlyOwner whenNotPaused {
        _addBurner(account);
    }

    /**
     * @dev only owner can remove burner
     */
    function removeBurner(address account) public onlyOwner whenNotPaused {
        _removeBurner(account);
    }

    /**
     * @dev burn burner's coin
     */
    function burn(uint256 amount) public onlyBurner whenNotPaused {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev pause all coin transfer
     */
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @dev unpause all coin transfer
     */
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @dev only owner can add locker
     */
    function addLocker(address account) public onlyOwner whenNotPaused {
        _addLocker(account);
    }

    /**
     * @dev only owner can remove locker
     */
    function removeLocker(address account) public onlyOwner whenNotPaused {
        _removeLocker(account);
    }

    /**
     * @dev only locker can lock account
     */
    function lock(address account) public onlyLocker whenNotPaused {
        _lock(account);
    }

    /**
     * @dev only locker can unlock account
     */
    function unlock(address account) public onlyLocker whenNotPaused {
        _unlock(account);
    }

}