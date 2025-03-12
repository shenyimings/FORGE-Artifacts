//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol"; 
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol"; 

///
/// @dev Interface for the NFT Royalty Standard
///
interface IERC2981 is IERC165 {
    /// ERC165 bytes to add to interface array - set in parent contract
    /// implementing this standard
    ///
    /// @notice Called with the sale price to determine how much royalty
    //          is owed and to whom.
    /// @param _tokenId - the NFT asset queried for royalty information
    /// @param _salePrice - the sale price of the NFT asset specified by _tokenId
    /// @return receiver - address of who should be sent the royalty payment
    /// @return royaltyAmount - the royalty payment amount for _salePrice   

    /// @notice Informs callers that this contract supports ERC2981
    /// @dev If `_registerInterface(_INTERFACE_ID_ERC2981)` is called
    ///      in the initializer, this should be automatic
    /// @param interfaceID The interface identifier, as specified in ERC-165
    /// @return `true` if the contract implements
    ///         `_INTERFACE_ID_ERC2981` and `false` otherwise
    function supportsInterface(bytes4 interfaceID) external override view returns (bool);
}

// Allows authorized users to add creators/infuencer addresses to the whitelist
contract Whitelisted is Ownable {

    mapping(address => bool) public whitelisted;

    modifier onlyWhitelisted() {
        require(whitelisted[_msgSender()] || owner() == address(_msgSender()));
        _;
    }

    function addWhitelisted(address _toAdd) onlyOwner public {
        require(_toAdd != address(0));
        whitelisted[_toAdd] = true;
    }

    function removeWhitelisted(address _toRemove) onlyOwner public {
        require(_toRemove != address(0));
        require(_toRemove != address(_msgSender()));
        whitelisted[_toRemove] = false;
    }

}

