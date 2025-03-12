// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

enum Color {
    Blue,
    Red,
    Green
}

contract RitestreamNFT is ERC721Enumerable, Ownable {
    address private immutable _self;
    string private baseURI;

    // This address is used for if current owner want to renounceOwnership, it will always be the same address
    address private constant fixedOwnerAddress =
        0x1156B992b1117a1824272e31797A2b88f8a7c729;

    /** @dev Mapping from color to maximum per color */
    mapping(Color => uint16) public max;

    /** @dev Mapping from color to quantity minted per color */
    mapping(Color => uint256) public passes;

    bool public isSaleActive;

    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {
        _self = address(this);
        max[Color.Blue] = 4000;
        max[Color.Red] = 7000;
        max[Color.Green] = 8000;

        //Start blue IDs at 0
        passes[Color.Blue] = 0;

        //Start red IDs at 4000
        passes[Color.Red] = 4000;

        //Start greed IDs at 7000
        passes[Color.Green] = 7000;
    }

    // MODIFIERS
    modifier saleActive() {
        require(isSaleActive, "Sale is not active");
        _;
    }

    // PUBLIC READ-ONLY FUNCTIONS
    function getBaseURI() external view returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Nonexistent token");

        return string(abi.encodePacked(baseURI, "/", tokenId, ".json"));
    }

    // ONLY OWNER FUNCTIONS
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function toggleSaleStatus() external onlyOwner {
        isSaleActive = !isSaleActive;
    }

    // SUPPORTING FUNCTIONS
    function nextPassId(Color id) internal view returns (uint256) {
        return passes[id] + 1;
    }

    // FUNCTION FOR MINTING
    function mintPass(address userAddress, Color id)
        external
        saleActive
        onlyOwner
    {
        require(passes[id] < max[id], "Not enough passes remaining to mint");
        _safeMint(userAddress, nextPassId(id));
        passes[id]++;
    }

    /// @dev Override renounceOwnership to transfer ownership to a fixed address, make sure contract owner will never be address(0)
    function renounceOwnership() public override onlyOwner {
        _transferOwnership(fixedOwnerAddress);
    }
}
