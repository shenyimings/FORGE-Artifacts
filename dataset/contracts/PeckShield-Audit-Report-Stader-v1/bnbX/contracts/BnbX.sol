// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./interfaces/IBnbX.sol";

contract BnbX is IBnbX, ERC20Upgradeable, AccessControlUpgradeable {
    /// @dev This Role is provided to StakeManager contract to mint/burn BnbX tokens
    bytes32 public constant PREDICATE_ROLE = keccak256("PREDICATE_ROLE");
    address private stakeManager;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _manager) external override initializer {
        __AccessControl_init();
        __ERC20_init("Liquid Staking BNB", "BNBx");

        require(_manager != address(0), "zero address provided");

        _setupRole(DEFAULT_ADMIN_ROLE, _manager);
    }

    function mint(address _account, uint256 _amount)
        external
        override
        onlyRole(PREDICATE_ROLE)
    {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount)
        external
        override
        onlyRole(PREDICATE_ROLE)
    {
        _burn(_account, _amount);
    }

    function setStakeManager(address _address)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(stakeManager != _address, "Old address == new address");
        require(_address != address(0), "zero address provided");

        _revokeRole(PREDICATE_ROLE, stakeManager);
        stakeManager = _address;
        _setupRole(PREDICATE_ROLE, _address);

        emit SetStakeManager(_address);
    }
}