contract KojiPosterNFT is ERC721Enumerable, ERC165Storage, Ownable, Whitelisted {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter private _tokenIds;
    Counters.Counter private _tier1tokenIds;
    Counters.Counter private _tier2tokenIds;
    
    mapping(address => bool) public minted;
    mapping(address => bool) public tier1minted;
    mapping(address => bool) public tier2minted;

    mapping(uint => uint) public mintedCount;
    mapping(string => uint) private mintedCounttier1URI;
    mapping(string => uint) private mintedCounttier2URI;

    bool timelimitenabled = false;
    bool walletlimitenabled = false;
    bool public mintlimitsenabled = false;
    bool public walletbalanceenabled = false;

    string private tier1URI;
    string private tier2URI;

    uint256 public tier1mintlimit = 1000;
    uint256 public tier2mintlimit = 1000;

    uint public mintedtotal;
    uint public mintedtier1;
    uint public mintedtier2;

    uint royaltyNumerator = 1;

    uint256 public timestart; //unix block timestamp for opening of mint window
    uint256 public timeend; //unix block timestamp for closing of mint window

    uint256 tier1balance = 1000000000000000000000000000; //1 Billion KOJI for tier1 poster mint
    uint256 tier2balance = 250000000000000000000000000; //250 Million KOJI for tier2 poster mint

    address public receiver = 0xb629Fb3426877640C6fB6734360D81D719062bF6; //KOJI token charity address
    address public nftproxy;
    IERC20 token = IERC20(0x08Ea9d54921d591146246AA7533C931cf78893B8); //KOJI token

    /*
     *     bytes4(keccak256('balanceOf(address)')) == 0x70a08231
     *     bytes4(keccak256('ownerOf(uint256)')) == 0x6352211e
     *     bytes4(keccak256('approve(address,uint256)')) == 0x095ea7b3
     *     bytes4(keccak256('getApproved(uint256)')) == 0x081812fc
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
     *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
     *     bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256)')) == 0x42842e0e
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)')) == 0xb88d4fde
     *
     *     => 0x70a08231 ^ 0x6352211e ^ 0x095ea7b3 ^ 0x081812fc ^
     *        0xa22cb465 ^ 0xe985e9c5 ^ 0x23b872dd ^ 0x42842e0e ^ 0xb88d4fde == 0x80ac58cd
     */
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    /*
     *     bytes4(keccak256('name()')) == 0x06fdde03
     *     bytes4(keccak256('symbol()')) == 0x95d89b41
     *     bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd
     *
     *     => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd == 0x5b5e139f
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;

    /*
     *     bytes4(keccak256('totalSupply()')) == 0x18160ddd
     *     bytes4(keccak256('tokenOfOwnerByIndex(address,uint256)')) == 0x2f745c59
     *     bytes4(keccak256('tokenByIndex(uint256)')) == 0x4f6ccce7
     *
     *     => 0x18160ddd ^ 0x2f745c59 ^ 0x4f6ccce7 == 0x780e9d63
     */
    bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;

    /*
    *      bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a
    *      bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    *      _registerInterface(_INTERFACE_ID_ERC2981);
    *
    */

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    constructor(uint256 _timestart, uint256 _timeend) ERC721("KojiNFT", "KOJINFT") {
        // register the supported interfaces to conform to ERC721 via ERC165
        _registerInterface(_INTERFACE_ID_ERC721);
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
        _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
        // Royalties interface
        _registerInterface(_INTERFACE_ID_ERC2981);

        timestart = _timestart;
        timeend = _timeend;
    }

    function minttier1NFT(address recipient) public returns (uint256) {   

        require(msg.sender == address(nftproxy), "Minting not allowed outside of the proxy contract");

        if(!whitelisted[address(recipient)]) {

            if(timelimitenabled) {
            require(timestart > block.timestamp && timeend < block.timestamp, "Time period for minting NFT has expired");
            }

            if(walletlimitenabled) {
                require(!minted[address(recipient)], "Wallet has reached 1 NFT mint limit for this contract");
            }

            if (mintlimitsenabled) {
                require(!tier1mintLimitReached(), "The mint limit for the NFT has been reached");
            }

            if (walletbalanceenabled) {
                require(token.balanceOf(recipient) >= tier1balance, "$KOJI token balance insufficient for this tier");
            }

        }       

        _tokenIds.increment();
        _tier1tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tier1URI);

        minted[address(recipient)] = true;
        tier1minted[address(recipient)] = true;
        
        mintedCounttier1URI[tier1URI] = _tier1tokenIds.current();
        mintedtier1 =  _tier1tokenIds.current();

        mintedtotal = _tokenIds.current();

        return newItemId;
    }

    function minttier2NFT(address recipient) public returns (uint256) {   
         
        require(msg.sender == address(nftproxy), "Minting not allowed outside of the proxy contract");

        if(!whitelisted[address(recipient)]) {

            if(timelimitenabled) {
            require(timestart > block.timestamp && timeend < block.timestamp, "Time period for minting NFT has expired");
            }

            if(walletlimitenabled) {
                require(!minted[address(recipient)], "Wallet has reached 1 NFT mint limit for this contract");
            }

            if (mintlimitsenabled) {
                require(!tier2mintLimitReached(), "The mint limit for the NFT has been reached");
            }

            if (walletbalanceenabled) {
                require(token.balanceOf(recipient) >= tier2balance, "$KOJI token balance insufficient for this tier");
            }

        }

        _tokenIds.increment();
        _tier2tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tier2URI);

        minted[address(recipient)] = true;
        tier2minted[address(recipient)] = true;
        
        mintedCounttier2URI[tier2URI] = _tier2tokenIds.current();
        mintedtier2 =  _tier2tokenIds.current();

        mintedtotal = _tokenIds.current();

        return newItemId;
    }

    //returns whether the mint limit has been reached or not
    function tier1mintLimitReached() public view returns (bool) {
        uint256 newItemId = _tier1tokenIds.current();
        if (newItemId == tier1mintlimit) {
            return (true);
        } else {
            return (false);
        }
    }

    //returns whether the mint limit has been reached or not
    function tier2mintLimitReached() public view returns (bool) {
        uint256 newItemId = _tier2tokenIds.current();
        if (newItemId == tier2mintlimit) {
            return (true);
        } else {
            return (false);
        }
    }

    //returns the total number of minted NFT
    function totalMinted() public view returns (uint256) {
        uint256 tier1 = _tier1tokenIds.current();
        uint256 tier2 = _tier2tokenIds.current();
        uint256 total = tier1.add(tier2);
        return total;
    }

    //returns the balance of the erc20 token required for validation
    function checkBalance(address _token, address holder) public view returns (uint256) {
        IERC20 tokens = IERC20(_token);
        return tokens.balanceOf(holder);
    }

    //returns the number of mints for each specific NFT based on URI
    function mintedCounttier1(string memory tokenURI) public view returns (uint256) {
        return mintedCounttier1URI[tokenURI];
    }

    //returns the number of mints for each specific NFT based on URI
    function mintedCounttier2(string memory tokenURI) public view returns (uint256) {
        return mintedCounttier2URI[tokenURI];
    }

    function setToken(address _token) external onlyOwner {
        token = IERC20(_token);
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns(address,uint256){
    
    uint256 royaltyAmount = _salePrice.mul(royaltyNumerator).div(100);
    _tokenId = _tokenId;

    return (receiver, royaltyAmount);
        
    }

    function changeReceiver(address _receiver) external onlyOwner {
        receiver = _receiver;
    }

    function changeTier1URI(string memory _uri) external onlyOwner {
        tier1URI = _uri;
    }

    function changeTier2URI(string memory _uri) external onlyOwner {
        tier2URI = _uri;
    }

    function tier1limit(uint256 _limit) external onlyOwner {
        tier1mintlimit = _limit;
    }

    function tier2limit(uint256 _limit) external onlyOwner {
        tier2mintlimit = _limit;
    }

    function enabletimelimit(bool _status) external onlyOwner {
        timelimitenabled = _status;
    }

    function enablewalletlimit(bool _status) external onlyOwner {
        walletlimitenabled = _status;
    }

    function enablemintlimit(bool _status) external onlyOwner {
        mintlimitsenabled = _status;
    }

    function enablewalletbalance(bool _status) external onlyOwner {
        walletbalanceenabled = _status;
    }

    function setWindow(uint256 _start, uint256 _end) external onlyOwner {
        timestart = _start;
        timeend = _end;
    }

    function setnftproxy(address _address) external onlyOwner {
        nftproxy = _address;
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

    function getRoyaltyNumerator() external view returns(uint) {
        return royaltyNumerator;
    }

    function setRoyaltyNumerator(uint _number) external onlyOwner {
        require(_number >= 1 && _number <= 10, "Royalty fee must be no less than 1% and no greater than 10%");
        royaltyNumerator = _number;
    } 

    function updateTier1balance(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than zero");
        tier1balance = _amount;
    }

    function updateTier2balance(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than zero");
        tier2balance = _amount;
    }
}

