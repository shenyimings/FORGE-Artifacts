// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title KentaToken
 * @dev Implementation of an ERC20 token with additional features.
 */
contract KentaToken is ERC20Pausable, Ownable {
    uint256 constant TOTAL_SUPPLY = 120 * 10**9 * 10**18;
    uint256 constant TAX_FEE = 2; // 2% tax fee

    address public taxWallet = 0xc5403ee71Ac5d637FFd870A24AFF0773DB1B017A;

    event FunctionCalled(string functionName);
    event TransferWithTax(address indexed sender, address indexed recipient, uint256 amount, uint256 taxAmount);

    /**
     * @dev Constructor that assigns the total supply to the creator of the contract.
     */
    constructor() ERC20("Kenta", "KENTA") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    /**
     * @dev Changes the tax wallet address.
     * @param _taxWallet The address of the new tax wallet.
     */
    function setTaxWallet(address _taxWallet) public onlyOwner {
        require(_taxWallet != address(0), "Invalid address");
        taxWallet = _taxWallet;
        emit FunctionCalled("SetTaxWallet");
    }

    /**
     * @dev Burns an amount of tokens.
     * @param amount The amount to burn.
     */
    function burn(uint256 amount) public onlyOwner {
        _burn(msg.sender, amount);
        emit FunctionCalled("Burn");
    }

    /**
     * @dev Renounces ownership of the contract.
     */
    function renounceOwnership() public virtual override onlyOwner {
        super.renounceOwnership();
        emit FunctionCalled("RenounceOwnership");
    }

    /**
     * @dev Pauses token transfers.
     */
    function pause() public onlyOwner {
        _pause();
        emit FunctionCalled("Pause");
    }

    /**
     * @dev Resumes token transfers after a pause.
     */
    function unpause() public onlyOwner {
        _unpause();
        emit FunctionCalled("Unpause");
    }

    /**
     * @dev Returns the maximum purchase limit, which is 1% of the total supply.
     */
    function getMaxPurchaseLimit() public view returns (uint256) {
        return totalSupply() / 100;
    }

    /**
     * @dev Carries out a token transfer considering the tax.
     * @param sender The address of the sender.
     * @param recipient The address of the recipient.
     * @param amount The amount to transfer.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        require(amount > 0, "Amount must be greater than 0");
        if (sender != owner()) {
            require(amount <= getMaxPurchaseLimit(), "Amount exceeds the 1% total supply limit");
        }

        uint256 taxAmount = (amount * TAX_FEE) / 100;
        uint256 amountAfterTax = amount - taxAmount;

        super._transfer(sender, taxWallet, taxAmount); // Transfer of the tax
        super._transfer(sender, recipient, amountAfterTax);

        emit TransferWithTax(sender, recipient, amountAfterTax, taxAmount);
    }
}
