// contracts/HashNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IEarningsOracle.sol";
import "./interfaces/IRiskControl.sol";
import "./interfaces/IHashNFT.sol";
import "./mToken.sol";
import "./ERC4907a.sol";

contract HashNFT is IHashNFT, ERC4907a { 
    enum Trait {
        BASIC,
        STANDARD,
        PREMIUM
    }
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    event HashNFTMint(
        address indexed payer,
        address indexed to,
        uint256 tokenId,
        Trait trait,
        string note
    );

    IRiskControl public immutable riskControl;

    uint256 public immutable total;

    address public immutable vault; 

    uint256 public sold = 0;

    mToken public mtoken;

    Counters.Counter private _counter;

    string private constant _defaultURI = "https://gateway.pinata.cloud/ipfs/QmeXA6bFsvAZspDvQTAiGZ7xdCyKPjKcFVzFRmaZQF7acb";

    mapping(uint256 => string) private _tokenURIs;

    mapping(Trait => uint256) public traitHashrates;

    mapping(Trait => uint256) public traitPrices;

    mapping(uint256 => Trait) public traits;

    constructor(
        uint256 _total,
        address rewards,
        address risk,
        uint256[] memory prices,
        address _vault
    ) ERC4907a("Hash NFT", "HASHNFT") {
        riskControl = IRiskControl(risk);
        require(prices[1] >= riskControl.price().mul(prices[0]), "HashNFT: trait price error");
        traitHashrates[Trait.BASIC] = prices[0];
        traitPrices[Trait.BASIC] = prices[1];
        require(prices[3] >= riskControl.price().mul(prices[2]), "HashNFT: trait price error");
        traitHashrates[Trait.STANDARD] = prices[2];
        traitPrices[Trait.STANDARD] = prices[3];
        require(prices[5] >= riskControl.price().mul(prices[4]), "HashNFT: trait price error");
        traitHashrates[Trait.PREMIUM] = prices[4];
        traitPrices[Trait.PREMIUM] = prices[5];

        vault = _vault;
        total = _total;

        mtoken = new mToken(rewards);
    }

    function dispatcher() external view override returns (address) {
        return address(mtoken);
    }

    function payForMint(
        address _to,
        Trait _nftType,
        string memory note
    ) public returns (uint256) {
        uint256 hashrate = traitHashrates[_nftType];
        require(_to != address(0), "HashNFT: mint to the zero address");
        require(sold.add(hashrate) <= total, "HashNFT: insufficient hashrates");
        require(riskControl.mintAllowed(), "HashNFT: risk not allowed to mint");

        uint256 amount = traitPrices[_nftType];
        uint256 cost = riskControl.price().mul(hashrate);
        riskControl.funds().safeTransferFrom(msg.sender, address(riskControl), cost);
        riskControl.funds().safeTransferFrom(msg.sender, vault, amount.sub(cost));

        uint256 tokenId = _counter.current();

        _safeMint(_to, tokenId);
        _counter.increment();
        _setTokenURI(tokenId, _defaultURI);

        mtoken.addPayee(tokenId, hashrate);
        sold = sold.add(hashrate);
        traits[tokenId] = _nftType;
        emit HashNFTMint(msg.sender, _to, tokenId, _nftType, note);
        return tokenId;
    }

    function hashRateOf(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "HashNFT: tokenId not exist");
        return traitHashrates[traits[tokenId]];
    }

     /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI query for nonexistent token"
        );

        string memory _tokenURI = _tokenURIs[tokenId];
        return _tokenURI;
    }

    function updateURI(uint256 tokenId, string memory tokenURI_)
        public
        onlyOwner
    {
        require(
            keccak256(abi.encodePacked(tokenURI(tokenId))) ==
                keccak256(abi.encodePacked(_defaultURI)),
            "HashNFT: token URI already updated"
        );
        _setTokenURI(tokenId, tokenURI_);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory tokenURI_)
        internal
        virtual
    {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI set of nonexistent token"
        );
        _tokenURIs[tokenId] = tokenURI_;
    }
}
