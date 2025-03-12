// contracts/Box.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetFixedSupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract AskjaCoin is ERC20PresetFixedSupplyUpgradeable, OwnableUpgradeable {
    //////////////////////////////////////////////////////////////////////
    //PROD
    address public constant rusticityFee = 0x5cd2f2d30582B22b7E30965D4b78046A0A2808F6;
    mapping(address => uint256) lastTimeMinted;
    //List of accounts that do not pay fee (time vaults)
    mapping(address => bool) whiteList;
    // event coolDown
    event coolDownChanged(uint256 value);
    // coolDown period
    uint256 coolDownPeriod;
    // fee disabled
    bool feeDisabled;

    //Contructor
    function initialize(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 tokenInitialSupply,
        address tokenOwner
    ) public override initializer {
        ERC20PresetFixedSupplyUpgradeable.initialize(
            tokenName,
            tokenSymbol,
            tokenInitialSupply,
            tokenOwner
        );
        OwnableUpgradeable.__Ownable_init();
        feeDisabled = false;
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        bool isWhiteListed = isWhiteListedAddress(_msgSender());

        if (!isWhiteListed) {
            require(
                lastTimeMinted[_msgSender()] + coolDownPeriod <=
                    block.timestamp,
                "not allowed to mint under cooldown period"
            );
        }

        if (!isWhiteListed && !feeDisabled) {
            uint256 senderBalance = balanceOf(_msgSender());
            uint256 recipientBalance = balanceOf(recipient);
            ////////////////////////////////////
            // the recipient has max 2% of the total supply
            ///////////////////////////
            uint256 totatOwnerShipMax = (totalSupply() * 2) / 100;
            require(
                recipientBalance <= totatOwnerShipMax,
                Strings.toString(totalSupply())
            );
            // check the sender actually has enough tokens to send
            require(senderBalance >= amount);
            // calculate the share for the fee target address 6%
            uint256 shareForFee = (amount * 7) / 100;
            _transfer(_msgSender(), recipient, amount - shareForFee);
            _transfer(_msgSender(), rusticityFee, shareForFee);
            // add last minted
            lastTimeMinted[_msgSender()] = block.timestamp;
        } else {
            _transfer(_msgSender(), recipient, amount);
        }

        return true;
    }

    function getCoolDownAddress(address adress)
        external
        view
        virtual
        returns (uint256)
    {
        return lastTimeMinted[adress];
    }

    function getCoolDownValue() external view virtual returns (uint256) {
        return coolDownPeriod;
    }

    // the maximum value of the cooldown is set to a percentage of the total amount
    // in order to prevent anyone (including the owner) to set the cooldown to a extremely high value.
    // the max value of the cooldown is set to 300 seconds
    function setCoolDownValue(uint256 _cooldownPeriod)
        external
        virtual
        onlyOwner
        returns (uint256)
    {
        require(_cooldownPeriod < 300, "cannot set coolDown over limit");
        coolDownPeriod = _cooldownPeriod;
        emit coolDownChanged(coolDownPeriod);
        return coolDownPeriod;
    }

    // add address to the whitelisted adresses
    function addToWhiteList(address _address) external onlyOwner {
        whiteList[_address] = true;
    }

    // Checks if the adress belongs to the whitelisted adresses
    function isWhiteListedAddress(address _address) public view returns (bool) {
        return whiteList[_address];
    }

    function removeFromWhiteList(address _address) external onlyOwner {
        delete whiteList[_address];
    }

    //change value of feeDisabled
    function updateFeeDisabled(bool _feeDisabled) external onlyOwner {
        feeDisabled = _feeDisabled;
    }

    function getFeeDisabled() external view returns (bool) {
        return feeDisabled;
    }
}
