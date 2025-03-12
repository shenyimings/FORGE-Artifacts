// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "@solarity/solidity-lib/libs/arrays/Paginator.sol";
import "@solarity/solidity-lib/libs/arrays/SetHelper.sol";

import "../../interfaces/gov/ERC20/IERC20Gov.sol";

contract ERC20Gov is
    IERC20Gov,
    ERC20CappedUpgradeable,
    ERC20PausableUpgradeable,
    ERC20BurnableUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using Paginator for EnumerableSet.AddressSet;
    using SetHelper for EnumerableSet.AddressSet;

    address public govAddress;

    EnumerableSet.AddressSet internal _blacklistAccounts;

    modifier onlyGov() {
        _onlyGov();
        _;
    }

    function __ERC20Gov_init(
        address _govAddress,
        ConstructorParams calldata params
    ) external initializer {
        __ERC20_init(params.name, params.symbol);
        __ERC20Capped_init(params.cap);

        require(_govAddress != address(0), "ERC20Gov: govAddress is zero");
        require(
            params.mintedTotal <= params.cap,
            "ERC20Gov: mintedTotal should not be greater than cap"
        );
        require(
            params.users.length == params.amounts.length,
            "ERC20Gov: users and amounts lengths mismatch"
        );

        govAddress = _govAddress;

        for (uint256 i = 0; i < params.users.length; i++) {
            _mint(params.users[i], params.amounts[i]);
        }

        require(totalSupply() <= params.mintedTotal, "ERC20Gov: overminting");

        _mint(_govAddress, params.mintedTotal - totalSupply());
    }

    function mint(address account, uint256 amount) external override onlyGov {
        _mint(account, amount);
    }

    function pause() external override onlyGov {
        _pause();
    }

    function unpause() external override onlyGov {
        _unpause();
    }

    function blacklist(address[] calldata accounts, bool value) external override onlyGov {
        if (value) {
            _blacklistAccounts.add(accounts);
        } else {
            _blacklistAccounts.remove(accounts);
        }
    }

    function totalBlacklistAccounts() external view override returns (uint256) {
        return _blacklistAccounts.length();
    }

    function getBlacklistAccounts(
        uint256 offset,
        uint256 limit
    ) external view override returns (address[] memory) {
        return _blacklistAccounts.part(offset, limit);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        require(
            !_blacklistAccounts.contains(from) && !_blacklistAccounts.contains(to),
            "ERC20Gov: account is blacklisted"
        );

        super._beforeTokenTransfer(from, to, amount);
    }

    function _mint(
        address account,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20CappedUpgradeable) {
        if (amount == 0) {
            return;
        }

        super._mint(account, amount);
    }

    function _onlyGov() internal view {
        require(msg.sender == govAddress, "ERC20Gov: not a Gov contract");
    }
}
