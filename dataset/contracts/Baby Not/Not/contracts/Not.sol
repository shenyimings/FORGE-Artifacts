// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Not is ERC20, Ownable {
    uint256 private _autoBurnPercentage;
    uint256 private _feePercentage;
    address private _feeAddress;
    mapping(address => bool) private _feeExcludedAddresses;

    // Event to log changes in auto-burn percentage, fee percentage, fee address, and fee-excluded addresses
    event AutoBurnPercentageChanged(uint256 newAutoBurnPercentage);
    event FeePercentageChanged(uint256 newFeePercentage);
    event FeeAddressChanged(address newFeeAddress);
    event FeeExcludedAddressChanged(address indexed account, bool isExcluded);

    constructor() ERC20("Baby Not", "BABY NOT") {
        _mint(msg.sender, 420000000000 * 10**18); // Initial supply set to 100000000000
        _autoBurnPercentage = 1; // Default auto-burn percentage
        _feePercentage = 4;      // Default fee percentage
        _feeAddress = msg.sender; // Default fee address
        _feeExcludedAddresses[msg.sender] = true;
    }

    // Function to transfer tokens with auto-burn and fee
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        uint256 burnAmount = 0;
        if (!_feeExcludedAddresses[sender]) {
            burnAmount = (amount * _autoBurnPercentage) / 100;
            _burn(sender, burnAmount);
        }

        uint256 feeAmount = (amount * _feePercentage) / 100;
        uint256 transferAmount = amount - burnAmount - feeAmount;

        // Transfer remaining amount to the recipient
        super._transfer(sender, recipient, transferAmount);

        // Charge fee unless the sender is excluded
        if (!_feeExcludedAddresses[sender]) {
            super._transfer(sender, _feeAddress, feeAmount);
        }
    }

    // Function to change the auto-burn percentage (only callable by the owner)
    function changeAutoBurnPercentage(uint256 newAutoBurnPercentage) external onlyOwner {
        require(newAutoBurnPercentage <= 20, "Auto-burn percentage exceeds 20");
        _autoBurnPercentage = newAutoBurnPercentage;
        emit AutoBurnPercentageChanged(newAutoBurnPercentage);
    }

    // Function to change the fee percentage (only callable by the owner)
    function changeFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage <= 20, "Fee percentage exceeds 20");
        _feePercentage = newFeePercentage;
        emit FeePercentageChanged(newFeePercentage);
    }

    // Function to change the fee address (only callable by the owner)
    function changeFeeAddress(address newFeeAddress) external onlyOwner {
        _feeAddress = newFeeAddress;
        emit FeeAddressChanged(newFeeAddress);
    }

    // Function to exclude or include an address from fees (only callable by the owner)
    function setFeeExcludedAddress(address account, bool isExcluded) external onlyOwner {
        _feeExcludedAddresses[account] = isExcluded;
        emit FeeExcludedAddressChanged(account, isExcluded);
    }

    // Function to check if an address is excluded from fees
    function isFeeExcludedAddress(address account) external view returns (bool) {
        return _feeExcludedAddresses[account];
    }
}
