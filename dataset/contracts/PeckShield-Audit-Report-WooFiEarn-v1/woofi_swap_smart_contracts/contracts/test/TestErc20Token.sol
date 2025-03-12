// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.12;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract TestToken is ERC20('TestToken', 'TT'), Ownable {
    using SafeMath for uint256;

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
