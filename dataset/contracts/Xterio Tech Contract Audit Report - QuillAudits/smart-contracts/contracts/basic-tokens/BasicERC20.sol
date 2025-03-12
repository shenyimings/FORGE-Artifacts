// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./management/GatewayGuarded.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IGateway.sol";
import "./interfaces/IBasicERC20.sol";

contract BasicERC20 is
    IBasicERC20,
    ERC20,
    ERC20Burnable,
    GatewayGuarded,
    Pausable
{
    uint8 private _decimals;

    /**
     * @param gateway Gateway contract of the ERC20 contract.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimal,
        address gateway
    ) ERC20(name, symbol) GatewayGuarded(gateway) {
        _decimals = decimal;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external override onlyGateway {
        _mint(to, amount);
    }

    function pause() external onlyGateway {
        _pause();
    }

    function unpause() external onlyGateway {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}
