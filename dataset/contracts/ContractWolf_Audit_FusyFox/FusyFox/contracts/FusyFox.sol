//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OFTV2} from "@layerzerolabs/solidity-examples/contracts/token/oft/v2/OFTV2.sol";

uint8 constant DECIMALS = 10;
uint256 constant CROSSCHAIN_TOTAL_SUPPLY = 1_000_000_000 * 10 ** DECIMALS;

contract FusyFox is OFTV2, ERC20Capped {
    constructor(
        uint256 initialSupply,
        address owner,
        address layerZeroEndpoint
    )
        ERC20Capped(CROSSCHAIN_TOTAL_SUPPLY)
        OFTV2("FusyFox", "FOX", DECIMALS, layerZeroEndpoint)
    {
        if (initialSupply != 0) _mint(owner, initialSupply);
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    function _mint(
        address account,
        uint amount
    ) internal virtual override(ERC20, ERC20Capped) {
        ERC20Capped._mint(account, amount);
    }
}
