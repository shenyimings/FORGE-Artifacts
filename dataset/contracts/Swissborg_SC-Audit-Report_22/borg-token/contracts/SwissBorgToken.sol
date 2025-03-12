// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

/// @title SwissBorgToken
/// @notice This contract implements the new $BORG token.
/// @author SwissBorg
contract SwissBorgToken is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes {
    /// @notice The initial supply of $CHSB that will be migrated to $BORG.
    uint256 internal constant INITIAL_SUPPLY = 1_000_000_000 ether;
    /// @notice The number of $CHSB sent to address(0).
    uint256 internal constant BURNED_AMOUNT = 14_316_585_358 * 10**15;

    /// @notice Creates a SwissBorgToken
    /// @param _migrator The ChsbToBorgMigrator contract address which is in charge of migrating the tokens.
    constructor(address _migrator) ERC20("SwissBorg Token", "BORG") ERC20Permit("SwissBorg Token") {
        // The mint amount is the supply minus everything that has been burned and that can't be migrated.
        _mint(_migrator, INITIAL_SUPPLY - BURNED_AMOUNT);
    }

    /// @inheritdoc ERC20
    function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    /// @inheritdoc ERC20
    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    /// @inheritdoc ERC20
    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}