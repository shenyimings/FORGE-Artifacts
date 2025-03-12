// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";



/// @notice  This ERC20 contract outlines the tranche token functionality.
///          This contract should support the following functionalities:
///           - Mintable.
///           - Burnable.
///           - Inherit the ownable library to handle temporary minterRole management.
contract ZivoeTrancheToken is ERC20, Ownable {

    // ---------------------
    //    State Variables
    // ---------------------

    /// @dev Whitelist for accessibility to mint() function, exposed in isMinter() view function.
    mapping(address => bool) private _isMinter;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the TrancheToken contract ($zTT).
    /// @dev    _totalSupply for this contract initializes to 0.
    /// @param  name_   The name (Zivoe Junior Tranche, Zivoe Senior Tranche).
    /// @param  symbol_ The symbol ($zJTT, $zSTT).
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) { }



    // ------------
    //    Events
    // ------------

    /// @notice This event is emitted when changeMinterRole() is called.
    /// @param  account The account who is receiving or losing the minter role.
    /// @param  allowed If true, account receives minter privlidges, if false the account loses minter privlidges.
    event MinterUpdated(address indexed account, bool allowed);



    // ---------------
    //    Modifiers
    // ---------------

    /// @dev Enforces the caller has minter role privlidges.
    modifier isMinterRole() {
        require(_isMinter[_msgSender()], "ZivoeTrancheToken::isMinterRole() !_isMinter[_msgSender()]");
        _;
    }



    // ---------------
    //    Functions
    // ---------------

    /// @notice Returns the whitelist status of account for accessibility to mint() function.
    /// @param  account The account to inspect whitelist status.
    /// @return minter  Returns true if account is allowed to access the mint() function.
    function isMinter(address account) external view returns (bool minter) { return _isMinter[account]; }

    /// @notice Burns $zTT tokens.
    /// @param  amount The number of $zTT tokens to burn.
    function burn(uint256 amount) external { _burn(_msgSender(), amount); }

    /// @notice Update an account's permission for access to mint() function.
    /// @dev    Only callable by owner.
    /// @param  account The account to change permissions for.
    /// @param  allowed The permission to give account (true = permitted, false = prohibited).
    function changeMinterRole(address account, bool allowed) external onlyOwner {
        _isMinter[account] = allowed;
        emit MinterUpdated(account, allowed);
    }

    /// @notice Mints $zTT tokens.
    /// @dev    Only callable by accounts on the _isMinter whitelist.
    /// @param  account The account to mint tokens for.
    /// @param  amount  The amount of $zTT tokens to mint for account.
    function mint(address account, uint256 amount) external isMinterRole { _mint(account, amount); }

}
