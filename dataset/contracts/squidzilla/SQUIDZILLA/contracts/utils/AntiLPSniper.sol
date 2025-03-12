// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "./Ownable.sol";

contract AntiLPSniper is Ownable {
    bool public antiSniperEnabled = true;
    bool public tradingOpen;
    mapping(address => bool) public isBlackListed;

    function banHammer(address user) internal {
        isBlackListed[user] = true;
    }

    function updateBlacklist(address user, bool shouldBlacklist) external onlyOwner {
        isBlackListed[user] = shouldBlacklist;
    }

    function enableAntiSniper(bool enabled) external onlyOwner {
        antiSniperEnabled = enabled;
    }

    function openTrading() external virtual onlyOwner {
        require(!tradingOpen, "Trading already open");
        tradingOpen = !tradingOpen;
    }
}
