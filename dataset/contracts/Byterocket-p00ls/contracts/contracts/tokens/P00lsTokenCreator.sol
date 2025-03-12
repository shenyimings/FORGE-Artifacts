// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "../utils/RegistryOwnable.sol";
import "./P00lsTokenBase.sol";
import "./interfaces.sol";

/// @custom:security-contact security@p00ls.com
contract P00lsTokenCreator is P00lsTokenBase, RegistryOwnable
{
    using BitMaps for BitMaps.BitMap;

    IP00lsTokenXCreator public xCreatorToken;
    bytes32             public merkleRoot;
    BitMaps.BitMap      private __claimedBitMap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address registry)
        RegistryOwnable(registry)
        initializer()
    {}

    function initialize(string calldata name, string calldata symbol, bytes32 root, address child)
        external
        initializer()
    {
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        merkleRoot = root;
        xCreatorToken = IP00lsTokenXCreator(child);
    }

    function isClaimed(uint256 index)
        public
        view
        returns (bool)
    {
        return __claimedBitMap.get(index);
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof)
        public
    {
        require(!isClaimed(index), "P00lsTokenCreator::claim: drop already claimed");

        require(MerkleProof.verify(merkleProof, merkleRoot, keccak256(abi.encodePacked(index, account, amount))), "P00lsTokenCreator::claim: invalid merkle proof");

        __claimedBitMap.set(index);
        _mint(account, amount);
    }

    function owner()
        public
        view
        override(P00lsTokenBase, RegistryOwnable)
        returns (address)
    {
        return super.owner();
    }

    /**
     * xCreatorToken bindings
     */
    function _delegate(address delegator, address delegatee)
        internal
        override
    {
        super._delegate(delegator, delegatee);
        xCreatorToken.__delegate(delegator, delegatee);
    }

    function allowance(address holder, address spender)
        public
        view
        override
        returns (uint256)
    {
        return spender == address(xCreatorToken)
            ? type(uint256).max
            : super.allowance(holder, spender);
    }
}
