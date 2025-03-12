// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/**
 * @title indu4.0 ERC-20 Smart Contract
 * @author indu4.0 AG <token@indu40.io>
 * @notice The INDU token serves as a payment token for usage
 * and advertising on the indu4.0 platform.
 * @dev You can cut out 10 opcodes in the creation-time EVM bytecode
 * if you declare a constructor `payable`. For more in-depth information
 * see here: https://forum.openzeppelin.com/t/a-collection-of-gas-optimisation-tricks/19966/5.
 * @custom:security-contact Kay Baur <security@indu40.com>
 */
contract Indu40 is ERC20Capped, ERC20Burnable, Ownable, ERC20Permit {
    /**
     * @dev Creates an initial amount of INDU tokens for the `multisig_` address.
     */
    constructor(address multisig_, uint256 amount_, uint256 cap_)
        payable
        ERC20("indu4.0", "INDU")
        ERC20Capped(cap_ * 10 ** decimals())
        ERC20Permit("indu4.0")
    {
        _mint(multisig_, amount_ * 10 ** decimals());
        _transferOwnership(multisig_);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev The following function override is required by Solidity.
     */
    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        super._mint(account, amount);
    }
}
