// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../staking/IPikaStaking.sol';

/** @title VePika
    @notice Vote escrowed non-transferable token
 */
contract VePika is ERC20 {
    IPikaStaking public pikaStaking;

    constructor(address _pikaStaking) ERC20("Vote Escrowed Pika", "vePIKA") {
        pikaStaking = IPikaStaking(_pikaStaking);
    }

    function totalSupply() public view override returns (uint256) {
        return pikaStaking.totalSupply();
    }

    function balanceOf(address _account) public view override returns (uint256) {
        return pikaStaking.balanceOf(_account);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal pure override {
        revert("Non-transferable");
    }
}