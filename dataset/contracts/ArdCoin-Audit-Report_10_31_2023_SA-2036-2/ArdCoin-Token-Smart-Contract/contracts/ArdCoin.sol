// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

/// @notice ArdCoin ERC20 Token
/// @notice Token Smart Contract has been written with centralized/versatile controls in mind
/// @notice Token Smart Contract has "Access Control System" to have an architecture of having other smart contracts as extended business logic
/// @notice Access Control System adds more clear authorization and versatility than Ownership Model
/// @notice Admin of contract will be a Multisignature Wallet
/// @dev Standard ERC20 Smart Contract with OpenZeppelin Presets
/// @author mnkhod.dev
contract ArdCoin is ERC20, ERC20Burnable, ERC20Snapshot, AccessControl, Pausable, ERC20Permit, ERC20Votes {

    /// @notice Smart Contract Feature Roles
    /// @dev Every feature has its own roles for versatility and responsibility scoping in mind 
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BLACKLIST_ROLE = keccak256("BLACKLIST_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Feature allows blacklisting addresses
    /// @notice Stops blacklisted addresses from transfering their ARDX tokens
    /// @dev Feature is used in _beforeTokenTransfer function that is called in transfer functions
    mapping(address => bool) private _blacklist;

    /// @notice Creator Address of contract has all the access roles
    /// @dev Feature responsibility scoping will be migrated to other addresses in the future
    /// @dev Creator Address of contract will be a Multisignature Wallet
    constructor() ERC20("ArdCoin", "ARDX") ERC20Permit("ArdCoin") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SNAPSHOT_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BLACKLIST_ROLE, msg.sender);
    }

    /// @notice Utility function to check if an address is blacklisted or not
    function isBlackListed(address user) public view returns (bool) {
        return _blacklist[user];
    }

    /// @notice Blacklist State Update Function
    /// @dev Remember that non-blacklisted addresses already has a default value of false
    /// @dev Setting an address as true boolean state means the address will be blacklisted
    function blackListUpdate(address user, bool value) public virtual onlyRole(BLACKLIST_ROLE) {
        _blacklist[user] = value;
    }

    /// @notice OpenZeppelin ERC20Snapshot Preset function
    function snapshot() public onlyRole(SNAPSHOT_ROLE) {
        _snapshot();
    }

    /// @notice OpenZeppelin ERC20Snapshot Preset function
    function getCurrentSnapshot() public view onlyRole(SNAPSHOT_ROLE) returns(uint256) {
        return _getCurrentSnapshotId();
    }

    /// @notice OpenZeppelin Pausable Preset function
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice OpenZeppelin Pausable Preset function
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice OpenZeppelin ERC20 function
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /// @notice OpenZeppelin ERC20 hook function
    /// @dev Added isBlackListed utility function calls to check if from/to address has been blacklisted or not
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override(ERC20, ERC20Snapshot)
    {
        require (!isBlackListed(from), "Token transfer refused. Sender is on blacklist");
        require (!isBlackListed(to), "Token transfer refused. Receiver is on blacklist");

        super._beforeTokenTransfer(from, to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

}
