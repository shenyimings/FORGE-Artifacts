// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.6.12;

import "../lib/HermezHelpers.sol";

contract HermezHelpersTest is HermezHelpers {
    constructor(
        address _poseidon2Elements,
        address _poseidon3Elements,
        address _poseidon4Elements
    ) public {
        _initializeHelpers(
            _poseidon2Elements,
            _poseidon3Elements,
            _poseidon4Elements
        );
    }

    function testHash2ElementsGas(uint256[2] memory inputs)
        public
        view
        returns (uint256)
    {
        uint256 gasFirst = gasleft();
        _hash2Elements(inputs);
        return (gasFirst - gasleft());
    }

    function testHash3ElementsGas(uint256[3] memory inputs)
        public
        view
        returns (uint256)
    {
        uint256 gasFirst = gasleft();
        _hash3Elements(inputs);
        return (gasFirst - gasleft());
    }

    function testHash4ElementsGas(uint256[4] memory inputs)
        public
        view
        returns (uint256)
    {
        uint256 gasFirst = gasleft();
        _hash4Elements(inputs);
        return (gasFirst - gasleft());
    }

    function testHash2Elements(uint256[2] memory inputs)
        public
        view
        returns (uint256)
    {
        return _hash2Elements(inputs);
    }

    function testHash3Elements(uint256[3] memory inputs)
        public
        view
        returns (uint256)
    {
        return _hash3Elements(inputs);
    }

    function testHash4Elements(uint256[4] memory inputs)
        public
        view
        returns (uint256)
    {
        return _hash4Elements(inputs);
    }

    function testHashNode(uint256 left, uint256 right)
        public
        view
        returns (uint256)
    {
        return _hashNode(left, right);
    }

    function testHashFinalNode(uint256 key, uint256 value)
        public
        view
        returns (uint256)
    {
        return _hashFinalNode(key, value);
    }

    function smtVerifierTestGas(
        uint256 root,
        uint256[] memory siblings,
        uint256 key,
        uint256 value
    ) public view returns (uint256) {
        uint256 gasFirst = gasleft();
        _smtVerifier(root, siblings, key, value);
        return (gasFirst - gasleft());
    }

    function smtVerifierTest(
        uint256 root,
        uint256[] memory siblings,
        uint256 key,
        uint256 value
    ) public view returns (bool) {
        return _smtVerifier(root, siblings, key, value);
    }

    function buildTreeStateTest(
        uint32 token,
        uint48 nonce, // 40 bits
        uint256 balance,
        uint256 ay,
        address ethAddress
    ) public pure returns (uint256[4] memory) {
        uint256[4] memory arrayState = _buildTreeState(
            token,
            nonce,
            balance,
            ay,
            ethAddress
        );
        return (arrayState);
    }

    function hashTreeStateTest(
        uint32 token,
        uint16 nonce,
        uint256 balance,
        uint256 ay,
        address ethAddress
    ) public view returns (uint256) {
        uint256[4] memory arrayState = _buildTreeState(
            token,
            nonce,
            balance,
            ay,
            ethAddress
        );
        return _hash4Elements(arrayState);
    }

    function float2FixTest(uint40 float) public pure returns (uint256) {
        return _float2Fix(float);
    }

    function checkSigTest(
        bytes32 babyjub,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public view returns (address) {
        return _checkSig(babyjub, r, s, v);
    }

    function getChainID() public view returns (uint256) {
        uint256 chainID;
        uint256 a = 0 % 6;
        assembly {
            chainID := chainid()
        }
        return chainID;
    }
}
