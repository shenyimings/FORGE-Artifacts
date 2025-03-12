// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import './FoldingRegistry.sol';

contract FoldingRegistryV2 is FoldingRegistry {
    function version() external pure virtual override returns (uint8) {
        return 2;
    }

    function createAccount() public virtual override returns (address) {
        bytes memory bytecode = type(FoldingAccount).creationCode;
        bytecode = abi.encodePacked(bytecode, abi.encode(address(this)));

        uint256 salt = uint256(keccak256(abi.encodePacked(msg.sender, nonces[msg.sender])));
        nonces[msg.sender] = nonces[msg.sender] + 1;

        address account;
        uint256 size;
        assembly {
            account := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            size := extcodesize(account)
        }
        require(size > 0, 'FR1');

        fodlNFT.mint(msg.sender, uint256(account));

        return account;
    }

    function setNFT(address fodlNFTV2_) external virtual onlyOwner {
        require(fodlNFTV2_ != address(0), 'ICP0');

        fodlNFT = FodlNFT(fodlNFTV2_);
    }
}
