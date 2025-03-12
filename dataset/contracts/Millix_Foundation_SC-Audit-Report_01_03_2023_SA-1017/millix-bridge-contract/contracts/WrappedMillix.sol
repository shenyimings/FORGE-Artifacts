// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * WrappedMillix is a smart contract for an ERC20 token with additional features, including pause and resume, minting and burning, and vesting restrictions. 
 * 
 * @title WrappedMillix
 * @dev Developer contact: developer@millix.com
 */

interface IMillixBridge {
    /**
     * @dev Emitted when `amount` tokens are moved from account (`from`) to millix network address (`to`)
     */
    event UnwrapMillix(address indexed from, string to, uint256 amount);

    /**
     * @dev Emitted when `amount` tokens are minted from millix transaction (`txhash`)
     */
    event MintWrappedMillix(string txhash);

    function unwrap(uint256 amount, string calldata to) external payable;
}

/// @custom:security-contact developer@millix.com
contract WrappedMillix is ERC20, Pausable, Ownable, IMillixBridge {
    uint256 public constant MAX_SUPPLY = 9 * 10**15;
    uint32 private _burnFees = 662780;
    mapping(address => bool) private _vesting;

    constructor() ERC20("WrappedMillix", "WMLX") {}
    
    /**
     * @dev Get the number of decimals for the token
     * @return {uint8} The number of decimals
     */
    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    /**
     * @dev Pause the token transfers
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the token transfers
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Mint `amount` tokens to `to`
     * @param {address} to The address to mint tokens to
     * @param {uint256} amount The amount of tokens to mint
     * @param {string} txhash The transaction hash in the millix network for the minting operation
     */
    function mint(
        address to,
        uint256 amount,
        string memory txhash
    ) public onlyOwner {
        require(
            totalSupply() + amount < MAX_SUPPLY,
            "total supply cannot be greater than 9e15"
        );
        _mint(to, amount);
        emit MintWrappedMillix(txhash);
    }

    /**
     * @dev Set the burn fees for unwrapping tokens to the millix network
     * @param {uint32} fees The burn fees
     */
    function setBurnFees(uint32 fees) public onlyOwner {
        require(fees >= 0, "burn fees cannot be negative");
        _burnFees = fees;
    }

    /**
     * @dev Get the current burn fees for unwrapping tokens to the millix network
     * @return {uint32} The current burn fees
     */
    function burnFees() public view virtual returns (uint32) {
        return _burnFees;
    }

    /**
     * @dev Check if an address is vested
     * @param {address} addr The address to check
     * @return {bool} True if the address is vested, false otherwise
     */
    function isVested(address addr) public view returns (bool) {
        return _vesting[addr];
    }

    /**
     * @dev Set the vesting state of an address
     * @param {address} addr The address to set the vesting state for
     * @param {bool} vested True if the address is vested, false otherwise
     */
    function setVestingState(address addr, bool vested) public onlyOwner {
        _vesting[addr] = vested;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        require(
            !_vesting[from],
            "address from is in the list of vesting addresses"
        );
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Unwrap `amount` tokens to the millix network address `to`
     * @param {uint256} amount The amount of tokens to unwrap
     * @param {string} to The millix network address
     */
    function unwrap(uint256 amount, string calldata to) public payable {
        require(
            msg.value >= _burnFees,
            "transaction value does not cover the MLX unwrap fees"
        );
        _burn(_msgSender(), amount);
        payable(owner()).transfer(msg.value);
        emit UnwrapMillix(_msgSender(), to, amount);
    }
}
