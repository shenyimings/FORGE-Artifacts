
/**
 *Submitted for verification at Etherscan.io on 2020-12-30
*/

pragma solidity ^0.6.0;
 pragma experimental ABIEncoderV2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/token/ERC721/ERC721.sol";
interface JOYContract {
    function ownerOf(uint256 tokenId) external view returns (address owner);
}
 
contract JOYtoys is ERC721, Ownable {
    using SafeMath for uint256;    

    string public joyGalleryLink;
    uint256 JOYtoyIndex;
    address payable public joyWallet;
    
    mapping(uint256 => string[30]) JOYtoyArtwork;
    mapping(uint256 => string[30]) artworkTypeMemory;    
    mapping(uint256 => bool[30]) artworkSlotFilled;    
    mapping(uint256 => address[5]) royaltyAddressMemory;
    mapping(uint256 => uint256[5]) royaltyPercentageMemory;    
    
    mapping(uint256 => string) toyNameMemory;
    mapping(uint256 => string) featuresMemory;
    mapping(uint256 => uint256) editionSizeMemory;
    mapping(uint256 => string) powerMemory;
    mapping(uint256 => uint256) editionNumberMemory;
    mapping(uint256 => uint256) totalCreated;
    mapping(uint256 => uint256) totalMinted;
    mapping(uint256 => bool) vendingMachineMode;
    mapping(uint256 => uint256) priceMemory;
    mapping(uint256 => uint256) royaltyLengthMemory;
    mapping(uint256 => uint256) royaltyMemory;
    mapping(uint256 => uint256) artworkJOYtoyReference;
    mapping (uint256 => bool) toyMintingActive;

    mapping(uint256 => uint256) joyCollabTokenId;    
    mapping(uint256 => address) joyHolderCollaborator;
    mapping(uint256 => bool) joyHolderCollabActive;
    mapping(uint256 => uint256) joyHolderCollabPercent;
    mapping(uint256 => string) collaboratorNamesMemory;

    string JOYtoyURI1;
    string JOYtoyURI2;
    
    address public joyContractAddress;
    JOYContract joyWorld;
    
    string public artist = "John Orion Young";
    string public artworkTypeList;
    
    constructor() ERC721("JOYWORLD JOYtoys", "JOYtoy") public {
    JOYtoyIndex = 1;
    updateURI("https://joyworld.azurewebsites.net/api/HttpTrigger?id=");
    updateJOYtoyURI("https://joyworldmulti.azurewebsites.net/api/HttpTrigger?id=", "&artworkIndex=");
    joyWallet = 0x9aE048c47aef066E03593D5Edb230E3fa80c3f17;
    joyContractAddress = 0x6c7B6cc55d4098400aC787C8793205D3E86C37C9;
    joyWorld = JOYContract(joyContractAddress);
    }  

    event NewJOYtoyCreated(string artworkHash, string artworkType, string power, string toyName, string feature, uint256 editionSize, bool vendingMachine, uint256 price, uint256 royalty, uint256 JOYtoyIndex);
    event AddJOYtoyRoyalties(uint256 JOYtoyId, uint256 count);
    event AddJOYCollector(uint256 JOYtoyId, uint256 joyTokenId, uint256 joyCollectorPercent, bool collectorActive);    
    event ClearRoyalties(uint256 JOYtoyId);
    event NewArtworkAdded(uint256 JOYtoyToUpdate, string artworkHash, string artworkType, uint256 artworkIndex);  
    event UpdateFeature(uint256 JOYtoyToUpdate, string newFeatures);
    event UpdatePrice(uint256 JOYtoyToUpdate, uint256 price);
    event CloseJOYtoyWindow(uint256 JOYtoyId);
    
    function createJOYtoy(string memory artworkHash, string memory artworkType, string memory power, string memory toyName, string memory feature, uint256 editionSize, bool vendingMachine, uint256 price, uint256 royalty) public onlyOwner {
        toyMintingActive[JOYtoyIndex] = true;
        
        JOYtoyArtwork[JOYtoyIndex][1] = artworkHash;
        artworkTypeMemory[JOYtoyIndex][1] = artworkType;
        powerMemory[JOYtoyIndex] = power;
        toyNameMemory[JOYtoyIndex] = toyName;
        featuresMemory[JOYtoyIndex] = feature;
        editionSizeMemory[JOYtoyIndex] = editionSize;
        totalCreated[JOYtoyIndex] = 0;
        totalMinted[JOYtoyIndex] = 0;
        artworkSlotFilled[JOYtoyIndex][1] = true;
        vendingMachineMode[JOYtoyIndex] = vendingMachine;
        priceMemory[JOYtoyIndex] = price;
        royaltyMemory[JOYtoyIndex] = royalty;
        
        emit NewJOYtoyCreated(artworkHash, artworkType, power, toyName, feature, editionSize, vendingMachine, price, royalty, JOYtoyIndex);
            
        JOYtoyIndex = JOYtoyIndex + 1;
    }
    
    function addJOYtoyRoyalties(uint256 JOYtoyId, address[] memory royaltyAddresses, uint256[] memory royaltyPercentage, string memory collaboratorNames) public onlyOwner {
        require(royaltyAddresses.length == royaltyPercentage.length);
        require(royaltyAddresses.length <= 5);
        
        uint256 totalCollaboratorRoyalties;
        collaboratorNamesMemory[JOYtoyId] = collaboratorNames;
        
        for(uint256 i=0; i<royaltyAddresses.length; i++){
            royaltyAddressMemory[JOYtoyId][i] = royaltyAddresses[i];
            royaltyPercentageMemory[JOYtoyId][i] = royaltyPercentage[i];
            totalCollaboratorRoyalties = totalCollaboratorRoyalties + royaltyPercentage[i];
        }
        
        royaltyLengthMemory[JOYtoyId] = royaltyAddresses.length;
        
        emit AddJOYtoyRoyalties(JOYtoyId, royaltyAddresses.length);
    }
    
    function getRoyalties(uint256 JOYtoyId) public view returns (address[5] memory addresses, uint256[5] memory percentages) {
        for(uint256 i=0; i<royaltyLengthMemory[JOYtoyId]; i++){
            addresses[i] = royaltyAddressMemory[JOYtoyId][i];
            percentages[i] = royaltyPercentageMemory[JOYtoyId][i];
        }    
    }
    
    function addJOYCollector(uint256 JOYtoyId, uint256 joyTokenId, uint256 joyCollectorPercent, bool collectorActive) public onlyOwner {
        joyCollabTokenId[JOYtoyId] = joyTokenId;
        joyHolderCollaborator[JOYtoyId] = originalJOYOwner(joyTokenId);
        joyHolderCollabPercent[JOYtoyId] = joyCollectorPercent;
        joyHolderCollabActive[JOYtoyId] = collectorActive;
        
        emit AddJOYCollector(JOYtoyId, joyTokenId, joyCollectorPercent, collectorActive);
    }
    
    function getJoyCollaborator(uint256 JOYtoyId) public view returns (uint256 joyTokenId, address joyTokenHolder, uint256 joyCollectorPercent, bool collectorActive) {
        joyTokenId = joyCollabTokenId[JOYtoyId];
        joyTokenHolder = joyHolderCollaborator[JOYtoyId];
        joyCollectorPercent = joyHolderCollabPercent[JOYtoyId];
        collectorActive = joyHolderCollabActive[JOYtoyId];
    }
    
    function clearRoyalties(uint256 JOYtoyId) public onlyOwner {
        for(uint256 i=0; i<royaltyLengthMemory[JOYtoyId]; i++){
            royaltyAddressMemory[JOYtoyId][i] = 0x0000000000000000000000000000000000000000;
            royaltyPercentageMemory[JOYtoyId][i] = 0;
        }
        
        collaboratorNamesMemory[JOYtoyId] = "";
        royaltyLengthMemory[JOYtoyId] = 0;
        
        emit ClearRoyalties(JOYtoyId);
    }
  
    function addJOYtoyArtwork(uint256 JOYtoyToUpdate, string memory artworkHash, string memory artworkType, uint256 artworkIndex) public onlyOwner{
        require(artworkSlotFilled[JOYtoyToUpdate][artworkIndex] == false);
        
        JOYtoyArtwork[JOYtoyToUpdate][artworkIndex] = artworkHash;
        artworkTypeMemory[JOYtoyToUpdate][artworkIndex] = artworkType;
            
        artworkSlotFilled[JOYtoyToUpdate][artworkIndex] = true;
        
        emit NewArtworkAdded(JOYtoyToUpdate, artworkHash, artworkType, artworkIndex);
    }

    function updateFeature(uint256 JOYtoyToUpdate, string memory newFeatures) public onlyOwner{
        featuresMemory[JOYtoyToUpdate] = newFeatures; 
        
        emit UpdateFeature(JOYtoyToUpdate, newFeatures);
    }
   
    function updatePrice(uint256 JOYtoyToUpdate, uint256 price) public onlyOwner{
        priceMemory[JOYtoyToUpdate] = price;
        
        emit UpdatePrice(JOYtoyToUpdate, price/10**18);
    }
    
    function mintJOYtoy(uint256 JOYtoyId, uint256 amountToMint) public onlyOwner {
        require(toyMintingActive[JOYtoyId] == true);
        require(totalMinted[JOYtoyId] + amountToMint <= editionSizeMemory[JOYtoyId]);
        
        for(uint256 i=totalMinted[JOYtoyId]; i<amountToMint + totalMinted[JOYtoyId]; i++) {
            uint256 tokenId = totalSupply() + 1;
            artworkJOYtoyReference[tokenId] = JOYtoyId;
            editionNumberMemory[tokenId] = i + 1;

            _safeMint(msg.sender, tokenId);
        }

        totalMinted[JOYtoyId] = totalMinted[JOYtoyId] + amountToMint;
        
        if (totalMinted[JOYtoyId] == editionSizeMemory[JOYtoyId]) {
            closeJOYtoyWindow(JOYtoyId);
        }
    }

    function JOYtoyMachine(uint256 JOYtoyId) public payable {
        require(toyMintingActive[JOYtoyId] == true);
        require(totalMinted[JOYtoyId] + 1 <= editionSizeMemory[JOYtoyId]);
        require(vendingMachineMode[JOYtoyId] == true);
        require(msg.value == priceMemory[JOYtoyId]);
        
        uint256 tokenId = totalSupply() + 1;
        artworkJOYtoyReference[tokenId] = JOYtoyId;
        editionNumberMemory[tokenId] = totalMinted[JOYtoyId] + 1;
        
        (address[5] memory royaltyAddress, uint256[5] memory percentage) = getRoyalties(JOYtoyId); 
        
        for(uint256 i=0; i<royaltyLengthMemory[JOYtoyId]; i++){
            address payable artistWallet = address(uint160(royaltyAddress[i]));
            artistWallet.transfer(msg.value/100*percentage[i]);   
        }
        
        if(joyHolderCollabActive[JOYtoyId] == true){
            address payable joyHolder = address(uint160(joyHolderCollaborator[JOYtoyId]));
            uint256 joyHolderPercentage = joyHolderCollabPercent[JOYtoyId];
            
            joyHolder.transfer(msg.value/100*joyHolderPercentage);
        }
        
        joyWallet.transfer(address(this).balance);

        _safeMint(msg.sender, tokenId);

        totalMinted[JOYtoyId] = totalMinted[JOYtoyId] + 1;
        
        if (totalMinted[JOYtoyId] == editionSizeMemory[JOYtoyId]) {
            closeJOYtoyWindow(JOYtoyId);
        }
    }

    function closeJOYtoyWindow(uint256 JOYtoyId) public onlyOwner {
        toyMintingActive[JOYtoyId] = false;
        editionSizeMemory[JOYtoyId] = totalMinted[JOYtoyId];
        
        emit CloseJOYtoyWindow(JOYtoyId); 
    }
    
    function withdrawFunds() public onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    function getJOYtoyArtworkData(uint256 JOYtoyId, uint256 index) public view returns (string memory artworkHash, string memory artworkType, uint256 unmintedEditions) {
        artworkHash = JOYtoyArtwork[JOYtoyId][index];
        artworkType = artworkTypeMemory[JOYtoyId][index];
        unmintedEditions = editionSizeMemory[JOYtoyId] - totalMinted[JOYtoyId];

    }
    
    function getMetadata(uint256 tokenId) public view returns (string memory toyName, string memory power, uint256 editionSize, uint256 editionNumber, bool vendingMachine, string memory feature, uint256 price, string memory collaborators, bool toyActive) {
        require(_exists(tokenId), "Token does not exist.");
        uint256 JOYtoyRef = artworkJOYtoyReference[tokenId];
        
        toyName = toyNameMemory[JOYtoyRef];
        power = powerMemory[JOYtoyRef];
        editionSize = editionSizeMemory[JOYtoyRef];
        editionNumber = editionNumberMemory[tokenId];
        vendingMachine = vendingMachineMode[JOYtoyRef];
        feature = featuresMemory[JOYtoyRef];
        price = priceMemory[JOYtoyRef];
        collaborators = collaboratorNamesMemory[JOYtoyRef];
        toyActive = toyMintingActive[JOYtoyRef];
    }
    
    function getRoyaltyData(uint256 tokenId) public view returns (address artistAddress, uint256 royaltyFeeById) {
        require(_exists(tokenId), "Token does not exist.");
        uint256 JOYtoyRef = artworkJOYtoyReference[tokenId];
        
        artistAddress = joyWallet;
        royaltyFeeById = royaltyMemory[JOYtoyRef];
    }
    
    function getArtworkData(uint256 tokenId, uint256 index) public view returns (string memory artworkHash, string memory artworkType) {
        require(_exists(tokenId), "Token does not exist.");
        uint256 JOYtoyRef = artworkJOYtoyReference[tokenId];
        
        artworkHash = JOYtoyArtwork[JOYtoyRef][index];
        artworkType = artworkTypeMemory[JOYtoyRef][index];        
    }
    
    function updateGalleryLink(string memory newURL) public onlyOwner {
        joyGalleryLink = newURL;
    }

    function updatePaymentWallet(address payable newWallet) public onlyOwner {
        joyWallet = newWallet;
    }
    
    function updateURI(string memory newURI) public onlyOwner {
        _setBaseURI(newURI);
    }
    
    function updateJOYtoyURI(string memory newURI1, string memory newURI2) public onlyOwner {
        JOYtoyURI1 = newURI1;
        JOYtoyURI2 = newURI2;
    }
    
    function JOYtoyURI(uint256 tokenId, uint256 artworkIndex) external view returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked(JOYtoyURI1, integerToString(tokenId), JOYtoyURI2, integerToString(artworkIndex)));
    }
    
    function originalJOYOwner(uint256 joyTokenId) public view returns (address ownerOfJOY) {
        ownerOfJOY = joyWorld.ownerOf(joyTokenId);        
    }
    
    function updateArtworkTypeList(string memory newArtworkTypeList) public onlyOwner {
        artworkTypeList = newArtworkTypeList; 
    }

    function updateJOYContractAddress(address newJOYaddress) public onlyOwner {
        joyContractAddress = newJOYaddress;
        joyWorld = JOYContract(joyContractAddress);
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
       
}