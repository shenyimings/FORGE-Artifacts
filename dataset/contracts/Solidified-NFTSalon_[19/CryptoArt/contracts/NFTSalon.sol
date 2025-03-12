pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.0/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.0/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.0/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.0/contracts/utils/structs/EnumerableSet.sol";


contract NFTSalon is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    uint totalBalance  = 0;
    string public metaUrl;
    uint256 public percentageCut;

    constructor(uint _percentageCut,string memory _metaurl) ERC721("SuperAsset", "SUPERASSET") {
        percentageCut = _percentageCut;
        metaUrl = _metaurl;
    }

    function setPercentCut(uint _percent) public onlyOwner {
        percentageCut = _percent;
    }

    function setMetaUrl(string memory _url) public onlyOwner {
        metaUrl = _url;
    }

    //Batch Start
    uint256 public tokenBatchIndex; //Batch ID
    mapping(uint256 => string) public tokenBatch; // Key -> Batch ID  : Value -> Batch Hash
    mapping(uint256 => string) public tokenBatchName; // Key -> Batch ID  : Value -> Batch Title
    mapping(uint256 => uint256) public tokenBatchEditionSize; // Key -> Batch ID  : Value -> how many tokens can we mint in the same batch (group)
    mapping(uint256 => uint256) public totalMintedTokens; // Key -> Batch ID  : Value -> ERC721 tokens already minted under same batch
    mapping(uint256 => address) public tokenCreator; // Key -> Batch ID : value -> address of creator
    mapping(uint256 => string) public imgUrl; // Key -> Batch ID : value -> imgUrl
    mapping(uint256 => string) public thumbNail; // Key -> Batch ID : value -> thumbnail url
    mapping(uint256 => address payable [5]) public royaltyAddressMemory; // Key -> Batch ID  : Value -> creator (artist) address
    mapping(uint256 => uint256[5]) public royaltyPercentageMemory;  // Key -> Batch ID  : Value -> percentage cut  for artist and owner
    mapping(uint256 => uint256) public royaltyLengthMemory; // Key -> Batch ID  : Value -> Number of royalty parties (ex. artist1, artist2)
    mapping(uint256 => bool) public openMinting; // Key -> Batch ID  : Value -> minting open or not
    mapping(uint256 => uint256) tokenBatchPrice; // Key -> Batch ID  : Value -> price of Batch
    //Batch end
    
    mapping(address => EnumerableSet.UintSet) internal tokensOwnedByWallet;
    mapping(uint256 => address) tokenOwner;
    mapping(uint256 => bool) public isSellings;
    mapping(uint256 => uint256) public sellPrices;
    mapping(uint256 => uint256) public tokenEditionNumber;
    mapping(uint256 => uint256) public referenceTotokenBatch;
    mapping(uint256 => Auction) public auctions;
    //Token end

    struct Auction {
        address payable bidder;
        uint bidPrice;
        bool isBidding;
        uint bidEnd;
    }

    //Event
    event NewTokenBatchCreated(string tokenHash, string tokenBatchName, uint256 editionSize, uint256 price, uint256 tokenBatchIndex, address creator);
    event tokenCreated(uint indexed tokenId, address indexed tokenCreator, uint timestamp, uint indexed batchId);
    event tokenPutForSale(uint indexed tokenId, address indexed seller, uint sellPrice, bool isListed, uint timestamp);
    event tokenBid(uint indexed tokenId, address indexed bidder, uint tokenPrice, uint timestamp);
    event bidStarted(uint indexed tokenId, address indexed lister, bool isBid, uint tokenPrice, uint endTime, bool isClosedBySuperWorld, uint timestamp);
    event tokenBought(uint indexed tokenId, address indexed newowner, address indexed seller, uint timestamp, uint tokenPrice);
    //Event

    modifier ownerToken(uint256 tokenId) {
        require(tokenOwner[tokenId] == msg.sender);
        _;
    }
    
    modifier creatorToken(uint256 tokenBatchId) {
        require(tokenCreator[tokenBatchId] == msg.sender);
        _;
    }
    
    // **
    // Use : Creates a token batch
    // Input : token hash, batch name, edition size, price, and imageURL
    // Output : New token batch with hash, name, size, price, and imageUrl
    function createTokenBatch(string memory _tokenHash,  string memory _tokenBatchName,  uint256 _editionSize, uint256 _price, string memory _imgUrl, string memory _imgThumbnail) public returns(uint256) {
        tokenBatchIndex++;
        tokenBatch[tokenBatchIndex] = _tokenHash;
        tokenBatchName[tokenBatchIndex] = _tokenBatchName;
        tokenBatchEditionSize[tokenBatchIndex] = _editionSize;
        totalMintedTokens[tokenBatchIndex] = 0;
        tokenBatchPrice[tokenBatchIndex] = _price;
        imgUrl[tokenBatchIndex] = _imgUrl;
        thumbNail[tokenBatchIndex] = _imgThumbnail;
        tokenCreator[tokenBatchIndex] = msg.sender;
        emit NewTokenBatchCreated(_tokenHash, _tokenBatchName, _editionSize, _price, tokenBatchIndex, msg.sender);
        return tokenBatchIndex;
    }

    // Used for Opening/Closing a minting session
    // Input : toke price, bool (True Opening minting session/False = Closing minting session)
    // Output : Mintting status
    function openCloseMint(uint256 tokenBatchToUpdate, uint256 _price, bool _isOpen) public creatorToken(tokenBatchToUpdate) {
        openMinting[tokenBatchToUpdate] = _isOpen;
        tokenBatchPrice[tokenBatchToUpdate] = _price;
    }

    // Use : Adds up to five addresses to recieve royalty percentages
    // Input : Token Batch Id, array of adresses, array of percentages
    // Output :  Added royalties and their percentages
    function addTokenBatchRoyalties(uint256 tokenBatchId, address[] memory _royaltyAddresses, uint256[] memory _royaltyPercentage) public creatorToken(tokenBatchId){
        require(_royaltyAddresses.length == _royaltyPercentage.length);
        require(_royaltyAddresses.length <= 5);
        uint256 totalCollaboratorRoyalties;
        for(uint256 i=0; i<_royaltyAddresses.length; i++){
            royaltyAddressMemory[tokenBatchId][i] = payable(_royaltyAddresses[i]);
            royaltyPercentageMemory[tokenBatchId][i] = _royaltyPercentage[i];
            totalCollaboratorRoyalties += _royaltyPercentage[i];
        }
        require(totalCollaboratorRoyalties <= 100);
        royaltyLengthMemory[tokenBatchId] = _royaltyAddresses.length;


    }

    // Use : Getter function for royalty addresses and proyalty percerntages
    // Input : Token Batch ID
    // Output : Puts royalty addresses and royalty percentages into two seperate arrays
    function getRoyalties(uint256 tokenBatchId) public view returns (address[5] memory addresses, uint256[5] memory percentages) {
        for(uint256 i=0; i<royaltyLengthMemory[tokenBatchId]; i++){
            addresses[i] = royaltyAddressMemory[tokenBatchId][i];
            percentages[i] = royaltyPercentageMemory[tokenBatchId][i];
        }
    }
    //Not Gonna use this
    // Use : Removes royalties only owner of the batch can do this
    // Input : Token Batch ID
    // Output : Removes all royalty adresses
    // function clearRoyalties(uint256 tokenBatchId) public creatorToken(tokenBatchId) {
    //     for (uint256 i=0; i<royaltyLengthMemory[tokenBatchId]; i++) {
    //         royaltyAddressMemory[tokenBatchId][i] = payable(address(0x0));
    //         royaltyPercentageMemory[tokenBatchId][i] = 0;
    //     }

    //     royaltyLengthMemory[tokenBatchId] = 0;
    // }

    // Use : Minting new tokens from batch
    // Input : Token Batch ID, minting amount
    // Output : minted token(s)
    function mintTokenBatch(uint256 tokenBatchId, uint256 amountToMint) public payable{
        for (uint i = 0 ; i<amountToMint; i++) {
            mintToken(tokenBatchId);
        }
    }

    function mintToken(uint256 tokenBatchId) public payable{
        uint safeState = totalMintedTokens[tokenBatchId] + 1;
        uint256 tokenId;
        
        if (openMinting[tokenBatchId]) {
            require(safeState <= tokenBatchEditionSize[tokenBatchId]);   
            tokenId = totalSupply() + 1;
            _safeMint(msg.sender, tokenId);
            uint256 totalMoney = msg.value;             //100 Ethers
            address payable royaltyPerson;
            uint256 royaltyPercent;
            uint256 x;
            uint fee = SafeMath.div(
                SafeMath.mul(msg.value, percentageCut),   //15 percentageCut fee = 15 ETH 
                100
                );
            totalMoney = SafeMath.sub(totalMoney, fee);         //totalMoney = 85
            totalBalance += fee;                            
        
            uint priceAfterFee = totalMoney;                    //priceAfterFee = 85
            for (uint256 i=0; i<royaltyLengthMemory[tokenBatchId]; i++) {   // 20 30 10 15 25 = 100
                royaltyPerson = royaltyAddressMemory[tokenBatchId][i];
                royaltyPercent = royaltyPercentageMemory[tokenBatchId][i];
                x = SafeMath.div(
                    SafeMath.mul(priceAfterFee, royaltyPercent),
                    100 
                );
            totalMoney = SafeMath.sub(totalMoney, x);
            royaltyPerson.transfer(x);                            //17 25.5 10 12.75 21.25
        }
            if (totalMoney > 0) {
            (payable(tokenCreator[tokenBatchId])).transfer(totalMoney);    
            }
            tokenOwner[tokenId] = msg.sender;
            referenceTotokenBatch[tokenId] = tokenBatchId;
            totalMintedTokens[tokenBatchId]++;
            tokenEditionNumber[tokenId] = totalMintedTokens[tokenBatchId];
            tokensOwnedByWallet[msg.sender].add(tokenId);
        }
        else {
            require(tokenCreator[tokenBatchId] == msg.sender);
            require(safeState <= tokenBatchEditionSize[tokenBatchId]);
            tokenId = totalSupply() + 1;
            _safeMint(msg.sender, tokenId);
            tokenOwner[tokenId] = msg.sender;
            referenceTotokenBatch[tokenId] = tokenBatchId;
            totalMintedTokens[tokenBatchId]++;
            tokenEditionNumber[tokenId] = totalMintedTokens[tokenBatchId];
            tokensOwnedByWallet[msg.sender].add(tokenId);
        }
        emit tokenCreated(tokenId, msg.sender, block.timestamp, tokenBatchId);
    }

    // Use : List token for sell (It you want to resell you re-list)
    // Input : Token ID, selling price, is lisred should be true
    // Output : Token ID, sellprice, if it is listed, timestamp
    function sale(uint256 _tokenId, uint _sellPrice, bool isListed) public ownerToken(_tokenId) { 
        isSellings[_tokenId] = isListed;
        sellPrices[_tokenId] = _sellPrice;
        emit tokenPutForSale(_tokenId, msg.sender, _sellPrice, isListed, block.timestamp);
    }

    function bulkSale(uint256[] memory _tokens, uint _sellPrice, bool _isListed) public { //moresale casing //change name
        for (uint i=0; i<_tokens.length; i++) {
            sale(_tokens[i], _sellPrice, _isListed);
        }
    }

    // **
    // Use : Gets all information about the batch from the Token Batch ID
    // Input : Token Batch ID
    // Output : Token hash, token batch name, token batch edition size, token creator, and image URL
    function getTokenBatchData(uint256 tokenBatchId) public view returns (uint256 _batchId, string memory _tokenHash, string memory _tokenBatchName, uint256 _unmintedEditions, address _tokenCreator, string memory _imgUrl, string memory _imgThumbnail, uint256 _mintedEditions) {
        _batchId = tokenBatchId;
        _tokenHash = tokenBatch[tokenBatchId];
        _tokenBatchName = tokenBatchName[tokenBatchId];
        _unmintedEditions = tokenBatchEditionSize[tokenBatchId] - totalMintedTokens[tokenBatchId];
        _mintedEditions = totalMintedTokens[tokenBatchId];
        _tokenCreator = tokenCreator[tokenBatchId];
        _imgUrl = imgUrl[tokenBatchId];
        _imgThumbnail = thumbNail[tokenBatchId];
    }


    // Use : Gets all information about a token from the Token ID
    // Input : Token id
    // Output : Token hash, token batch name, token batch edition size, token creator, and image URL Token owner, if it is currently for sale, sell price, referefence to its token batch, auctions, token bidder, if it is bidding, and bid price
    function getTokenData(uint256 tokenId) public view returns (string memory _tokenHash, string memory _tokenBatchName, address _tokenCreator, string memory _imgUrl, string memory _imgThumbnail, address _tokenOwner, bool _isSellings, uint _sellPrice, uint _refBatch, Auction memory _aucObj, uint _tokenId, uint256 _editionNo) {
        require(_exists(tokenId), "Not exist");
        _refBatch = referenceTotokenBatch[tokenId];
        _tokenHash = tokenBatch[_refBatch];
        _tokenBatchName = tokenBatchName[_refBatch];
        _tokenCreator = tokenCreator[_refBatch];
        _imgUrl = imgUrl[_refBatch];
        _imgThumbnail = thumbNail[_refBatch];
        _tokenOwner = tokenOwner[tokenId];
        _isSellings = isSellings[tokenId];
        _sellPrice = sellPrices[tokenId];
        _aucObj = auctions[tokenId];
        _tokenId = tokenId;
        _editionNo = tokenEditionNumber[tokenId];

    }

    // Use : Start a bid
    // Input : Token ID and start price
    // Output : Emit bidStarted event by giving token ID, address, setting event to true, false(represents the creator), and time stamp
    function startBid(uint _tokenId, uint256 _startPrice, uint _endTimestamp) public ownerToken(_tokenId){
        auctions[_tokenId].bidEnd = _endTimestamp;
        auctions[_tokenId].isBidding = true; 
        auctions[_tokenId].bidPrice = _startPrice;
        emit bidStarted(_tokenId, msg.sender, true, _startPrice, _endTimestamp, false, block.timestamp);
    }

    // Use : Add a bid to auction
    // Input : Token ID
    // Output : Emit tokenBid event by giving token id, bidder adress, bid ammount, and timestamp
    function addBid(uint _tokenId) public payable{
        require(auctions[_tokenId].isBidding);
        require(msg.value > auctions[_tokenId].bidPrice);
        if (auctions[_tokenId].bidder == payable(address(0x0))){
            auctions[_tokenId].bidder = payable(msg.sender);
            auctions[_tokenId].bidPrice = msg.value;
            auctions[_tokenId].isBidding = true;
            emit tokenBid(_tokenId, msg.sender, msg.value, block.timestamp);
        }
        else{
            (auctions[_tokenId].bidder).transfer(auctions[_tokenId].bidPrice);
            auctions[_tokenId].bidder = payable(msg.sender);
            auctions[_tokenId].bidPrice = msg.value;
            emit tokenBid(_tokenId, msg.sender, msg.value, block.timestamp);
        }
    }

    // Use : Allows SuperWorld to close a bid
    // Input : Token ID
    // Output : Emit bidStarted event by giving token ID, address, sets bidding to false, true(represents SuperWorld) and, timestamp
    function closeBid(uint _tokenId) public onlyOwner{
        require(auctions[_tokenId].bidEnd < block.timestamp);
        auctions[_tokenId].bidder.transfer(auctions[_tokenId].bidPrice);
        auctions[_tokenId].bidder = payable(address(0x0));
        auctions[_tokenId].bidPrice = 0;
        emit bidStarted(_tokenId, msg.sender, false, 0, 0, true, block.timestamp);
    }

    // Use : Getter function for token URL
    // Input : Token Id
    // Output : Striong URL
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(metaUrl, integerToString(tokenId)));

    }

    // Use : Buy a token
    // Input : Token ID
    // Output : Calls _buyToken event by giving Token ID, address, buy amount, and 1(represents buy function)
    function buyToken(uint256 _tokenId) public payable returns(bool) {
        require(isSellings[_tokenId]);
        require(msg.value >= sellPrices[_tokenId]);
        return _buyToken(_tokenId, payable(msg.sender), msg.value, 1);
    }

    // Use : Buy a token
    // Input : Token ID, address that will be paid, cost amount, and 1(represents the creator)
    // Output : Boolean
    function _buyToken(uint256 _tokenId, address payable addr, uint256 _price, uint8 _type) private returns(bool) {
        uint256 totalMoney = _price;             //100 Ethers
        address payable royaltyPerson;
        uint256 royaltyPercent;
        uint256 x;
        uint fee = SafeMath.div(
            SafeMath.mul(_price, percentageCut),   //15 percentageCut fee = 15 ETH 
            100
        );
        totalMoney = SafeMath.sub(totalMoney, fee);         //totalMoney = 85
        totalBalance += fee;                            
        uint256 batchId = referenceTotokenBatch[_tokenId];
        uint priceAfterFee = totalMoney;                    //priceAfterFee = 85
        for (uint256 i=0; i<royaltyLengthMemory[batchId]; i++) {   // 20 30 10 15 25 = 100
            royaltyPerson = royaltyAddressMemory[batchId][i];
            royaltyPercent = royaltyPercentageMemory[batchId][i];
            x = SafeMath.div(
                SafeMath.mul(priceAfterFee, royaltyPercent),
                100
            );
            totalMoney = SafeMath.sub(totalMoney, x);
            royaltyPerson.transfer(x);                            //17 25.5 10 12.75 21.25 = 85
        }
        
        address payable seller = payable(tokenOwner[_tokenId]);        //totalMoney = 0
        if (totalMoney > 0) {
            seller.transfer(totalMoney);    
        }
        
        tokenOwner[_tokenId] = addr;
        isSellings[_tokenId] = false;
        sellPrices[_tokenId] = 0;
        if (_type == 1) {
            emit tokenPutForSale(_tokenId, seller, 0, false, block.timestamp);
        }
        auctions[_tokenId].isBidding = false;
        auctions[_tokenId].bidder = payable(address(0x0));
        auctions[_tokenId].bidPrice = 0;
        if (_type == 2) {
            emit bidStarted(_tokenId, seller, false, 0, 0, false, block.timestamp);
        }

        _transfer(seller, addr, _tokenId);
        tokensOwnedByWallet[seller].remove(_tokenId);
        tokensOwnedByWallet[addr].add(_tokenId);
        
        emit tokenBought(_tokenId, addr, seller, block.timestamp, _price);
        return true;
    }

    // Use : Close bid by owner
    // Input : Token ID
    // Output : Calls _buytoken function by giving Token ID, bidder,bid price, and 2(triggers a two in _buytoken function)
    function closeBidOwner(uint _tokenId)public ownerToken(_tokenId) returns(bool) {
        if (auctions[_tokenId].bidder == payable(address(0x0))) {
            auctions[_tokenId].bidEnd = 0;
            auctions[_tokenId].isBidding = false;
            auctions[_tokenId].bidPrice = 0;
            address _tokenOwner = tokenOwner[_tokenId];
            emit bidStarted(_tokenId, _tokenOwner, false, 0, 0, false, block.timestamp);
            return true;
        }
        else {
            require(auctions[_tokenId].bidEnd < block.timestamp);
            require(auctions[_tokenId].isBidding);
            return _buyToken(_tokenId, auctions[_tokenId].bidder, auctions[_tokenId].bidPrice, 2);
        }
    }
    
    function getSellingNFTs(address _owner)public view returns(string memory){
        uint len = EnumerableSet.length(tokensOwnedByWallet[_owner]);
        string memory intString;
       
        for(uint j = 0; j<len; j++){
            if (j > 0){
                intString = string(abi.encodePacked(intString, ",", integerToString((EnumerableSet.at(tokensOwnedByWallet[_owner], j)))));
            }
            else {
                intString = string(abi.encodePacked(intString, integerToString((EnumerableSet.at(tokensOwnedByWallet[_owner], j)))));
            }
         }
        return intString;
    }

    // Use : Withdraw funds from smart contract owned by SW
    // Input : None
    // Output : Transfer iniated
    function withdrawBalance() public payable onlyOwner() {
        (payable(msg.sender)).transfer(totalBalance);
    }

    // Use : Withdraw all funds
    // Input : None
    // Output : Transfer iniated
    function FinalWithdrawBal() public payable onlyOwner() {
        uint256 balance = address(this).balance;
        (payable(msg.sender)).transfer(balance);
    }

    // Use : Converts an integer to a string
    // Input : Integer
    // Output : String

    function integerToString(uint256 _i)internal pure returns (string memory str){
        if (_i == 0){
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0){
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0)
        {
            bstr[--k] = bytes1(uint8(48 + j % 10));
            j /= 10;
        }
        str = string(bstr);
    }
}
