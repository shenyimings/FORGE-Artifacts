//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./interfaces/IStackOsNFT.sol";
import "./GenerationManager.sol";
import "./Whitelist.sol";

contract DarkMatter is Whitelist, ERC721, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    
    GenerationManager private generations;

    // total amount of NFT deposited from any generation
    mapping(address => uint256) private deposits; 
    // owner => current incomplete DarkMatter id
    mapping(address => uint256) private lastUserDarkMatter; 
    // owner => DarkMatter ids
    mapping(address => uint256[]) private toBeMinted; 
    // generation => StackNFT id => DarkMatter id
    mapping(uint256 => mapping(uint256 => uint256)) private stackToDarkMatter; 

    // DarkMatter id => generation => StackNFT ids 
    mapping(uint256 => mapping(uint256 => uint256[])) private darkMatterToStack; 
    // mapping(address => bool) _whitelist;
    
    // number of StackNFTs that must be deposited in order to be able to mint a DarkMatter.
    uint256 immutable mintPrice; 

    constructor(GenerationManager _generations, uint256 _mintPrice)
        ERC721("DarkMatter", "DM")
    {
        generations = _generations;
        mintPrice = _mintPrice;
    }

    /*
     * @title Return stack token ids owned by DarkMatter token.
     * @param DarkMatter token id.
     */
    function ID(uint256 _darkMatterId)
        public
        view
        returns (uint256[][] memory)
    {
        uint256[][] memory stackTokenIds = new uint256[][](generations.count());
        for(uint256 i; i < stackTokenIds.length; i ++) {
            stackTokenIds[i] = darkMatterToStack[_darkMatterId][i];
        }
        return stackTokenIds;
    }

    /*
     * @title Returns true if `_wallet` owns either StackNFT or DarkMatterNFT that owns this StackNFT.
     * @param Address of wallet.
     * @param StackNFT generation id.
     * @param StackNFT token id.
     */
    function isOwnStackOrDarkMatter(
        address _wallet,
        uint256 generationId,
        uint256 tokenId
    ) public view returns (bool) {
        if (
            _exists(stackToDarkMatter[generationId][tokenId]) &&
            ownerOf(generationId, tokenId) == _wallet
        ) {
            return true;
        }
        return generations.get(generationId).ownerOf(tokenId) == _wallet;
    }

    /*
     * @title Returns owner of StackNFT.
     * @param StackNFT address.
     * @param StackNFT token id.
     * @dev The returned address owns StackNFT or DarkMatter that owns this StackNFT. 
     */
    function ownerOfStackOrDarkMatter(IStackOsNFT _stackOsNFT, uint256 tokenId)
        public
        view
        returns (address)
    {
        uint256 generationId = generations.getIDByAddress(address(_stackOsNFT));
        if (_exists(stackToDarkMatter[generationId][tokenId])) {
            return ownerOf(generationId, tokenId);
        }
        return _stackOsNFT.ownerOf(tokenId);
    }

    /*
     * @title Returns owner of the DarkMatterNFT that owns StackNFT.
     * @param StackNFT generation id.
     * @param StackNFT token id.
     */
    function ownerOf(uint256 generationId, uint256 tokenId)
        public
        view
        returns (address)
    {
        return ownerOf(stackToDarkMatter[generationId][tokenId]);
    }

    /*
     *  @title Deposit StackNFTs.
     *  @param StackNFT generation id.
     *  @param Token ids.
     *  @dev StackNFT generation must be added in manager prior to deposit.
     */
    function deposit(uint256 generationId, uint256[] calldata tokenIds)
        external
        nonReentrant
    {
        require(generationId < generations.count(), "Generation doesn't exist");
        IStackOsNFT stackNFT = generations.get(generationId);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            stackNFT.transferFrom(msg.sender, address(this), tokenId);

            if (deposits[msg.sender] == 0) {
                lastUserDarkMatter[msg.sender] = _tokenIdCounter.current();
                _tokenIdCounter.increment();
            }
            deposits[msg.sender] += 1;
            if (deposits[msg.sender] == mintPrice) {
                deposits[msg.sender] -= mintPrice;
                darkMatterToStack[lastUserDarkMatter[msg.sender]][generationId].push(tokenId);
                toBeMinted[msg.sender].push(lastUserDarkMatter[msg.sender]);
            } else {
                darkMatterToStack[lastUserDarkMatter[msg.sender]][generationId].push(tokenId);
            }
            stackToDarkMatter[generationId][tokenId] = lastUserDarkMatter[
                msg.sender
            ];
        }
    }

    /*
     *  @title Mints a DarkMatterNFT for the caller.
     *  @dev Caller must have deposited `mintPrice` number of StackNFT of any generation.
     */
    function mint() public nonReentrant {
        require(toBeMinted[msg.sender].length > 0, "Not enough deposited");
        while (toBeMinted[msg.sender].length > 0) {
            _mint(
                msg.sender,
                toBeMinted[msg.sender][toBeMinted[msg.sender].length - 1]
            );
            toBeMinted[msg.sender].pop();
        }
    }

    /*
     *  @title Override to make use of whitelist.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    )
        internal
        override(ERC721)
        onlyWhitelisted
    {
        super._transfer(from, to, tokenId);
    }

}
