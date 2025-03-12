        // pragma solidity ^0.6.0;
        pragma solidity >=0.6.0; 
        pragma experimental ABIEncoderV2;
        
        import "https://github.com/kole-swapnil/openzepkole/token/ERC721/ERC721.sol";
       // import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; 
        import "https://github.com/kole-swapnil/openzepkole/access/Ownable.sol";
        //import "@openzeppelin/contracts/access/Ownable.sol"; 
        
        
        contract Cryptoart is ERC721,Ownable{
            uint256 public percentageCut;
            uint256 public totalbal = 0;
            uint256 public tokenCount = 0;
            uint public batchcounter = 0;
            string public metaUrl; 
            
            
            constructor(uint _percentageCut,string memory _metaurl) public ERC721("SuperArt", "SUPERART"){
                percentageCut = _percentageCut;
                metaUrl = _metaurl;
            }
            
            event tokencreated(uint indexed tokenId,address indexed tokenCreator,uint tokenPrice,uint times,uint batchId);
            event tokenbought(uint indexed tokenId,address indexed newowner,address indexed seller,uint times,uint tokenPrice);
            event tokenputforsale(uint indexed tokenId,address indexed seller,uint sellPrice,bool isListed,uint times);
            event tokenbid(uint indexed tokenId,address indexed stcl,bool isBid,uint close,uint times);
            event bidstarted(uint indexed tokenId,address indexed stcl,uint times);
            struct Panel{
                    uint memcount;
                    address[] allmem;
                    uint panelprice;
                    uint countcritic;
            }
            struct Auction{
                address payable bidder;
                uint bidprice;
                bool isBidding;
            }
            struct ArtToken{
                uint tokenIdentifier;
                string tokenHash;
                address payable tokenCreator;
                address payable tokenOwner;
                bool isSelling;
                uint tokenPrice;
                uint tokenSellPrice;
                string imgurl;
                string tokenTitle;
               // uint tier;
                Panel panel;
                Auction auction;
                uint batchId;
                
            }
            mapping(uint => uint)public batches;
            mapping(uint => ArtToken) public Arts;
            mapping(address => ArtToken[]) public tokensByCreator;
            mapping(address => ArtToken[]) public tokensByOwner; 
            
            function setPercentCut(uint _percent) public {
                percentageCut = _percent;
            }
            function setMetaUrl(string memory _url) public {
                metaUrl = _url;
            }
            
            function createToken(
                address buyer,
                uint256 tokenId
            ) private {
                _mint(buyer, tokenId);
            }
            
            function batchCreator(string memory _tokenHash,string memory _tokenTitle,uint _tokenPrice,string memory _imgurl,uint _nos)public{
                
                    batchcounter++;
                    batches[batchcounter] = _nos;
                    for(uint i=0;i<_nos;i++){
                    create(_tokenHash,_tokenTitle,_tokenPrice,_imgurl,batchcounter);
                    }
                        
                
          
            }
           function create(string memory _tokenHash,string memory _tokenTitle,uint _tokenPrice,string memory _imgurl,uint _batchid)public returns(uint){
                tokenCount++;
                ArtToken memory y;
                y.tokenIdentifier = tokenCount;
                y.tokenHash = _tokenHash;
                y.tokenCreator = msg.sender;
                y.tokenOwner = msg.sender;
                y.isSelling = false;
                y.tokenPrice = _tokenPrice;
                y.imgurl = _imgurl;
                y.tokenTitle = _tokenTitle;
                //y.tier = _tier;
                y.batchId = _batchid;
                Arts[tokenCount] = y;
                createToken(msg.sender,tokenCount);
                tokensByCreator[msg.sender].push(y);
                tokensByOwner[msg.sender].push(y);
                emit tokencreated(tokenCount,msg.sender,_tokenPrice,block.timestamp,_batchid);
                return tokenCount;
            }

            function addtoGallery(uint _tokenId,uint _memcount,address[] calldata _allmem) public {
                ArtToken memory y = Arts[_tokenId];
                y.panel.memcount = _memcount;
                y.panel.allmem = _allmem;
                Arts[_tokenId] = y;
                
            }
            
            function addCriticPrice(uint _tokenId,uint _criticprice) public {
                ArtToken memory y = Arts[_tokenId];
                bool exists;
                for(uint i = 0;i<y.panel.allmem.length;i++){
                    if(msg.sender == y.panel.allmem[i]){
                        exists = true;    
                    }
                    
                }
                
                require(exists);
                
                y.panel.panelprice = ((y.panel.panelprice*y.panel.countcritic) + _criticprice)/y.panel.countcritic++;
                y.panel.countcritic++;
                Arts[_tokenId] = y;
                
            }
            
            function putForSale(uint256 _tokenId,uint _sellprice) public{
                Arts[_tokenId].isSelling = true;
                Arts[_tokenId].tokenSellPrice = _sellprice;
                emit tokenputforsale(_tokenId,msg.sender,_sellprice,true,block.timestamp);
                
            }
            function deSale(uint256 _tokenId) public{
                Arts[_tokenId].isSelling = false;
                Arts[_tokenId].tokenSellPrice = 0;
                emit tokenputforsale(_tokenId,msg.sender,0,false,block.timestamp);
            }
            
            function giftToken(uint256 _tokenId,address payable addr) public payable returns(bool){
                return _buyToken(_tokenId,addr,msg.value);
            }
            
            function buyToken(uint256 _tokenId) public payable returns(bool){
                return _buyToken(_tokenId,msg.sender,msg.value);
            }
            
            
            function _buyToken(uint256 _tokenId,address payable addr,uint256 val) private returns(bool){
               ArtToken memory y = Arts[_tokenId];
               require(y.isSelling);
               require(val >= y.tokenPrice);
               require(val >= y.tokenSellPrice);
               uint fee;
               uint priceAfterFee;
               uint creatorfee;
               uint onlyprice = y.tokenSellPrice;
               if(y.tokenOwner == y.tokenCreator){
                    fee = SafeMath.div(
                    SafeMath.mul(y.tokenSellPrice, percentageCut),
                    100
                );
                priceAfterFee = SafeMath.sub(y.tokenSellPrice, fee);
                y.tokenCreator.transfer(priceAfterFee);
                totalbal += fee;
                   
               }
               else{
                   fee = SafeMath.div(
                    SafeMath.mul(y.tokenSellPrice,percentageCut),
                    100
                );
                
                creatorfee = SafeMath.div(
                    fee,2
                );
                
                priceAfterFee = SafeMath.sub(y.tokenSellPrice, fee);
                   y.tokenCreator.transfer(creatorfee);
                   y.tokenOwner.transfer(priceAfterFee);
                   totalbal = SafeMath.add(SafeMath.div(
                    fee,2),totalbal);
               }
               uint index;
               address seller = y.tokenOwner;
               y.tokenOwner = addr;
               y.isSelling = false;
               y.tokenPrice = y.tokenSellPrice;
               y.tokenSellPrice = 0;
               y.auction.bidprice = 0;
               y.auction.isBidding = false;
               Arts[_tokenId] = y;
               ArtToken[] storage z = tokensByOwner[seller];
               for(uint i = 0;i < z.length;i++){
                   if(_tokenId == z[i].tokenIdentifier){
                       index = i;
                   }     
               }
               delete z[index];
               tokensByOwner[seller] = z;
               tokensByOwner[addr].push(y);
                _holderTokens[seller].remove(_tokenId);
                _holderTokens[addr].add(_tokenId);
                
               emit tokenbought(_tokenId,addr,seller,block.timestamp,onlyprice);
                return true;
            }
            
            function startbid(uint _tokenId) public {
                Arts[_tokenId].auction.isBidding = true;    
                emit tokenbid(_tokenId,msg.sender,true,0,block.timestamp); 
            }
            
            function addBid(uint _tokenId) public payable{
                ArtToken memory y = Arts[_tokenId];
                require(msg.value>y.auction.bidprice);
                if(y.auction.bidder == address(0x0)){
                    y.auction.bidder = msg.sender;
                    y.auction.bidprice = msg.value;
                    y.auction.isBidding = true;
                    emit bidstarted(_tokenId,msg.sender,msg.value);
                    
                }
                else{
                    (y.auction.bidder).transfer(y.auction.bidprice);
                    y.auction.bidder = msg.sender;
                    y.auction.bidprice = msg.value;
                    emit bidstarted(_tokenId,msg.sender,msg.value);
                }
                Arts[_tokenId] = y;
                
            }
            
            function closeBidOwner(uint _tokenId) public {
                ArtToken memory y = Arts[_tokenId];
                require(y.tokenOwner == msg.sender || y.tokenOwner == owner());
                y.tokenSellPrice = y.auction.bidprice;
                Arts[_tokenId] = y;
                _buyToken(_tokenId,y.auction.bidder,y.auction.bidprice);
                ArtToken memory z = Arts[_tokenId];
                z.auction.isBidding = false;
                z.auction.bidder = address(0x0);
                z.auction.bidprice = 0;
                Arts[_tokenId] = z;
                emit tokenbid(_tokenId,msg.sender,false,1,block.timestamp);
            }
            
            function closeBid(uint _tokenId)public{
                 ArtToken memory z = Arts[_tokenId];
                 require(z.auction.bidder == msg.sender);
                 z.auction.bidder.transfer(z.auction.bidprice);
                 z.auction.bidder = address(0x0);
                 z.auction.bidprice = 0;
                 Arts[_tokenId] = z;
                 emit tokenbid(_tokenId,msg.sender,false,2,block.timestamp);
            }
            
            function tokenURI(uint256 tokenId) public view override returns (string memory) {
                return string(abi.encodePacked(metaUrl,integerToString(tokenId)));
            
            }
            
            function integerToString(uint _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        
        uint j = _i;
        uint len;
      
        while (j != 0) {
            len++;
            j /= 10;
        }
      
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
      
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
            _i /= 10;
        }
      return string(bstr);
    }    
            
            function withdrawBalance() public payable onlyOwner() {
                (msg.sender).transfer(totalbal);
            }
            
            function FinalWithdrawBal() public payable onlyOwner() {
                uint256 balance = address(this).balance;
                (msg.sender).transfer(balance);
            }
        
           
        }