// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MelodityGovernance is
    ERC20,
    ERC20Permit,
    ERC20Votes,
    ERC20Wrapper,
    Ownable
{
    address public _dao;

    // control switch for whitelist and blacklist, this are used *ONLY* to
    // avoid dex listing prior to the release time
    bool public isWhitelistEnabled;
    bool public isBlacklistEnabled;
    mapping(address => bool) public whitelist;
    mapping(address => bool) public blacklist;

    modifier onlyOwnerOrDAO() {
        require(msg.sender == _dao || msg.sender == owner(), "Unauthorized");
        _;
    }

    modifier isWhitelisted(address recipient) {
        // whitelist not enabled => everyone pass
        // address in whitelist has assigned true => pass
        if (isWhitelistEnabled && !whitelist[recipient]) {
            revert("Recipient not whitelisted");
        }
        _;
    }

    modifier isBlacklisted(address recipient) {
        // blacklist not enabled => everyone pass
        // address in blacklist has assigned true => block
        if (isBlacklistEnabled && blacklist[recipient]) {
            revert("Recipient blacklisted");
        }
        _;
    }

    constructor(IERC20 wrappedToken)
        ERC20("Melodity governance", "gMELD")
        ERC20Permit("Melodity governance")
        ERC20Wrapper(wrappedToken)
    {
        // enables whitelist by default
        isWhitelistEnabled = true;
    }

    // The functions below are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
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

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    )
        public
        override
        isWhitelisted(recipient)
        isBlacklisted(recipient)
        returns (bool)
    {
        return ERC20.transferFrom(sender, recipient, amount);
    }

    function safeTransferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public isWhitelisted(recipient) isBlacklisted(recipient) returns (bool) {
        return ERC20.transferFrom(sender, recipient, amount);
    }

    function depositFor(address account, uint256 amount)
        public
        pure
        override
        returns (bool)
    {
        revert("Unimplemented method");
    }

    function withdrawTo(address account, uint256 amount)
        public
        pure
        override
        returns (bool)
    {
        revert("Unimplemented method");
    }

    function wrap(uint256 amount) public returns (bool) {
        return ERC20Wrapper.depositFor(msg.sender, amount);
    }

    function enableWhitelist() public onlyOwnerOrDAO {
        isWhitelistEnabled = true;
        isBlacklistEnabled = false;
    }

    function disableWhitelist() public onlyOwnerOrDAO {
        isWhitelistEnabled = false;
    }

    function enableBlacklist() public onlyOwnerOrDAO {
        isWhitelistEnabled = false;
        isBlacklistEnabled = true;
    }

    function disableBlacklist() public onlyOwnerOrDAO {
        isBlacklistEnabled = false;
    }

    function addToWhitelist(address _addr, bool whitelisted)
        public
        onlyOwnerOrDAO
    {
        whitelist[_addr] = whitelisted;
    }

    function addToBlacklist(address _addr, bool blacklisted)
        public
        onlyOwnerOrDAO
    {
        blacklist[_addr] = blacklisted;
    }
}