// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IIndexToken } from "../interfaces/IIndexToken.sol";

import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract IndexToken is
    ContextUpgradeable,
    OwnableUpgradeable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    UUPSUpgradeable,
    IIndexToken
{
    string private _name; // Redeclare to make it changable.
    string private _symbol; // Redeclare to make it changable.

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name_, string memory symbol_)
        external
        initializer
    {
        __Context_init();
        __Ownable_init();
        __ERC20_init("", "");
        __ERC20Burnable_init();
        __UUPSUpgradeable_init();

        _name = name_;
        _symbol = symbol_;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function name()
        public
        view
        override(IIndexToken, ERC20Upgradeable)
        returns (string memory)
    {
        return _name;
    }

    function symbol()
        public
        view
        override(IIndexToken, ERC20Upgradeable)
        returns (string memory)
    {
        return _symbol;
    }

    function decimals()
        public
        pure
        virtual
        override(IIndexToken, ERC20Upgradeable)
        returns (uint8)
    {
        return 18;
    }

    function mint(address account_, uint256 amount_) public virtual onlyOwner {
        _mint(account_, amount_);
    }

    function burn(uint256 amount)
        public
        virtual
        override(IIndexToken, ERC20BurnableUpgradeable)
    {
        ERC20BurnableUpgradeable.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        virtual
        override(IIndexToken, ERC20BurnableUpgradeable)
    {
        ERC20BurnableUpgradeable.burnFrom(account, amount);
    }

    function setName(string memory name_) external onlyOwner {
        _name = name_;
    }

    function setSymbol(string memory symbol_) external onlyOwner {
        _symbol = symbol_;
    }
}
