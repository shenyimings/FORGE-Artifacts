//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


interface IAuth {
    function isAuthorized(address _address) external view returns (bool);
    function getKojiStaking() external view returns (address);
    function DEAD() external view returns (address);
    function getKojiOracle() external view returns (address);
    function getKojiNFTPoster() external view returns (address);
}

// Interface for the Koji Oracle
interface IOracle {
    function gettier1USDprice() external view returns (uint,uint);
    function gettier2USDprice() external view returns (uint,uint);
}


contract KojiNFT is ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    modifier onlyAuthorized() {
        require(IAuth(auth).isAuthorized(_msgSender()) || owner() == address(_msgSender()), "User not Authorized to NFT Contract");
        _;
    }

    Counters.Counter private _tokenIds;
    Counters.Counter private _tier1tokenIds;
    Counters.Counter private _tier2tokenIds;
    Counters.Counter public _NFTIds; //so we can track which NFT's have been added to the system

    struct NFTInfo {
        string collectionName; // Name of nft creator/influencer/artist
        string nftName; // Name of the actual NFT artwork
        string tier1uri; //address of NFT metadata
        string tier2uri; //address of NFT metadata
        uint256 timestart; //start time of release window
        uint256 timeend; //end time of release window
        uint256 supermintend; //***end time of supermint window
        uint256 order; //order of the NFT
        bool redeemable; //can be redeemed via staking tier
        bool supermintable; //***can be redeemed with supermint
        bool bnbable; //***can be redeemed with bnb
        bool exists;
    }

    mapping(uint256 => NFTInfo) private nftInfo; // Info of each NFT 
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public nftTierMinted; //nftTierMinted[_nftID][recipient][tier#]
    mapping(uint256 => mapping(address => bool)) public nftMinted; //nftMinted[_nftID][recipient]
    mapping(uint256 => mapping(address => bool)) public nftSuperMinted; //nftMinted[_nftID][recipient]
    mapping(uint256 => mapping(address => bool)) public nftBNBtier1Minted; //nftBNBtier1Minted[_nftID][recipient]
    mapping(uint256 => mapping(address => bool)) public nftBNBtier2Minted; //nftBNBtier2Minted[_nftID][recipient]
    mapping (uint256 => mapping(uint => uint256)) public mintTotals; //mintTotals[_nftID][tier#]
    mapping (uint256 => mapping(uint => uint256)) public mintTotalsAfterWindow; //mintTotalsAfterWindow[_nftID][tier#]
    mapping (string => uint256) public mintTotalsURI; //mintTotalsURI[_nftID][URI]
    mapping (string => bool) private uriExists;
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    uint256 windowSpan = 2592000; //31 days from timestart, regardless of mint method
    uint256 supermintSpan = 2592000; //31 days 
    
    string poster1uri;
    string poster2uri;

    IAuth private auth;
    
    address public DEAD = auth.DEAD();
       
    constructor(string memory _poster1uri, string memory _poster2uri, address _auth) ERC721("KojiNFT", "KOJINFT") {
        poster1uri = _poster1uri;
        poster2uri = _poster2uri;

        auth = IAuth(_auth);
    }

    function upgradeNFT(uint tokenID) external nonReentrant returns (uint) {

        address POSTER = auth.getKojiNFTPoster();

        require(IERC721(POSTER).balanceOf(_msgSender())>0, "Sender has no balance");

        string memory holderuri = ERC721(POSTER).tokenURI(tokenID);

        NFTInfo storage nft = nftInfo[0];

        uint256 minted;
        uint256 minttier;

        _tokenIds.increment();
        
        uint256 newItemId = _tokenIds.current();
        _mint(_msgSender(), newItemId);

        //mint the appropriate tier based on variable passed in from staking
        if (keccak256(bytes(poster1uri)) == keccak256(bytes(holderuri))) {
            _setTokenURI(newItemId, nft.tier1uri);
             _tier1tokenIds.increment();
             minted = mintTotalsURI[nft.tier1uri];
             mintTotalsURI[nft.tier1uri] = minted.add(1);
             minttier = 1;
        } else {
            if (keccak256(bytes(poster2uri)) == keccak256(bytes(holderuri))) {
                _setTokenURI(newItemId, nft.tier2uri);
                _tier2tokenIds.increment();
                minted = mintTotalsURI[nft.tier2uri];
                mintTotalsURI[nft.tier2uri] = minted.add(1);
                minttier = 2;
            } else {
                revert("Invalid uri");
            }
        }

        //increment total # of NFT minted for this ID/Tier
        minted = mintTotals[0][minttier];
        mintTotals[0][minttier] = minted.add(1);

        IERC721(POSTER).safeTransferFrom(_msgSender(), DEAD, tokenID);

        return newItemId;
    }

    function validatePrice(uint _id, uint _tier) external view returns (uint, uint) {

        uint price;
        uint increase;

        if(_tier == 1) {
            (price, increase) = IOracle(auth.getKojiOracle()).gettier1USDprice();
        } else {
            (price, increase) = IOracle(auth.getKojiOracle()).gettier2USDprice();
        }
        
        uint mintsAfterWindow = mintTotalsAfterWindow[_id][_tier];

        price = price.add(mintsAfterWindow.mul(increase));

        return (price, increase);
    }

    function checkValidation(address recipient, uint256 minttier, uint256 id, uint256 userstaketime, bool redeemed, bool superMinted, bool bnbMinted) internal view returns (bool valid, string memory rstring) {
         
         bool validated = true;
         string memory revertstring = "OK";

         NFTInfo storage nft = nftInfo[id];

         if(!nft.exists) {validated = false; revertstring = "E44";}

         if(block.timestamp >= nft.timestart) {validated = false; revertstring = "E18";}

         if((redeemed && superMinted) || (redeemed && bnbMinted) || (superMinted && bnbMinted)) {validated = false; revertstring = "E45";}

         if (!auth.isAuthorized(_msgSender())) {

            if(msg.sender != address(auth.getKojiStaking())) {validated = false; revertstring = "E46";}
        
            if(redeemed) {

                if(!nft.redeemable) {validated = false; revertstring = "E15";}
                if(nftMinted[id][recipient]) {validated = false; revertstring = "E16";}
                if(userstaketime > nft.timestart) {validated = false; revertstring = "E47";}

            } else {

                if(bnbMinted) {
                    if(block.timestamp > nft.timeend) {validated = false; revertstring = "E48";}

                    if(minttier == 1) {
                        if(nftBNBtier1Minted[id][recipient]) {validated = false; revertstring = "E26";}
                    } else {
                        if(nftBNBtier2Minted[id][recipient]) {validated = false; revertstring = "E26";}
                    }

                } else {

                    if(superMinted) {
                        if(block.timestamp > nft.supermintend) {validated = false; revertstring = "E49";} 
                        if(nftSuperMinted[id][recipient]) {validated = false; revertstring = "E23";}

                    }

                }

            }

            if(!redeemed && !superMinted && !bnbMinted) {validated = false; revertstring = "E45"; }
            
         }

         return (validated, revertstring);

    }

    function mintNFT(address recipient, uint256 minttier, uint256 id, uint256 userstaketime, bool redeemed, bool superMinted, bool bnbMinted) public nonReentrant returns (uint256) {   

        (bool valid, string memory revertstring)  = checkValidation(recipient, minttier, id, userstaketime, redeemed, superMinted, bnbMinted);

        require(valid, revertstring);

        NFTInfo storage nft = nftInfo[id];
         
        uint256 minted;

        _tokenIds.increment();
        
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);

        //mint the appropriate tier based on variable passed in from staking
        if(minttier == 1) {
            _setTokenURI(newItemId, nft.tier1uri);
             _tier1tokenIds.increment();
             minted = mintTotalsURI[nft.tier1uri];
             mintTotalsURI[nft.tier1uri] = minted.add(1);
        } else {
            _setTokenURI(newItemId, nft.tier2uri);
             _tier2tokenIds.increment();
             minted = mintTotalsURI[nft.tier2uri];
             mintTotalsURI[nft.tier2uri] = minted.add(1);
        }
        
        //record this NFT & tier as being minted by the recipient
        if (!superMinted && !bnbMinted) {
            nftTierMinted[id][recipient][minttier] = true;
            nftMinted[id][recipient] = true;
        }

        if(superMinted) {nftSuperMinted[id][recipient] = true;}
        
        if(bnbMinted && minttier == 1) {
            nftBNBtier1Minted[id][recipient] = true;
            if(block.timestamp > nft.timestart) {mintTotalsAfterWindow[id][minttier]++;}
        }
        if(bnbMinted && minttier == 2) {
            nftBNBtier2Minted[id][recipient] = true;
            if(block.timestamp > nft.timestart) {mintTotalsAfterWindow[id][minttier]++;}
        }

        //increment total # of NFT minted for this ID/Tier
        minted = mintTotals[id][minttier];
        mintTotals[id][minttier] = minted.add(1);

        return newItemId;

    }

    //returns the gloabal total number of minted NFT per tier
    function totalMinted() public view returns (uint256) {
        uint256 tier1 = _tier1tokenIds.current();
        uint256 tier2 = _tier2tokenIds.current();
        uint256 total = tier1.add(tier2);
        return total;
    }

    //returns the number of mints for each specific NFT based on URI
    function mintedCounttier(string memory tokenURI) public view returns (uint256) {
        return mintTotalsURI[tokenURI];
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

    function setNFTInfo(string memory _collectionName, string memory _nftName, string memory _tier1uri, string memory _tier2uri, uint256 _timestart, uint256 _order, bool _redeemable, bool _supermintable, bool _bnbable, bool _override) public onlyAuthorized returns (uint256) {

        require(owner() == address(_msgSender()) || auth.isAuthorized(_msgSender()), "Sender is not authorized"); 
        require(bytes(_collectionName).length > 0, "Creator name string must not be empty");
        require(bytes(_nftName).length > 0, "NFT name string must not be empty");
        require(bytes(_tier1uri).length > 0, "tier 1 URI string must not be empty");
        require(bytes(_tier2uri).length > 0, "tier 2 URI string must not be empty");
        if(!_override) {
            require(_timestart != 0 && _timestart > block.timestamp, "Time start and end must be in the proper order");
        }
        
        uint256 _nftid = _NFTIds.current();

        NFTInfo storage nft = nftInfo[_nftid];

            nft.collectionName = _collectionName;
            nft.nftName = _nftName;
            nft.tier1uri = _tier1uri;
            nft.tier2uri = _tier2uri;
            nft.timestart = _timestart;
            nft.timeend = _timestart.add(windowSpan);
            nft.order = _order;
            nft.redeemable = _redeemable;
            nft.supermintable = _supermintable;
            nft.bnbable = _bnbable;
            nft.exists = true;

            uriExists[_tier1uri] = true;
            uriExists[_tier2uri] = true;

            if(_supermintable) {nft.supermintend=nft.timeend.add(supermintSpan);}

            _NFTIds.increment();

        return  _nftid; 

    }

    function getNFTInfo(uint256 _nftID) external view returns(string[] memory, uint256[] memory, bool[] memory) {
        
        NFTInfo storage nft = nftInfo[_nftID];

        string[] memory strings = new string[](4);
        uint256[] memory numbers = new uint256[](4);
        bool[] memory bools = new bool[](4);

        strings[0] = nft.collectionName;
        strings[1] = nft.nftName;

        if(block.timestamp >= nft.timestart) {
            strings[2] = nft.tier1uri;
            strings[3] = nft.tier2uri;
        } else {
            strings[2] = nft.nftName;
            strings[3] = nft.nftName;
        }
        

        numbers[0] = nft.timestart;
        numbers[1] = nft.timeend;
        numbers[2] = nft.supermintend;
        numbers[3] = nft.order;

        bools[0] = nft.redeemable;
        bools[1] = nft.supermintable;
        bools[2] = nft.bnbable;
        bools[3] = nft.exists;

        return(strings,numbers,bools);
    }

    function setCollectionName(uint256 _nftID, string memory _name) external onlyAuthorized {
        NFTInfo storage nft = nftInfo[_nftID];
        nft.collectionName = _name;
    }

    function setNFTName(uint256 _nftID, string memory _name) external onlyAuthorized {
        NFTInfo storage nft = nftInfo[_nftID];
        nft.nftName = _name;
    }

    function setTier1URI(uint256 _nftID, string memory _uri) external onlyAuthorized {
        NFTInfo storage nft = nftInfo[_nftID];
        nft.tier1uri = _uri;
    }

    function setTier2URI(uint256 _nftID, string memory _uri) external onlyAuthorized {
        NFTInfo storage nft = nftInfo[_nftID];
        nft.tier2uri = _uri;
    }

    function setNFTwindow(uint256 _nftID, uint256 _timestart, uint256 _timeend) external onlyAuthorized {
        NFTInfo storage nft = nftInfo[_nftID];  

        nft.timestart = _timestart;
        nft.timeend = _timeend;
    }

    function setNFTend(uint256 _nftID, uint256 _timeend) external onlyAuthorized {
        NFTInfo storage nft = nftInfo[_nftID];  

        nft.timeend = _timeend;
    }

    function setNFTOrder(uint256 _nftID, uint256 _order) external onlyAuthorized {
        NFTInfo storage nft = nftInfo[_nftID];

        nft.order = _order;
    }

    function setNFTredeemable(uint256 _nftID, bool _redeemable) external onlyAuthorized {
        NFTInfo storage nft = nftInfo[_nftID];

        nft.redeemable = _redeemable;
    }

    function setNFTsupermintable(uint256 _nftID, bool _supermintable) external onlyAuthorized {
        NFTInfo storage nft = nftInfo[_nftID];

        nft.supermintable = _supermintable;

        if(!nft.supermintable) {nft.supermintend=0;} else {nft.supermintend=nft.timeend.add(supermintSpan);}
    }

    function setNFTsuperminEnd(uint256 _nftID, uint _supermintend) external onlyAuthorized {
        NFTInfo storage nft = nftInfo[_nftID];

        nft.supermintend = _supermintend;
    }

    function setNFTbnbable(uint256 _nftID, bool _bnbable) external onlyAuthorized {
        NFTInfo storage nft = nftInfo[_nftID];

        nft.bnbable = _bnbable;
        
    }

    function setNFTexists(uint256 _nftID, bool _exists) external onlyAuthorized {
        NFTInfo storage nft = nftInfo[_nftID];

        nft.exists = _exists;
    }

    function getIfMinted(address _recipient, uint256 _nftID) external view returns (bool) {
        return nftMinted[_nftID][_recipient];
    }

    function getIfSuperMinted(address _recipient, uint256 _nftID) external view returns (bool) {
        return nftSuperMinted[_nftID][_recipient];
    }

    function getIfMintedTier(address _recipient, uint256 _nftID, uint256 minttier) external view returns (bool) {
        return nftTierMinted[_nftID][_recipient][minttier];
    }

    function getNFTIDbyURI(string memory _uri) public view returns (uint256) {
        uint256 totalNFT = _NFTIds.current();
        uint256 nftID = 0;

        for (uint256 x = 1; x <= totalNFT; ++x) {

            NFTInfo storage nft = nftInfo[x];

            if (keccak256(bytes(nft.tier1uri)) == keccak256(bytes(_uri)) || keccak256(bytes(nft.tier2uri)) == keccak256(bytes(_uri))) {   
                nftID = x;
            }

        }

        return nftID;
    }

    function getNFTwindow(uint256 _nftID) external view returns (uint256,uint256,uint256) {
        NFTInfo storage nft = nftInfo[_nftID];  
        return (nft.timestart,nft.timeend,nft.supermintend);
    }

    function getNFTredeemable(uint256 _nftID) external view returns (bool) {
        NFTInfo storage nft = nftInfo[_nftID];  
        return (nft.redeemable);
    }

    function getNFTsupermintable(uint256 _nftID) external view returns (bool) {
        NFTInfo storage nft = nftInfo[_nftID];  
        return (nft.supermintable);
    }

    function getNFTbnbable(uint256 _nftID) external view returns (bool) {
        NFTInfo storage nft = nftInfo[_nftID];  
        return (nft.bnbable);
    } 

    function getBNBtier1minted(address _recipient, uint _nftID) external view returns (bool) {
        return nftBNBtier1Minted[_nftID][_recipient];
    }

    function getBNBtier2minted(address _recipient, uint _nftID) external view returns (bool) {
        return nftBNBtier2Minted[_nftID][_recipient];
    }

    function getMintTotalsAfterWindow(uint _nftID, uint _tier) external view returns (uint) {
        return mintTotalsAfterWindow[_nftID][_tier];
    }

    function checkWalletforNFT(address _holder, string memory _uri) public view returns (bool nftpresent, uint256[] memory tokens) {

        uint256 nftbalance = IERC721(this).balanceOf(_holder);
        uint256[] memory tokenids = new uint256[](nftbalance);
        bool result;

        if(nftbalance == 0) {return (false, tokenids);}

         for (uint256 y = 0; y < nftbalance; y++) {

             string memory holderuri = tokenURI(tokenOfOwnerByIndex(_holder, y));

            if (keccak256(bytes(_uri)) == keccak256(bytes(holderuri))) {
                result = true;
                tokenids[y] = tokenOfOwnerByIndex(_holder, y);
            }

        }

        return (result, tokenids);
    }

    function setMintTotalsAfterWindow(uint _id, uint _tier, uint _amount) external onlyAuthorized {
        mintTotalsAfterWindow[_id][_tier] = _amount;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

}

