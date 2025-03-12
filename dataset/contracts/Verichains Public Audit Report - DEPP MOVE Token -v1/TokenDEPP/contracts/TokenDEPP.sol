//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract TokenDEPP is ERC20Burnable {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => uint256) private lockBalances;

    EnumerableSet.AddressSet private operatorAccounts;

    uint256 public unlockPercent;

    address private immutable owner;

    modifier onlyOperatorAccount() {
        require(operatorAccounts.contains(msg.sender), "Only operator accounts");
        _;
    }

    modifier onlyOwner() {
        require(_msgSender() == owner, "Only owner accounts");
        _;
    }

    constructor(address[] memory accounts) ERC20("DEPP", "DEPP") {
        _mint(_msgSender(), 350_000_000 * 10**18);

        owner = _msgSender();

        unlockPercent = 0;

        for (uint256 i = 0; i < accounts.length; i++) {
            operatorAccounts.add(accounts[i]);
        }
    }

    function addOperatorAccount(address account) external onlyOwner {
        operatorAccounts.add(account);
    }

    function removeOperatorAccount(address account) external onlyOwner {
        operatorAccounts.remove(account);
    }

    function setUnlockPercent(uint256 percent) external onlyOperatorAccount {
        require(percent <= 100);
        unlockPercent = percent;
    }

    function burn(address account, uint256 amount) external onlyOperatorAccount {
        _burn(account, amount);
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        if (unlockPercent < 100) {
            uint256 locked = (lockBalances[msg.sender] * (100 - unlockPercent)) / 100;
            require(balanceOf(msg.sender) - locked >= amount, "Unlocked balance is not enough");
        }

        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        if (unlockPercent < 100) {
            uint256 locked = (lockBalances[from] * (100 - unlockPercent)) / 100;
            require(balanceOf(from) - locked >= amount, "Unlocked balance is not enough");
        }

        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function transferAndLock(address to, uint256 amount) public onlyOperatorAccount returns (bool) {
        _transfer(msg.sender, to, amount);
        lockBalances[to] = lockBalances[to] + amount;
        return true;
    }

    function transferFromAndUnlock(
        address from,
        address to,
        uint256 amount
    ) public onlyOperatorAccount returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);

        uint256 locked = (lockBalances[from] * (100 - unlockPercent)) / 100;
        if (locked > amount) {
            lockBalances[from] = ((locked - amount) * 100) / unlockPercent;
        } else {
            lockBalances[from] = 0;
        }
        return true;
    }
}
