// SPDX-License-Identifier: agpl-3.0


pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract EggV2 is ERC20Burnable, ERC20Snapshot, Ownable {
    using SafeMath for uint256;

    /**
     * @dev - The maximum mintable over the lifetime.
     */
    uint256 internal _maxAmountMintable = 365_000e18;

    constructor() ERC20("EggV2", "EGGV2") {
        _mint(msg.sender, _maxAmountMintable);
    }

 
    
    /**
     * @dev - Override _burn to reduce the maximum mintable amount.
     */
    function _burn(address account, uint256 amount) internal override {
        _maxAmountMintable = _maxAmountMintable.sub(amount);
        super._burn(account, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Snapshot) {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev - Override _snapshot.
     */
    function snapshot() external onlyOwner returns (uint256) {
        return _snapshot();
    }

	/**
     * @dev - Override _mint
     */
    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}