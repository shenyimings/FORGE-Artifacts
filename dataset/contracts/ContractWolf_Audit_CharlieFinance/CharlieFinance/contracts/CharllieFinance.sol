// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CharlieFinance is ERC20, ERC20Burnable, Ownable {
    uint256 public taxPercent = 3;
    uint256 public burnPercent = 2;
    address public taxRecipient;

    mapping(address => bool) public pausedWallets;
    mapping(address => bool) public taxFreeWallets;

    constructor(address _taxRecipient) ERC20("Charlie Finance", "CHT") {
        require(_taxRecipient != address(0), "Invalid tax recipient");

        taxRecipient = _taxRecipient;
        _mint(msg.sender, 10000000000 * 10**9);
    }

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    function setTaxRecipient(address _taxRecipient) external onlyOwner {
        require(_taxRecipient != address(0), "Invalid tax recipient");
        taxRecipient = _taxRecipient;
    }

    function pauseWallet(address _wallet) external onlyOwner {
        _setPausedWallet(_wallet, true);
    }

    function unpauseWallet(address _wallet) external onlyOwner {
        _setPausedWallet(_wallet, false);
    }

    function _setPausedWallet(address _wallet, bool _paused) private {
        pausedWallets[_wallet] = _paused;
    }

    function addTaxFreeWallet(address _wallet) external onlyOwner {
        _setTaxFreeWallet(_wallet, true);
    }

    function removeTaxFreeWallet(address _wallet) external onlyOwner {
        _setTaxFreeWallet(_wallet, false);
    }

    function _setTaxFreeWallet(address _wallet, bool _taxFree) private {
        taxFreeWallets[_wallet] = _taxFree;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transferWithFees(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transferWithFees(sender, recipient, amount);
        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);
        return true;
    }

    function _transferWithFees(address sender, address recipient, uint256 amount) private {
        require(!pausedWallets[sender], "Sender wallet is paused");
        require(!pausedWallets[recipient], "Recipient wallet is paused");

        require(balanceOf(sender) >= amount, "ERC20: transfer amount exceeds balance");

        uint256 burnAmount = (amount * burnPercent) / 100;
        uint256 taxAmount = taxFreeWallets[sender] ? 0 : (amount * taxPercent) / 100;
        uint256 transferAmount = amount - burnAmount - taxAmount;

        _burn(sender, burnAmount);
        _transfer(sender, taxRecipient, taxAmount);
        _transfer(sender, recipient, transferAmount);
    }

    function withdrawNativeCoins() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function withdrawTokens(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        token.transfer(owner(), token.balanceOf(address(this)));
    }

    receive() external payable {}
}