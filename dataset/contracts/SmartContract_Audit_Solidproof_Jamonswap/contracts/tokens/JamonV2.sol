// SPDX-License-Identifier: MIT
pragma solidity =0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/IERC20MintBurn.sol";

contract JamonV2 is
    ERC20,
    ERC20Burnable,
    AccessControl,
    ERC20Permit,
    IERC20MintBurn
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;

    EnumerableSet.AddressSet private taxExent;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address internal vault;

    constructor() ERC20("JamonSwapV2", "JAMON") ERC20Permit("JamonSwapV2") {
        _mint(msg.sender, 2000000 * 10**decimals());
        vault = msg.sender;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount)
        public
        override
        onlyRole(MINTER_ROLE)
    {
        require(to != address(0x0), "Invalid address");
        require(amount > 0, "Zero amount");
        _mint(to, amount);
    }

    function setVault(address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0x0), "Invalid address");
        vault = to;
    }

    function setExent(address exent, bool set)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(exent != address(0x0), "Invalid address");
        if (set) {
            taxExent.add(exent);
        } else {
            taxExent.remove(exent);
        }
    }

    // The following functions are overrides required by Solidity.
    function transfer(address recipient, uint256 amount)
        public
        virtual
        override(ERC20, IERC20)
        returns (bool)
    {
        if (!taxExent.contains(_msgSender())) {
            uint256 toVault = amount.mul(10).div(10000); // 0.1% tax fee
            _transfer(_msgSender(), vault, toVault);
            amount -= toVault;
        }
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function burn(uint256 amount)
        public
        virtual
        override(ERC20Burnable, IERC20MintBurn)
    {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        virtual
        override(ERC20Burnable, IERC20MintBurn)
    {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(
            currentAllowance >= amount,
            "ERC20: burn amount exceeds allowance"
        );
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
    }
}
