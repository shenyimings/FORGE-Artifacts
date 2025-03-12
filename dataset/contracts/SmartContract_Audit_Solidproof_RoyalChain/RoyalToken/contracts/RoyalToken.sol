// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Using OpenZeppelin Implementation for security
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract RoyalToken is ERC20, ERC20Burnable, Ownable {
    using SafeERC20 for IERC20;

    string private constant name_ = "Royal Token";
    string private constant symbol_ = "ROYAL";
    uint256 private totalSupply_ = 2 * (10**11) * (10 ** uint256(decimals())); // 200,000,000,000

    constructor () ERC20(name_, symbol_) {
        _mint(msg.sender, totalSupply_);
    }

    /**
     * @notice Sends airdropped tokens via ERC20 _transfer() method from the array list of recipients and amounts
     * @param recipients Array list of addresses
     * @param amounts Array list of token amounts
     * @return bool
     */
    function airdrop(address[] calldata recipients, uint256[] calldata amounts) public onlyOwner returns (bool) {
        require(recipients.length == amounts.length, "RoyalToken: recipients and amounts must be the same length");
        for (uint i = 0; i < recipients.length; i++) {
            _transfer(_msgSender(), recipients[i], amounts[i]);
        }
        return true;
    }

    /**
     * @notice Overrides ERC20Burnable burn() method for adding "onlyOwner" identifier
     */
    function burn(uint256 amount) override public virtual onlyOwner {
        _burn(_msgSender(), amount);
    }

    /**
     * @notice Overrides ERC20Burnable burnFrom() method for adding "onlyOwner" identifier
     */
    function burnFrom(address account, uint256 amount) override public virtual onlyOwner {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
    }
}