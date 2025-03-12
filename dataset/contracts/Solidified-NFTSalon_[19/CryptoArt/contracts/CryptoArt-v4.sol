    pragma solidity ^0.6.0;
    pragma experimental ABIEncoderV2;

    //import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
    //import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
    import "https://github.com/kole-swapnil/openzepkole/token/ERC721/ERC721.sol";
    import "https://github.com/kole-swapnil/openzepkole/access/Ownable.sol";

    contract SuperArt is ERC721, Ownable {
        using SafeMath for uint256;    
        uint totalBalance  = 0;

        uint256 tokenBatchIndex; //Batch ID
        address payable public SuperWorldWallet; //SupwerWorld address (contract owner)
        
        mapping(uint256 => string[30]) tokenBatch; // Key -> Batch ID  : Value -> Batch Name
        mapping(uint256 => string[30]) tokenType;  // Key -> Batch ID  : Value -> Batch type
        mapping(uint256 => address[5]) royaltyAddressMemory; // Key -> Batch ID  : Value -> creator (artist) address
        mapping(uint256 => uint256[5]) royaltyPercentageMemory;  // Key -> Batch ID  : Value -> percentage cut  for artist and owner

        mapping(uint256 => string) tokenBatchName; // Key -> Batch ID  : Value -> Batch Name
        mapping(uint256 => string) tokenBatchFeatures; // Key -> Batch ID  : Value -> Batch description (features)
        mapping(uint256 => uint256) tokenBatchEditionSize; // Key -> Batch ID  : Value -> how many tokens can we mint in the same batch (group)

        mapping(uint256 => uint256) tokenEditionNumber; // to check later
        mapping(uint256 => uint256) totalCreatedTokens; // Key -> Batch ID  : Value -> How many tokens are created in the same batch
        mapping(uint256 => uint256) totalMintedTokens; // Key -> Batch ID  : Value -> ERC721 tokens already minted under same batch
        mapping(uint256 => uint256) tokenBatchPrice; // Key -> ERC721 token : value ->token price
        mapping(uint256 => string) imgUrl; // Key -> Batch ID : value ->imgUrl
        mapping(uint256 => uint256) royaltyLengthMemory; // Key -> Batch ID  : Value -> Number of royalty parties (ex. artist1, artist2, superworld)
        mapping(uint256 => uint256) royaltyMemory; // to check later
        mapping(uint256 => uint256) referenceTotokenBatch; // Key -> ERC Token Id : Value -> Batch Id
        mapping (uint256 => uint256) tokenOffset ; //NEW: Key -> ERC Token Id : Value -> tokenId offset within some batch
        // tokenId => bought price in wei
        mapping(uint256 => uint256) public boughtPrices;
        // tokenId => sell price in wei
        mapping(uint256 => uint256) public sellPrices;
        // tokenId => is selling
        mapping(uint256 => bool) public isSellings;
        // tokenId => buyId
        mapping(uint256 => uint256) public buyIds;
    

        mapping(uint256 => string) collaboratorNamesMemory; //Key -> Batch ID  : Value -> all collaborators who have made the token

        string tokenBatchURI1; // token URI
        string tokenBatchURI2; // token URI
        
        address public joyContractAddress; // contract address

        constructor() ERC721("SuperArt", "SUPERART") public { // Constructor ("SuperArt", "SUPERART")
            updateURI("https://joyworld.azurewebsites.net/api/HttpTrigger?id="); // for each ERC721 token id
            updatetokenBatchURI("https://joyworldmulti.azurewebsites.net/api/HttpTrigger?id=", "&tokenIndex="); // for each ERC721 token id with batch details with offset
            SuperWorldWallet = 0x9aE048c47aef066E03593D5Edb230E3fa80c3f17;
            //joyContractAddress = 0x6c7B6cc55d4098400aC787C8793205D3E86C37C9;
        }  

        event NewtokenBatchCreated(string tokenHash, string tokenType, string tokenBatchName, string feature, uint256 editionSize, uint256 price, uint256 royalty, uint256 tokenBatchIndex);
        event AddtokenBatchRoyalties(uint256 tokenBatchId, uint256 count);
        event ClearRoyalties(uint256 tokenBatchId);
        event NewtokenAdded(uint256 tokenBatchToUpdate, string tokenHash, string tokenType, uint256 tokenIndex);  
        event UpdateFeature(uint256 tokenBatchToUpdate, string newFeatures);
        event UpdatePrice(uint256 tokenBatchToUpdate, uint256 price);

        function createtokenBatch(string memory _tokenHash, string memory _tokenType,  string memory _tokenBatchName, string memory _feature, uint256 _editionSize, uint256 _price, uint256 _royalty, string memory _imgURL) public onlyOwner {
            tokenBatchIndex++ ;
            tokenBatch[tokenBatchIndex][1] = _tokenHash;
            tokenType[tokenBatchIndex][1] = _tokenType;        
            tokenBatchName[tokenBatchIndex] = _tokenBatchName;
            tokenBatchFeatures[tokenBatchIndex] = _feature;
            tokenBatchEditionSize[tokenBatchIndex] = _editionSize;
            totalCreatedTokens[tokenBatchIndex] = 0;
            totalMintedTokens[tokenBatchIndex] = 0;
            tokenBatchPrice[tokenBatchIndex] = _price;
            imgUrl[tokenBatchIndex] = _imgURL;
            royaltyMemory[tokenBatchIndex] = _royalty;
            emit NewtokenBatchCreated(_tokenHash, _tokenType, _tokenBatchName, _feature, _editionSize,  _price, _royalty, tokenBatchIndex);
        }
        
        /*
        /@params: tokenBatchId is batch id
        */
        function addTokenBatchRoyalties(uint256 tokenBatchId, address[] memory royaltyAddresses, uint256[] memory royaltyPercentage, string memory collaboratorNames) public onlyOwner {
            require(royaltyAddresses.length == royaltyPercentage.length);
            require(royaltyAddresses.length <= 5);
            
            uint256 totalCollaboratorRoyalties;
            collaboratorNamesMemory[tokenBatchId] = collaboratorNames;
            
            for(uint256 i=0; i<royaltyAddresses.length; i++){
                royaltyAddressMemory[tokenBatchId][i] = royaltyAddresses[i];
                royaltyPercentageMemory[tokenBatchId][i] = royaltyPercentage[i];
                totalCollaboratorRoyalties += royaltyPercentage[i];
            }
            
            royaltyLengthMemory[tokenBatchId] = royaltyAddresses.length;
            
            emit AddtokenBatchRoyalties(tokenBatchId, royaltyAddresses.length);
        }

        /*
        /@params: tokenBatchId is batch id
        */
        
        function getRoyalties(uint256 tokenBatchId) public view returns (address[5] memory addresses, uint256[5] memory percentages) {
            for(uint256 i=0; i<royaltyLengthMemory[tokenBatchId]; i++){
                addresses[i] = royaltyAddressMemory[tokenBatchId][i];
                percentages[i] = royaltyPercentageMemory[tokenBatchId][i];
            }    
        }

        /*
        /@params: tokenBatchId is batch id
        */
        function clearRoyalties(uint256 tokenBatchId) public onlyOwner {
            for(uint256 i=0; i<royaltyLengthMemory[tokenBatchId]; i++){
                royaltyAddressMemory[tokenBatchId][i] = 0x0000000000000000000000000000000000000000;
                royaltyPercentageMemory[tokenBatchId][i] = 0;
            }
            
            collaboratorNamesMemory[tokenBatchId] = "";
            royaltyLengthMemory[tokenBatchId] = 0;
            
            emit ClearRoyalties(tokenBatchId);
        }
        
        /*
        /@params: tokenBatchToUpdate is batch id
        */
        // check the access right. Remove onlyOwner to allow artist to call the function?
        function addTokenBatch(uint256 tokenBatchToUpdate, string memory _tokenHash, string memory _tokenType, uint256 _tokenIndex) public onlyOwner{
            require(totalCreatedTokens[tokenBatchToUpdate] < 30);
            tokenBatch[tokenBatchToUpdate][_tokenIndex] = _tokenHash;
            tokenType[tokenBatchToUpdate][_tokenIndex] = _tokenType;
            emit NewtokenAdded(tokenBatchToUpdate, _tokenHash, _tokenType, _tokenIndex);
        }

        /*
        /@params: tokenBatchToUpdate is batch id
        */
        function updateFeature(uint256 tokenBatchToUpdate, string memory newFeatures) public onlyOwner{
            tokenBatchFeatures[tokenBatchToUpdate] = newFeatures; 
            emit UpdateFeature(tokenBatchToUpdate, newFeatures);
        }
        
        /*
        /@params: tokenBatchToUpdate is ERC721 tokenId
        */
        function updatePrice(uint256 tokenBatchToUpdate, uint256 price) public onlyOwner{
            tokenBatchPrice[tokenBatchToUpdate] = price;
            emit UpdatePrice(tokenBatchToUpdate, price/10**18);
        }
        
        /*
        /@params: tokenBatchId is batch id
        */
        function mintTokenBatch(uint256 tokenBatchId, uint256 amountToMint) public onlyOwner {
            require(totalMintedTokens[tokenBatchId] + amountToMint <= tokenBatchEditionSize[tokenBatchId]);
            for(uint256 i=totalMintedTokens[tokenBatchId]; i<amountToMint + totalMintedTokens[tokenBatchId]; i++) {
                uint256 tokenId = totalSupply() + 1;
                referenceTotokenBatch[tokenId] = tokenBatchId;
                tokenEditionNumber[tokenId] = i + 1;
                _safeMint(msg.sender, tokenId);
                totalMintedTokens[tokenBatchId]++;
                tokenOffset[tokenId] = totalMintedTokens[tokenBatchId];
            }
        }

        function withdrawFunds() public onlyOwner {
            msg.sender.transfer(address(this).balance);
        }

        /*
        /@params: tokenBatchId is batch id and index is tokenOffset
        */
        function getTokenBatchData(uint256 tokenBatchId, uint256 index) public view returns (string memory _tokenHash, string memory _tokenType, uint256 _unmintedEditions) {
            _tokenHash = tokenBatch[tokenBatchId][index];
            _tokenType = tokenType[tokenBatchId][index];
            _unmintedEditions = tokenBatchEditionSize[tokenBatchId] - totalMintedTokens[tokenBatchId];
        }

        /*
        /@params: tokenId is ERC721 tokenId
        */
        function getMetadata(uint256 _tokenId) public view returns (string memory _tokenBatchName, uint256 _editionSize, uint256 _editionNumber, string memory _feature, uint256 _price, string memory _collaborators) {
            require(_exists(_tokenId), "Token does not exist."); // checks ERC721 token exists
            uint256 tokenBatchRef = referenceTotokenBatch[_tokenId]; //checks wich batch token belongs to
            
            _tokenBatchName = tokenBatchName[tokenBatchRef];
            _editionSize = tokenBatchEditionSize[tokenBatchRef];
            _editionNumber = tokenEditionNumber[_tokenId];
            _feature = tokenBatchFeatures[tokenBatchRef];
            _price = tokenBatchPrice[tokenBatchRef];
            _collaborators = collaboratorNamesMemory[tokenBatchRef];
        }

        /*
        /@params: tokenId is ERC721 tokenId and index is tokenOffset
        */    
        function getTokenData(uint256 tokenId, uint256 index) public view returns (string memory _tokenHash, string memory _tokenType) {
            require(_exists(tokenId), "Token does not exist.");
            uint256 tokenBatchRef = referenceTotokenBatch[tokenId];
            
            _tokenHash = tokenBatch[tokenBatchRef][index];
            _tokenType = tokenType[tokenBatchRef][index];        
        }
    /*
    function updatePaymentWallet(address payable newWallet) public onlyOwner {
            SuperWorldWallet = newWallet;
        }
    */   
        function updateURI(string memory newURI) public onlyOwner {
            _setBaseURI(newURI);
        }
        
        function updatetokenBatchURI(string memory newURI1, string memory newURI2) public onlyOwner {
            tokenBatchURI1 = newURI1;
            tokenBatchURI2 = newURI2;
        }

        /*
        /@params: ERC721 tokenId and tokenIndex is tokenOffset
        */    
        function tokenBatchURI(uint256 tokenId, uint256 tokenIndex) external view returns (string memory) {
            require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
            return string(abi.encodePacked(tokenBatchURI1, integerToString(tokenId), tokenBatchURI2, integerToString(tokenIndex)));
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

        function putForSale(uint256 _tokenId,uint _sellprice) public{
            //Arts[_tokenId].isSelling = true;
            isSellings[_tokenId] = true;
            //Arts[_tokenId].tokenSellPrice = _sellprice;
            sellPrices[_tokenId] = _sellprice;
            //emit tokenputforsale(_tokenId,msg.sender,_sellprice,true,now);
        }
        function deSale(uint256 _tokenId) public{
            isSellings[_tokenId] = false;
            sellPrices[_tokenId] = 0;
            //emit tokenputforsale(_tokenId,msg.sender,0,false,now);
        }
        
        function _buyToken(uint256 _tokenId,address payable addr,uint256 val) private returns(bool){
            //ArtToken memory y = Arts[_tokenId];
            require(isSellings[_tokenId]);
            require(val >= sellPrices[_tokenId]);
            uint fee;
            uint priceAfterFee;
            bool firstPurchase = false;
            address _seller = ownerOf(_tokenId);
            for (uint i=0; i < 5 ; i++){
                if (tokenOwners[_tokenId] == royaltyAddressMemory[_tokenId][i]) {
                    firstPurchase = true;
                }
            }
            uint256 _batchId = referenceTotokenBatch[_tokenId];
            uint256 _royalLength = royaltyLengthMemory[_batchId];
            if(firstPurchase){
                fee = SafeMath.div(
                SafeMath.mul(sellPrices[_tokenId], 10),
                100
            );
            priceAfterFee = SafeMath.sub(sellPrices[_tokenId], fee);

            for (uint i=0; i<_royalLength ; i++){
                payable(royaltyAddressMemory[_batchId][i]).transfer(priceAfterFee/_royalLength); 
            }
            totalBalance += fee;
            }
            else{
                fee = SafeMath.div(
                SafeMath.mul(sellPrices[_tokenId],10),
                100
            );
            priceAfterFee = SafeMath.sub(sellPrices[_tokenId], fee);
 
            for (uint i=0; i<_royalLength ; i++){
                payable(royaltyAddressMemory[_batchId][i]).transfer((fee/2)/_royalLength); 
            }            
            
            payable(_seller).transfer(priceAfterFee);
            totalBalance = SafeMath.add(SafeMath.div(fee,2),totalBalance);
            }

        // check seller != buyer
        require(msg.sender != _seller);

        // mark not selling
        isSellings[_tokenId] = false;

        // transfer token
        //removeTokenFrom(seller, tokenId);
        //addTokenTo(msg.sender, tokenId);
        _holderTokens[_seller].remove(_tokenId);
        _holderTokens[msg.sender].add(_tokenId);
        return true;
        
        }

}   