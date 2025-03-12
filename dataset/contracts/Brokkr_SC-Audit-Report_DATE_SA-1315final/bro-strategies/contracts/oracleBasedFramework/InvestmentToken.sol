// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./interfaces/IInvestmentToken.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

contract InvestmentToken is
    ContextUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    IInvestmentToken
{
    string private _name; // redeclare name prop to be able to change it
    string private _symbol; // redeclare symbol prop to be able to change it

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name_, string memory symbol_)
        public
        initializer
    {
        __Context_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ERC20_init("", "");

        _name = name_;
        _symbol = symbol_;
    }

    function mint(address account_, uint256 amount_) public virtual onlyOwner {
        _mint(account_, amount_);
    }

    function _authorizeUpgrade(
        address /* newImplementation */
    ) internal virtual override onlyOwner {}

    function burn(uint256 amount)
        public
        virtual
        override(IInvestmentToken, ERC20BurnableUpgradeable)
    {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        virtual
        override(IInvestmentToken, ERC20BurnableUpgradeable)
    {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }

    function decimals() public pure virtual override returns (uint8) {
        return 6;
    }

    function setName(string memory name_) external onlyOwner {
        _name = name_;
    }

    function setSymbol(string memory symbol_) external onlyOwner {
        _symbol = symbol_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }
}
