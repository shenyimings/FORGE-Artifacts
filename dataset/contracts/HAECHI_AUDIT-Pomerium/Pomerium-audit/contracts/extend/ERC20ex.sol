// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/extensions/ERC20Pausable.sol';
import 'openzeppelin-solidity/contracts/security/ReentrancyGuard.sol';
import 'openzeppelin-solidity/contracts/access/Ownable.sol';
import 'openzeppelin-solidity/contracts/utils/math/SafeMath.sol';

contract ERC20ex is ERC20, Ownable, ReentrancyGuard, ERC20Pausable {
    using SafeMath for uint256;

    uint8 private _decimals = 6;

    mapping(address => uint256) private _lockAccount;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function lockTransfer(address account, uint256 lockAmount) public onlyOwner {
        uint256 prevAmount = _lockAccount[account];
        _lockAccount[account] = prevAmount.add(lockAmount);
    }

    function unlockTransfer(address account, uint256 unlockAmount) public onlyOwner {
        require(_lockAccount[account] >= unlockAmount, 'need unlock amount');
        uint256 prevAmount = _lockAccount[account];
        _lockAccount[account] = prevAmount.sub(unlockAmount);
    }

    function getLockAmount(address account) public view returns (uint256) {
        return _lockAccount[account];
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Pausable) {
        if (from != address(0)) {
            require(_lockAccount[from].add(amount) <= balanceOf(from), 'lock token check');
        }
        super._beforeTokenTransfer(from, to, amount);
    }
}
