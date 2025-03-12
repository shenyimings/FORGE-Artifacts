// SPDX-License-Identifier: MIT

/**
 __      __  _____ _______________________________________   
/  \    /  \/  _  \\______   \______   \_   _____/\______ \  
\   \/\/   /  /_\  \|       _/|     ___/|    __)_  |    |  \ 
 \        /    |    \    |   \|    |    |        \ |    `   \
  \__/\  /\____|__  /____|_  /|____|   /_______  //_______  /
       \/         \/       \/                  \/         \/ 
 */

pragma solidity 0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ITaxHandler} from "./interfaces/ITaxHandler.sol";
import {ITreasuryHandler} from "./interfaces/ITreasuryHandler.sol";

/// @notice WARPED token contract
/// @dev extends standard ERC20 contract
contract WarpedToken is ERC20, Ownable {
    uint8 private constant _DECIMALS = 18;
    uint256 private constant _T_TOTAL = 10_000_000_000 * 10 ** _DECIMALS;
    string private constant _NAME = "WARPED";
    string private constant _SYMBOL = "WARPED";

    uint256 private constant _NOT_IN_TAX_PROCESSING = 1;
    uint256 private constant _TAX_PROCESSING = 2;

    uint256 private _tax_processing_status = _NOT_IN_TAX_PROCESSING;

    /// @notice Tax handler address
    ITaxHandler public taxHandler;
    /// @notice Treasury handler address
    ITreasuryHandler public treasuryHandler;

    /// @notice Emitted when tax handler contract is updated.
    event TaxHandlerUpdated(address newAddress);

    /// @notice Emitted when tax handler contract is updated.
    event TreasuryHandlerUpdated(address newAddress);

    /// @notice Constructor of WARPED token contract
    /// @dev initialize with tax and treasury handler addresses.
    /// @param deployerAddress deployer address to receive total supply
    /// @param taxHandlerAddress tax handler contract address
    /// @param treasuryHandlerAddress treasury handler contract address
    constructor(
        address deployerAddress,
        address taxHandlerAddress,
        address treasuryHandlerAddress
    ) ERC20(_NAME, _SYMBOL) {
        require(deployerAddress != address(0), "Deployer is zero address");
        require(taxHandlerAddress != address(0), "taxHandler is zero address");
        require(treasuryHandlerAddress != address(0), "treasuryHandler is zero address");
        taxHandler = ITaxHandler(taxHandlerAddress);
        treasuryHandler = ITreasuryHandler(treasuryHandlerAddress);

        _mint(deployerAddress, _T_TOTAL);
    }

    modifier skipWhenTaxProcessing() {
        if (_tax_processing_status == _TAX_PROCESSING) {
            return;
        }

        _tax_processing_status = _TAX_PROCESSING;
        _;

        _tax_processing_status = _NOT_IN_TAX_PROCESSING;
    }

    /**
     * @notice Update tax handler
     * @param taxHandlerAddress address of tax handler contract.
     */
    function updateTaxHandler(address taxHandlerAddress) external onlyOwner {
        require(taxHandlerAddress != address(0x00), "Zero tax handler address");
        require(taxHandlerAddress != address(taxHandler), "Same tax handler address");

        taxHandler = ITaxHandler(taxHandlerAddress);
        emit TaxHandlerUpdated(taxHandlerAddress);
    }

    /**
     * @notice Update treasury handler
     * @param treasuryHandlerAddress address of treasury handler contract.
     */
    function updateTreasuryHandler(address treasuryHandlerAddress) external onlyOwner {
        require(treasuryHandlerAddress != address(0x00), "Zero treasury handler address");
        require(treasuryHandlerAddress != address(treasuryHandler), "Same treasury handler address");

        treasuryHandler = ITreasuryHandler(treasuryHandlerAddress);
        emit TreasuryHandlerUpdated(treasuryHandlerAddress);
    }

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     * forward into beforeTokenTransferHandler function of treasury handler
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override skipWhenTaxProcessing {
        treasuryHandler.processTreasury(from, to, amount);
    }

    /**
     * @dev See {ERC20-_afterTokenTransfer}.
     * calculate tax, reward, and burn amount using tax handler and transfer using _transfer function
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal override skipWhenTaxProcessing {
        if (from == address(0x0)) {
            // skip for mint
            return;
        }

        uint256 taxAmount;
        taxAmount = taxHandler.getTax(from, to, amount);
        if (taxAmount > 0) {
            _transfer(to, address(treasuryHandler), taxAmount);
        }
    }
}
