// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import '../extend/ERC20ex.sol';
import 'openzeppelin-solidity/contracts/utils/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/utils/Address.sol';
import './IGToken.sol';

contract Pomerium is IGToken, ERC20ex {
    using Address for address;
    using SafeMath for uint256;

    event Mint(address to, uint256 amount);
    event Burn(address sender, uint256 amount);

    constructor(uint256 _balance) ERC20ex('Pomerium Token', 'PMR', 18) {
        _mint(_msgSender(), _balance);

        emit Mint(_msgSender(), _balance);
    }

    function burn(uint256 amount) public virtual override {
        _burn(_msgSender(), amount);

        emit Burn(_msgSender(), amount);
    }
}
