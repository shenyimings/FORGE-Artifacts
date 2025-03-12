// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {TokenBasic} from "./TokenBasic.sol";

// solhint-disable-next-line no-empty-blocks
contract FrockTokenV1 is TokenBasic {

    bool public isAddressSetted;
    address public reflection;
    address public treasury;
    address public marketing;

    uint256 public reflectionPercentage; // Using 2 decimals
    uint256 public treasuryPercentage; // Using 2 decimals
    uint256 public marketingPercentage; // Using 2 decimals    
    uint256 public totalTax;

    event ReflectionUpdated(address newReflectionAddress);
    event TreasuryUpdated(address newTreasuryAddress);
    event MarketingUpdated(address newMarketingAddress);
    event PercentageUpdated(uint256 reflectionPercentage,  uint256 treasuryPercentage, uint256 marketingPercentage);

    function setReflection(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        reflection = newAddress;    
        _setIsAddressSetted();    
        emit ReflectionUpdated(newAddress);
    }

    function setTreasury(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = newAddress;
        _setIsAddressSetted();
        emit TreasuryUpdated(newAddress);
    }

    function setMarketing(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        marketing = newAddress;
        _setIsAddressSetted();
        emit MarketingUpdated(newAddress);
    }

    function _setIsAddressSetted() private {
        isAddressSetted = (reflection != address(0) && treasury != address(0) && marketing != address(0));
    }

     function setPercentage(uint256 reflectionPrctg,  uint256 treasuryPrctg, uint256 marketingPrctg) external onlyRole(DEFAULT_ADMIN_ROLE) {                    
        require(reflectionPrctg + treasuryPrctg + marketingPrctg <= 22_00, "Tax: Maximal Tax is 22%");
        reflectionPercentage = reflectionPrctg;
        treasuryPercentage = treasuryPrctg;
        marketingPercentage = marketingPrctg;  
        totalTax = reflectionPrctg + treasuryPrctg + marketingPrctg;            
        emit PercentageUpdated(reflectionPrctg, treasuryPrctg, marketingPercentage);
    }


    /**
    * @dev Override transfer function to apply tax deduction
    */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        super._transfer(_msgSender(), recipient, amount);

        _taxDeduction(_msgSender(), recipient, amount);                
        
        return true;
    }


    /**
    * @dev Override transferFrom function to apply tax deduction
    */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        super.transferFrom(sender, recipient, amount);

        _taxDeduction(sender, recipient, amount);         

        return true;
    }

    function _taxDeduction(address sender, address recipient, uint256 amount) internal virtual {
        if(!(isExcludedFromFees[sender] || isExcludedFromFees[recipient])) {     
            require(isAddressSetted, "Tax : Address not set correctly");
            require(totalTax > 0, "Tax : Percentage not set correctly");
                          
            // Calculate amount
            uint256 reflectionAmount = reflectionPercentage * amount / 100_00;
            uint256 treasuryAmount = treasuryPercentage * amount / 100_00;
            uint256 marketingAmount = marketingPercentage * amount / 100_00;

            // Transfer token        
            _transfer(recipient, reflection, reflectionAmount);
            _transfer(recipient, treasury, treasuryAmount);
            _transfer(recipient, marketing, marketingAmount);            
        }                                      
    }
  
}
