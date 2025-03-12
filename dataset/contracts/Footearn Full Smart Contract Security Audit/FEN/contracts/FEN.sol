pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract FEN is
    AccessControlEnumerable,
    ERC20,
    ERC20Burnable,
    Ownable,
    Pausable
{
    using SafeMath for uint256;

    uint256 private totalTokens;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("Footearn", "FEN") {
        totalTokens =   10**9 * 10**uint256(decimals()); // 1B
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    function getBurnedAmountTotal() external view returns (uint256 _amount) {
        return totalTokens.sub(totalSupply());
    }

    /**
     * @dev Add factory to mint item
     */
    function setMintFactory(address factory) public onlyOwner {
        _setupRole(MINTER_ROLE, factory);
    }

    function getTotalToken() public view returns (uint256) {
        return totalTokens;
    }

    function mint(address to, uint256 amount) public {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "Must have minter role to mint"
        );
        require(totalSupply() + amount <= totalTokens, "out of token");
        _mint(to, amount);
    }
}