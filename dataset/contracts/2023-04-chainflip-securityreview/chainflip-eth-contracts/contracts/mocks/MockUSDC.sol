pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title    Token
 * @dev      Creates a mock USDC contract just for the internal network testing
 */
contract MockUSDC is ERC20 {
    address public blacklister;
    mapping(address => bool) internal blacklisted;

    constructor(string memory name, string memory symbol, uint256 mintAmount) ERC20(name, symbol) {
        _mint(msg.sender, mintAmount);
        blacklister = msg.sender;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // Override OZ's transfer function to add blacklist functionality
    function transfer(
        address to,
        uint256 amount
    ) public virtual override notBlacklisted(msg.sender) notBlacklisted(to) returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function blacklist(address _account) external onlyBlacklister {
        blacklisted[_account] = true;
    }

    function unBlacklist(address _account) external onlyBlacklister {
        blacklisted[_account] = false;
    }

    function isBlacklisted(address _account) external view returns (bool) {
        return blacklisted[_account];
    }

    modifier notBlacklisted(address _account) {
        require(!blacklisted[_account], "Blacklistable: account is blacklisted");
        _;
    }
    modifier onlyBlacklister() {
        require(msg.sender == blacklister, "Blacklistable: caller is not the blacklister");
        _;
    }
}
