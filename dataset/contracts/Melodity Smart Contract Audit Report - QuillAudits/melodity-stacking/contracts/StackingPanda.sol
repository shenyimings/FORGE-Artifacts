// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./PRNG.sol";

contract StackingPanda is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct StackingBonus {
        uint8 decimals;
        uint256 meldToMeld;
        uint256 toMeld;
    }

    struct Metadata {
        string name;
        string picUrl;
        StackingBonus bonus;
    }

    Metadata[] private metadata;

    address public masterchef;
    PRNG private prng;

    event NewPandaMinted(uint256 pandaId, string pandaName);

    // Init the NFT contract with the ownable abstact in order to let only the owner
    // mint new NFTs
    constructor(address _prng)
        ERC721("Melodity Stacking Panda", "STACKP")
        Ownable()
    {
        masterchef = msg.sender;
        prng = PRNG(_prng);
    }

    /**
        Mint new NFTs, the maximum number of mintable NFT is 100.
        Only the owner of the contract can call this method.
        NFTs will be minted to the owner of the contract (alias, the creator); in order
        to let the Masterchef sell the NFT immediately after minting this contract *must*
        be deployed onchain by the Masterchef itself.

        @param _name Panda NFT name
        @param _picUrl The url where the picture is stored
        @param _stackingBonus As these NFTs are designed to give stacking bonuses this 
                value defines the reward bonuses
        @return uint256 Just minted nft id
     */
    function mint(
        string calldata _name,
        string calldata _picUrl,
        StackingBonus calldata _stackingBonus
    ) public nonReentrant onlyOwner returns (uint256) {
        prng.rotate();

        // Only 100 NFTs will be mintable
        require(_tokenIds.current() < 100, "All pandas minted");

        uint256 newItemId = _tokenIds.current();
        _tokenIds.increment();

        // incrementing the counter after taking its value makes possible the aligning
        // between the metadata array and the panda id, this let us simply push the metadata
        // to the end of the array instead of calculating where to place the data
        metadata.push(
            Metadata({name: _name, picUrl: _picUrl, bonus: _stackingBonus})
        );
        _mint(owner(), newItemId);

        emit NewPandaMinted(newItemId, _name);

        return newItemId;
    }

    /**
        Retrieve and return the metadata for the provided _nftId
        @param _nftId Identifier of the NFT whose data should be returned
        @return Metadata
     */
    function getMetadata(uint256 _nftId) public view returns (Metadata memory) {
        return metadata[_nftId];
    }
}