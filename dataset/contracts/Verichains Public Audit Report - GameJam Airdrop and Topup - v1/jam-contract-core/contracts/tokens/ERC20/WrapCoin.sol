// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WrapCoin is ERC20 {
    event Deposit(address _sender, uint256 _value);

    event Withdrawal(address _sender, uint256 _value);

    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
    {}

    fallback() external payable {
        super._mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    receive() external payable {
        super._mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function deposit() external payable {
        super._mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 _wad) external {
        require(
            balanceOf(msg.sender) >= _wad,
            "WrappedCoin: wad exceeds user balance"
        );
        super._burn(msg.sender, _wad);
        payable(msg.sender).transfer(_wad);
        emit Withdrawal(msg.sender, _wad);
    }
}
