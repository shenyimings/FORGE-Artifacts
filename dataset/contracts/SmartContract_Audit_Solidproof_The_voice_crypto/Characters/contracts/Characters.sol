// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MysteryBox.sol";
import "./Promocode.sol";

contract Characters is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Pausable, ERC721Burnable, Ownable {

    event CharacterNFTMinted(uint256 tokenId, uint256 mysteryBoxType, string nameMysteryBox);

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    using Strings for uint256;

    address payable private tvcAddress;
    IERC20 public tvcContract;

    address private codeAddress;
    Promocode public codeContract;

    address private mysteryAddress;
    MysteryBox public mysteryContract;

    uint256 private limit;

    mapping (uint256 => uint256) private mapCharacterToMysteryBoxType;

    bool private native;

    constructor(address _mysteryBoxAddress, address _promocodeAddress) ERC721("Character Token", "CharacterTVC"){
        tvcAddress = payable(address(0));
        changeMysteryAddress(_mysteryBoxAddress);
        changeCodeAddress(_promocodeAddress);
        native = true;
        limit = 20;
    }
    
    function modifyLimitPayment(uint256 _limit) public onlyOwner {
        limit = _limit;
    }

    modifier verifications(uint256 _numberMysteryBoxType, uint256 _amount) {
        require(_amount <= limit, "Amount is higher");
        require(_numberMysteryBoxType <= mysteryContract.getMysteryBoxCount(), "Not exist");
        _;
    }

    function modifyPaymentMethod(bool _nativeBool) public onlyOwner {
        native = _nativeBool;
    }

    function getMysteryBoxToCharacter(uint _tokenId) public view returns(uint256 numberMysteryBoxType_) {
        require(_exists(_tokenId), "Non existent");
        return mapCharacterToMysteryBoxType[_tokenId];
    }

    function buyMysteryBoxNative(uint256 _numberMysteryBoxType, uint256 _amount, string memory _code)
        public payable
        whenNotPaused
        verifications(_numberMysteryBoxType, _amount) {
        require(native, "Minted not enabled");

        MysteryBox.MysteryBoxType memory mystery = mysteryContract.mysteryBoxDetails(_numberMysteryBoxType);
        require(mystery.stock > 0, "Sold out");
        uint256 price = mystery.priceNative;

        if(codeContract.getActivePromocode() && bytes(_code).length != 1){
            require(codeContract.validateCode(_code), "Invalid Code");
            price = mystery.priceNativeDesc;
        }
        
        require(msg.value == price * _amount, "Not enough ethers");
        for (uint256 i = 0; i < _amount; i++) {
            uint256 newItemId = _mintNewToken(_msgSender());
            mapCharacterToMysteryBoxType[newItemId] = _numberMysteryBoxType;
            emit CharacterNFTMinted(newItemId, _numberMysteryBoxType, mystery.name);
        }

        mysteryContract.changeMysteryBoxStock(_numberMysteryBoxType, _amount);
        codeContract.changePromocodeReedem(_code, _amount);
        payable(owner()).transfer(price * _amount);
    }

    function buyMysteryBoxTVC(uint256 _numberMysteryBoxType, uint256 _amount, string memory _code)
        public payable
        whenNotPaused
        verifications(_numberMysteryBoxType, _amount) {
        require(!native, "Minted not enabled");

        MysteryBox.MysteryBoxType memory mystery = mysteryContract.mysteryBoxDetails(_numberMysteryBoxType);
        require(mystery.stock > 0, "Sold out");
        uint256 price = mystery.priceTVC;

        if(codeContract.getActivePromocode() && bytes(_code).length != 1){
            require(codeContract.validateCode(_code), "Invalid code");
            price = mystery.priceTVCDesc;
        }

        require(tvcContract.balanceOf(_msgSender()) >= price * _amount, "Not enough TVC");
        tvcContract.transferFrom(_msgSender(), owner(), price * _amount);

        for (uint256 i = 0; i < _amount; i++) {
            uint256 newItemId = _mintNewToken(_msgSender());
            mapCharacterToMysteryBoxType[newItemId] = _numberMysteryBoxType;
            emit CharacterNFTMinted(newItemId, _numberMysteryBoxType, mystery.name);
        }
        mysteryContract.changeMysteryBoxStock(_numberMysteryBoxType, _amount);
        codeContract.changePromocodeReedem(_code, _amount);
    }
    
    function _mintNewToken(address _addressRequest) private returns(uint256) {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(_addressRequest, tokenId);
        _setTokenURI(_tokenIdCounter.current(), tokenId.toString());
        return tokenId;
    }

    function mint() public onlyOwner {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(_msgSender(), _tokenIdCounter.current());
        _setTokenURI(_tokenIdCounter.current(), tokenId.toString());
    }

    function changeTVCAddress(address _newAddress) public onlyOwner{
        tvcAddress = payable(_newAddress);
        tvcContract = IERC20(tvcAddress);
    }

    function changeCodeAddress(address _newAddress) public onlyOwner{
        codeAddress = payable(_newAddress);
        codeContract = Promocode(codeAddress);
    }

    function changeMysteryAddress(address _newAddress) public onlyOwner{
        mysteryAddress = payable(_newAddress);
        mysteryContract = MysteryBox(mysteryAddress);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://thevoicecryto.org/tokens/nft/";
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable, ERC721Pausable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}