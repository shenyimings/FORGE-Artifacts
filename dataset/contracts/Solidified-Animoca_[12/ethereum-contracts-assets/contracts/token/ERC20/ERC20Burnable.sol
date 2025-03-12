// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {IERC20Burnable} from "./IERC20Burnable.sol";
import {ERC20} from "./ERC20.sol";

/**
 * @title ERC20 Fungible Token Contract, burnable version.
 */
abstract contract ERC20Burnable is ERC20, IERC20Burnable {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        string memory tokenURI
    ) ERC20(name, symbol, decimals, tokenURI) {}

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC20Burnable).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev See {IERC20Burnable-burn(uint256)}.
    function burn(uint256 amount) external virtual override returns (bool) {
        _burn(_msgSender(), amount);
        return true;
    }

    /// @dev See {IERC20Burnable-burnFrom(address,uint256)}.
    function burnFrom(address from, uint256 value) external virtual override returns (bool) {
        _burnFrom(from, value);
        return true;
    }

    /// @dev See {IERC20Burnable-batchBurnFrom(address[],uint256[])}.
    function batchBurnFrom(address[] calldata owners, uint256[] calldata values) external virtual override returns (bool) {
        _batchBurnFrom(owners, values);
        return true;
    }
}
