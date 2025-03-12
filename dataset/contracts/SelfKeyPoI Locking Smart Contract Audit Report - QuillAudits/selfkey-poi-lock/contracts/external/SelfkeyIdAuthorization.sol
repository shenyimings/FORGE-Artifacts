// SPDX-License-Identifier: proprietary
pragma solidity 0.8.19;

import "./SafeOwn.sol";

contract SelfkeyIdAuthorization is SafeOwn {

    address public authorizedSigner;
    mapping(bytes32 => bool) public executed;

    event SignerChanged(address indexed _address);
    event PayloadAuthorized(address _from, address _to, uint256 _amount);

    constructor(address _signer) SafeOwn(14400) {
        require(_signer != address(0), "Invalid authorized signer");
        authorizedSigner = _signer;
    }

    function changeSignerAddress(address _signer) public onlyOwner {
        require(_signer != address(0), "Invalid authorized signer");
        authorizedSigner = _signer;
        emit SignerChanged(_signer);
    }

    function authorize(address _from, address _to, uint256 _amount, string memory _scope, bytes32 _param, uint _timestamp, address _signer, bytes memory _signature) external {
        uint timeLimit = block.timestamp - 4 hours;
        require(_timestamp > timeLimit, "Invalid timestamp");
        require(_from == msg.sender, "Invalid caller");
        require(_to == tx.origin, "Invalid subject");
        require(_signer == authorizedSigner, "Invalid signer");
        require(verify(_from, _to, _amount, _scope, _param, _timestamp, _signer, _signature), "Verification failed");

        bytes32 messageHash = getMessageHash(_from, _to, _amount, _scope, _param, _timestamp);
        require(!executed[messageHash], "Payload already used");

        executed[messageHash] = true;
        emit PayloadAuthorized(_from, _to, _amount);
    }

    function getMessageHash(address _from, address _to, uint256 _amount, string memory _scope, bytes32 _param, uint _timestamp) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_from, _to, _amount, _scope, _param, _timestamp));
    }

    function getEthSignedMessageHash(bytes32 _messageHash) public pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }

    function verify(address _from, address _to, uint256 _amount, string memory _scope, bytes32 _param, uint _timestamp, address _signer, bytes memory signature) public pure returns (bool) {
        bytes32 messageHash = getMessageHash(_from, _to, _amount, _scope, _param, _timestamp);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");
        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
        // implicitly return (r, s, v)
    }
}
