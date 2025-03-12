// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FakeWETH is ERC20 {

    constructor(string memory _name, string memory _symbol) public ERC20(_name, _symbol) {

    }

    function faucet() public {
        _mint(msg.sender, 10000 * 1e18);
    }
}


contract FakeUSDC is ERC20 {

    constructor(string memory _name, string memory _symbol) public ERC20(_name, _symbol) {

    }

    function faucet() public {
        _mint(msg.sender, 10000 * 1e18);
    }
}


contract FakeDAI is ERC20 {

    constructor(string memory _name, string memory _symbol) public ERC20(_name, _symbol) {

    }

    function faucet() public {
        _mint(msg.sender, 10000 * 1e18);
    }
}

contract FakeWBTC is ERC20 {

    constructor(string memory _name, string memory _symbol) public ERC20(_name, _symbol) {
        _setupDecimals(8);
    }

    function faucet() public {
        _mint(msg.sender, 10000 * 10**8);
    }
}

contract FakeRenBTC is ERC20 {

    constructor(string memory _name, string memory _symbol) public ERC20(_name, _symbol) {
        _setupDecimals(8);
    }

    function faucet() public {
        _mint(msg.sender, 10000 * 10**8);
    }
}

contract FakeHBTC is ERC20 {

    constructor(string memory _name, string memory _symbol) public ERC20(_name, _symbol) {
        _setupDecimals(18);
    }

    function faucet() public {
        _mint(msg.sender, 10000 * 1e18);
    }
}