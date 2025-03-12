//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IAuthPass {
    function isAuthorized(address _address) external view returns (bool);
    function getKojiOracle() external view returns (address);
    function getGameContract() external view returns (address);
}

// Interface for the Koji Oracle
interface IOracle {
    function getMintUSD(uint256 amount) external view returns (uint256);
}

contract KojiGamepass is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    modifier onlyAuthorized() {
        require(auth.isAuthorized(_msgSender()) || owner() == address(_msgSender()), "User not Authorized to NFT Contract");
        _;
    }

    Counters.Counter private _tokenIds;

    uint public mintFee = 1;

    string URI;

    IAuthPass private auth;

    address  AUTH;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    mapping(address => bool) public nftAuth; //nftAuth[recipient]

    constructor(address _auth, string memory _uri) ERC721("KojiGamepass", "SPACEWARS.v1") { 

        auth = IAuthPass(_auth);

        URI = _uri;
    }

    receive() external payable {}

    function mintGamepass(string memory _holder) external payable nonReentrant {

        uint mintCost = IOracle(auth.getKojiOracle()).getMintUSD(mintFee);

        require(compareHashes(_msgSender(), _holder), "Sender is not the same as requested recipient");
        require(IERC721(this).balanceOf(_msgSender()) == 0, "You already possess a Koji Gamepass NFT");
        require(msg.value >= mintCost, "Please include mint fee in order to mint Koji Gamepass NFT");

        _tokenIds.increment();
        
        uint256 newItemId = _tokenIds.current();

        _mint(_msgSender(), newItemId);

        string memory metadata = _holder;
        string memory json = ".json";        
        string memory result = string.concat(metadata, json);

        _setTokenURI(newItemId, string.concat(URI, result));

        nftAuth[_msgSender()] = true;

    }

    // This will allow to rescue ETH sent by mistake directly to the contract
    function rescueETHFromContract() external onlyOwner {
        address payable _owner = payable(_msgSender());
        _owner.transfer(address(this).balance);
    }

    // Function to allow admin to claim *other* ERC20 tokens sent to this contract (by mistake)
    function transferERC20Tokens(address _tokenAddr, address _to, uint _amount) public onlyOwner {
       
        IERC20(_tokenAddr).transfer(_to, _amount);
    }

    function getMintCost() external view returns(uint) {
        return IOracle(auth.getKojiOracle()).getMintUSD(mintFee);
    }

    function changeMintFee(uint _fee) external onlyAuthorized {
        mintFee = _fee;
    }

    function getNFTAuth(address _holder) external view returns (bool) {
        return nftAuth[_holder];
    }

    function compareHashes(address _address, string memory _holder) internal pure returns (bool) {

        bytes32 first = keccak256(bytes(Strings.toHexString(uint160(_address), 20)));

        bytes32 second = keccak256(bytes(_toLower(_holder)));

        return(first == second);
    }

    function _toLower(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            // Uppercase character...
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                // So we add 32 to make it lowercase
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override(ERC721) returns (string memory) {
        _requireMinted(tokenId);

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

        /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
    
}
