// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/// @notice Quickly deploy an ERC20 token

import "forge-std/Script.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol, _decimals) {}

    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }
}

contract DeployERC20 is Script {
    function deploy(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    )
        public
        returns (
            address,
            string memory name,
            string memory symbol,
            uint8 decimals
        )
    {
        console2.log("Chain ID", block.chainid);

        vm.broadcast();
        MockERC20 erc20 = new MockERC20(_name, _symbol, _decimals);

        return (address(erc20), _name, _symbol, _decimals);
    }
}
