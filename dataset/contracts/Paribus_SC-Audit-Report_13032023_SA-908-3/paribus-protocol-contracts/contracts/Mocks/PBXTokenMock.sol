// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "../PBXToken.sol";

contract PBXTokenMock is PBXToken {
    constructor(uint256 initialSupply) public PBXToken(initialSupply) { }

    function mint(address _to, uint256 _amount) public onlyOwner returns (bool) {
        ERC20._mint(_to, _amount);
        return true;
    }
}
