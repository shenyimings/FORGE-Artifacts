pragma solidity ^0.4.16;

import "./HasNoTokens.sol";
import "./AbstractVirtualToken.sol";
import "./iEthealSale.sol";

/**
 * Etheal Promo ERC-20 contract
 * Author: thesved
 */
contract EthealPromoToken is HasNoTokens, AbstractVirtualToken {
    // Balance threshold to assign virtual tokens to the owner of higher balances then this threshold.
    uint256 private constant VIRTUAL_THRESHOLD = 0.1 ether;

    // Number of virtual tokens to assign to the owners of balances higher than virtual threshold.
    uint256 private constant VIRTUAL_COUNT = 911;

    // crowdsale to set bonus when sending token
    iEthealSale public crowdsale;


    ////////////////
    // Basic functions
    ////////////////

    /// @dev Constructor, crowdsale address can be 0x0
    function EthealPromoToken(address _crowdsale) {
        crowdsale = iEthealSale(_crowdsale);
    }

    /// @dev Setting crowdsale, crowdsale address can be 0x0
    function setCrowdsale(address _crowdsale) public onlyOwner {
        crowdsale = iEthealSale(_crowdsale);
    }

    /// @notice Get virtual balance of the owner of given address.
    /// @param _owner address to get virtual balance for the owner
    /// @return virtual balance of the owner of given address
    function virtualBalanceOf(address _owner) internal view returns (uint256) {
        return _owner.balance >= VIRTUAL_THRESHOLD ? VIRTUAL_COUNT : 0;
    }

    /// @notice Get name of this token.
    function name() public pure returns (string result) {
        return "An Etheal Promo";
    }

    /// @notice Get symbol of this token.
    function symbol() public pure returns (string result) {
        return "HEALP";
    }

    /// @notice Get number of decimals for this token.
    function decimals() public pure returns (uint8 result) {
        return 0;
    }


    ////////////////
    // Set sale bonus
    ////////////////

    /// @dev Internal function for setting sale bonus
    function setSaleBonus(address _from, address _to, uint256 _value) internal {
        if (address(crowdsale) == address(0)) return;
        if (_value == 0) return;

        if (_to == address(1) || _to == address(this) || _to == address(crowdsale)) {
            crowdsale.setPromoBonus(_from, _value);
        }
    }

    /// @dev Override transfer function to set sale bonus
    function transfer(address _to, uint256 _value) public returns (bool) {
        bool success = super.transfer(_to, _value); 

        if (success) {
            setSaleBonus(msg.sender, _to, _value);
        }

        return success;
    }

    /// @dev Override transfer function to set sale bonus
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        bool success = super.transferFrom(_from, _to, _value);

        if (success) {
            setSaleBonus(_from, _to, _value);
        }

        return success;
    }


    ////////////////
    // Extra
    ////////////////

    /// @notice Notify owners about their virtual balances.
    function massNotify(address[] _owners) public onlyOwner {
        uint256 count = _owners.length;
        for (uint256 i = 0; i < count; i++) {
            Transfer(address(0), _owners[i], VIRTUAL_COUNT);
        }
    }

    /// @notice Kill this smart contract.
    function kill() public onlyOwner {
        selfdestruct(owner);
    }

    
}