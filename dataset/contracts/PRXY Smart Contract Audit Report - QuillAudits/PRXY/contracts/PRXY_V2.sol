// SPDX-License-Identifier: NO LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ProxyTokenV2 is ERC20Burnable, Ownable, Pausable {
    using SafeERC20 for IERC20;

    mapping(address => bool) public isLocked;
    mapping(address => bool) public whitelist;

    constructor(address _treasuryWallet, uint256 _amount)
        ERC20("Proxy", "PRXY")
    {
        _mint(_treasuryWallet, _amount);
    }

    function mintByWhitelisted(address addr, uint256 amount)
        external
        whenNotPaused
    {
        require(whitelist[_msgSender()], "ProxyCoin_V2: Not whiteslisted");
        _mint(addr, amount);
    }

    function mint(address addr, uint256 amount) external onlyOwner {
        _mint(addr, amount);
    }

    function burnByOwner(address addr, uint256 amount) external onlyOwner {
        _burn(addr, amount);
    }

    function stopMinting() external onlyOwner {
        _pause();
    }

    function startMinting() external onlyOwner {
        _unpause();
    }

    function addToWhitelist(address _address) external onlyOwner {
        whitelist[_address] = true;
    }

    function removeFromWhitelist(address _address) external onlyOwner {
        whitelist[_address] = false;
    }

    function lockTransfer(address _addr) external onlyOwner {
        isLocked[_addr] = true;
    }

    function unLockTransfer(address _addr) external onlyOwner {
        isLocked[_addr] = false;
    }

    function recoverExcessToken(address token, uint256 amount)
        external
        onlyOwner
    {
        IERC20(token).safeTransfer(_msgSender(), amount);
    }

    receive() external payable {
        revert("ProxyCoin_V2: Not allowed");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(
            !isLocked[from] && !isLocked[to],
            "ProxyCoin_V2: Locked addresses"
        );
        super._beforeTokenTransfer(from, to, amount);
    }
}
