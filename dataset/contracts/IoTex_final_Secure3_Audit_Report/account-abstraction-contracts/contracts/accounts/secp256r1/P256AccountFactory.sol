// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./P256Account.sol";
import "../../interfaces/ISecp256r1.sol";
import "../../interfaces/IDkimVerifier.sol";

contract P256AccountFactory {
    P256Account public immutable accountImplementation;

    constructor(
        IEntryPoint _entryPoint,
        ISecp256r1 _validator,
        IDkimVerifier _verifier
    ) {
        accountImplementation = new P256Account(_entryPoint, _validator, _verifier);
    }

    function createAccount(bytes calldata publicKey, uint256 salt)
        public
        returns (P256Account ret)
    {
        address addr = getAddress(publicKey, salt);
        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            return P256Account(payable(addr));
        }
        ret = P256Account(
            payable(
                new ERC1967Proxy{salt: bytes32(salt)}(
                    address(accountImplementation),
                    abi.encodeCall(P256Account.initialize, publicKey)
                )
            )
        );
    }

    function getAddress(bytes calldata publicKey, uint256 salt) public view returns (address) {
        return
            Create2.computeAddress(
                bytes32(salt),
                keccak256(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            address(accountImplementation),
                            abi.encodeCall(P256Account.initialize, publicKey)
                        )
                    )
                )
            );
    }
}
