// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BUSD is ERC20, Ownable, ReentrancyGuard {
    address private refWalletAddress;

    constructor(address _refWalletAddress) ERC20("Reflection BUSD", "BUSD") {
        require(_refWalletAddress != address(0), "Zero Ref Address");
        refWalletAddress = _refWalletAddress;
    }

    function setRefWalletAddress(address _refWalletAddress) external onlyOwner {
        require(_refWalletAddress != address(0), "Zero Ref Address");
        refWalletAddress = _refWalletAddress;
    }

    modifier onlyRefWalletAddress() {
        require(msg.sender == refWalletAddress, "Only ref wallet");
        _;
    }

    function mint(address to, uint256 _amount) external onlyRefWalletAddress {
        _mint(to, _amount);
    }

    function burn(address from, uint256 _amount) external onlyRefWalletAddress {
        _burn(from, _amount);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    receive() external payable {
        revert();
    }
}
