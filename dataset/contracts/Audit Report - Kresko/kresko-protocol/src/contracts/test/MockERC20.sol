// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    mapping(address => bool) public minters;
    address public owner;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply
    ) ERC20(_name, _symbol, _decimals) {
        _mint(msg.sender, _initialSupply);
        minters[msg.sender] = true;
    }

    function reinitializeERC20(string memory _name, string memory _symbol) external {
        require(msg.sender == owner, "!owner");
        name = _name;
        symbol = _symbol;
    }

    function toggleMinters(address[] calldata _minters) external {
        require(minters[msg.sender], "!minter");
        for (uint256 i; i < _minters.length; i++) {
            minters[_minters[i]] = !minters[_minters[i]];
        }
    }

    function mint(address to, uint256 value) public virtual {
        require(minters[msg.sender], "!minter");
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        require(minters[msg.sender], "!minter");
        _burn(from, value);
    }
}
