// SPDX-License-Identifier: ISC

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.4;


contract ParmaFanToken is ERC20, Ownable {

    uint initialSupply = 20_000_000 ether;

    mapping(address => bool) private _blacklistAddress;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol){
        _mint(_msgSender(), initialSupply);
    }

    /**
    * @dev Add address to blacklist
    * Can only be called by the current owner.
    */
    function addAddressToBlacklist(address addressToAdd_) external onlyOwner() {
        _blacklistAddress[addressToAdd_] = true;
    }

    /**
    * @dev Remove address to blacklist
    * Can only be called by the current owner.
    */
    function removeAddressFromBlacklist(address addressToRemove_) external onlyOwner() {
        _blacklistAddress[addressToRemove_] = false;
    }

    /**
    * @dev Return `true` if address is blacklisted
    */
    function isBlacklisted(address addressToCheck_) public view returns(bool) {
        return _blacklistAddress[addressToCheck_];
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!isBlacklisted(from), "ParmaFanToken: Transfer not allowed");
        require(!isBlacklisted(to), "ParmaFanToken: Transfer not allowed");
    }


}
