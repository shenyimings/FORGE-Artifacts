// SPDX-License-Identifier:  MIT

pragma solidity ^0.8.9;

import "../Crowdsale.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title PausableCrowdsale
 * @dev Extension of Crowdsale contract where purchases can be paused and unpaused by the pauser role.
 */
abstract contract PausableCrowdsale is Crowdsale, Pausable,Ownable  {

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met.
     * Use super to concatenate validations.
     * Adds the validation that the crowdsale must not be paused.
     * @param _beneficiary Address performing the token purchase
     * @param _weiAmount Value in wei involved in the purchase
     */

    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) override virtual internal view whenNotPaused {
        return super._preValidatePurchase(_beneficiary, _weiAmount);
    }


        /**
     * @dev Called by a pauser to pause, triggers stopped state.
     */
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @dev Called by a pauser to unpause, returns to normal state.
     */
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }
}