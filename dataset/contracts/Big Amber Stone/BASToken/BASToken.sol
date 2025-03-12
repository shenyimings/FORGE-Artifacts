// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./IERC20.sol";
import "./ERC20.sol";
import "./SafeERC20.sol";
import "./Ownable.sol";
import "./Address.sol";
import "./Context.sol";
import "./Pausable.sol";
import "./SafeMath.sol";
import "./MinterRole.sol";


contract BASToken is Context, Ownable, Pausable, ERC20, MinterRole {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    mapping(address => bool) private _isBlackListed;

    constructor() ERC20("Big Amber Stone", "BAS") public {

    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(!_isBlackListed[_msgSender()], "account is blacklisted");

        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(!_isBlackListed[sender], "account is blacklisted");

        return super.transferFrom(sender, recipient, amount);
    }

    function burn(uint256 amount) public override returns (bool){
        require(!_isBlackListed[_msgSender()], "account is blacklisted");
        _burn(_msgSender(), amount);
        return true;
    }

    function burnFrom(address account, uint256 amount) public override returns (bool) {
        require(!_isBlackListed[account], "account is blacklisted");
        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(amount, "ERC20: burn amount exceeds allowance");

        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
        return true;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address account, uint256 amount) public onlyMinter returns (bool) {
        _mint(account, amount);
        return true;
    }

    function addBlackList(address account) public onlyOwner {
        _isBlackListed[account] = true;
    }

    function removeBlackList(address account) public onlyOwner {
        _isBlackListed[account] = false;
    }

    function isBlackListed(address account) public view returns (bool) {
        return _isBlackListed[account];
    }

    function destroyBlackFunds(address account, uint256 amount) public onlyOwner {
        require(_isBlackListed[account], "account is not blacklisted");
        _burn(account, amount);
    }

    // Added to support recovering ERC20 token from other systems
    function recoverERC20(address tokenAddress, uint256 tokenAmount, address to) public onlyOwner {
        require(IERC20(tokenAddress).balanceOf(address(this)) >= tokenAmount, "not enough token balance");
        IERC20(tokenAddress).safeTransfer(to, tokenAmount);
    }

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - minted tokens must not cause the total supply to go over the cap.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        // contract is not paused for mine, transfer, or burn
        require(!paused(), "ERC20Pausable: token transfer while paused");
    }

}