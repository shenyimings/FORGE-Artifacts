// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract MockERC20 is ERC20, AccessControl {
    uint8 private immutable _decimals;

    bool private _useWhitelist;

    mapping(address => bool) private _whitelist;

    modifier whitelisted() {
        require(!_useWhitelist || _whitelist[tx.origin]);
        _;
    }

    constructor(string memory symbol, uint8 decimals_) ERC20(symbol, symbol) {
        _decimals = decimals_;
        _whitelist[msg.sender] = true;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(uint256 amount) external whitelisted {
        _mint(msg.sender, amount);
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        whitelisted
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override whitelisted returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    function toggleWhitelist() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _useWhitelist = !_useWhitelist;
    }

    function whitelist(bool status, address[] calldata addresses)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256 len = addresses.length;
        for (uint256 i; i < len; i++) {
            _whitelist[addresses[i]] = status;
        }
    }
}
