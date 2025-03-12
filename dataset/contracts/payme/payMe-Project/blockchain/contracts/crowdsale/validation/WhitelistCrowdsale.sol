// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../Crowdsale.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

//ROLE = INVESTOR_WHITELISTED

/**
 * @title WhitelistCrowdsale
 * @dev Crowdsale in which only whitelisted users can contribute.
 */
abstract contract WhitelistCrowdsale is AccessControl, Crowdsale {
    bytes32 INVESTOR_WHITELISTED =  0xf5ddd805fa96b7c3d4f3ea55114f966ab9aad1de73aff48d008717b66678bb36;
    /**
     * @dev Extend parent behavior requiring beneficiary to be whitelisted. Note that no
     * restriction is imposed on the account sending the transaction.
     * @param _beneficiary Token beneficiary
     * @param _weiAmount Amount of wei contributed
     */
   
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) 
    internal 
    override
    virtual
    view {
        require(hasRole(0xf5ddd805fa96b7c3d4f3ea55114f966ab9aad1de73aff48d008717b66678bb36,_beneficiary), "WhitelistCrowdsale: beneficiary doesn't have the Whitelisted role");
        super._preValidatePurchase(_beneficiary, _weiAmount);
    }

    function addWhitelisted(address account) public onlyRole(getRoleAdmin(INVESTOR_WHITELISTED)) {
        //_addWhitelisted(account);
         grantRole(INVESTOR_WHITELISTED,account);
        
    }
}
