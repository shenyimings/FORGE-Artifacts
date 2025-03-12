// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Create2.sol";

import "./interfaces/CloberOrderNFTDeployer.sol";
import "./OrderNFT.sol";

contract OrderNFTDeployer is CloberOrderNFTDeployer {
    address private immutable _factory;
    address private immutable _canceler;
    bytes32 private immutable _orderTokenBytecodeHash;

    constructor(address factory_, address canceler_) {
        _factory = factory_;
        _canceler = canceler_;
        _orderTokenBytecodeHash = keccak256(
            abi.encodePacked(type(OrderNFT).creationCode, abi.encode(factory_, canceler_))
        );
    }

    function deploy(bytes32 salt) external returns (address) {
        if (msg.sender != _factory) {
            revert Errors.CloberError(Errors.ACCESS);
        }
        return address(new OrderNFT{salt: salt}(_factory, _canceler));
    }

    function computeTokenAddress(bytes32 salt) external view returns (address) {
        return Create2.computeAddress(salt, _orderTokenBytecodeHash);
    }
}
