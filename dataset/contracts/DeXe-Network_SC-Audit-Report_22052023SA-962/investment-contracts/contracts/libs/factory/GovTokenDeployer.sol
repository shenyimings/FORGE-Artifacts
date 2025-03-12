// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Create2.sol";

import "../../gov/ERC20/ERC20Gov.sol";

library GovTokenDeployer {
    function deployToken(
        address poolProxy,
        bytes32 salt,
        ERC20Gov.ConstructorParams calldata tokenParams
    ) external returns (address) {
        ERC20Gov token = new ERC20Gov{salt: salt}();

        token.__ERC20Gov_init(poolProxy, tokenParams);

        return address(token);
    }

    function predictTokenAddress(bytes32 salt) external view returns (address) {
        bytes32 bytecodeHash = keccak256(type(ERC20Gov).creationCode);

        return Create2.computeAddress(salt, bytecodeHash);
    }
}
