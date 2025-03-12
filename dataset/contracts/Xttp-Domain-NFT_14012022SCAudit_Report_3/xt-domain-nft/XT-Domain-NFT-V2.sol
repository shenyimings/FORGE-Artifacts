//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
//pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
//import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
//import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract XTNFT is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    struct NFTSaleStatsStruct {
        mapping(address => uint256) _totalSalePerPaymentToken;
    }

    NFTSaleStatsStruct private nftSaleStats;

    struct NFTSaleStruct {
        address _ownerAddress;
        address _payerAddress;
        uint256 _paidTime;
        uint256 _salePrice;
        address _tokenForPayment;
        uint256 _qtyYear;
    }
    
    struct NFTRegisterStruct {
        address _ownerAddress;
        address _payerAddress;
        uint256 _tokenId;
        uint256 _beginTime;
        uint256 _expiryTime;
        bool _forSale;
        uint256 _salePrice;
        string _tokenURI;
        string _nftName;
        string _nameXTExt;
        string _URI;
        uint256 _totalPaidForSubscription;
        NFTSaleStruct[] _NFTSaleHistory;
    }
    
    mapping(string => NFTRegisterStruct) private nftNameMap;
    mapping(uint256 => string) private nftIdNameMap;
    
    //mapping with wallet address for a better performance
    struct UserNFTRegisterStruct {
        uint256[] _tokenIds;
        mapping(uint256 => uint256) _tokenIdArrIndexMap;
    }
    
    mapping(address => UserNFTRegisterStruct) private nftUserTokenMap;
    
    //mapping with ext name for a better performance
    struct ExtNFTRegisterStruct {
        uint256[] _tokenIds;
    }
    
    mapping(string => ExtNFTRegisterStruct) private nftExtTokenMap;
    
    using SafeERC20 for IERC20;
    
    uint256 private _activeTime;

    // ERC20 basic payment token contracts being held
    IERC20 private _tokenForRegisterNFT;
    IERC20 private _tokenForMarketPlace;
    
    // beneficiary of payment
    address private _newBeneficiary;
    address private _beneficiary;
    uint256 private _beneficiaryActiveTime;
    
    address private _worker;
    
    string[] private _nameXTExt= [".ada", ".algo", ".atom", ".avax", ".bch", ".bnb", ".bsv", ".btc", ".cake", ".chz", ".dash", ".dcr", ".doge", ".dot", ".egld", ".enj", ".eos", ".etc", ".eth", ".fil", ".flow", ".ftm", ".hbar", ".hnt", ".hot", ".icp", ".int", "iotx", ".kda", ".klay", ".ksm", ".link", ".luna", ".matic", ".mina", ".miota", ".mkr", ".near", ".neo", ".omg", ".one", ".qnt", ".qtum", ".rune", ".sc", ".sol", ".stx", ".theta", ".trx", ".uni", ".vet", ".waves", ".xdc", ".xem", ".xlm", ".xrp", ".xt"];
    //string[] private _nameIANAExt= [".com"];
    
    uint256 private mintPrice = 30e18;//30 * 10^18 tokens
    uint256 private _marketplaceFee = 15e18; // 15 = 15 * 10^18 %
    uint256 private _burnRate = 1e18; // 1 = 1 * 10^18 %
    
    constructor() {
        _activeTime = block.timestamp + 24 hours;
        _beneficiary = address(this);
        _newBeneficiary = address(this);
        _beneficiaryActiveTime = block.timestamp;
        _worker = msg.sender;
    }
    
    function getWorker() external onlyOwner view returns (address) {
        return _worker;
    }
    
    //Declare an Event
    
    event UpdateWorker(
        address indexed caller,
        address indexed worker
    );
    
    function updateWorker(address newWorker_) external onlyOwner {
        require(
            newWorker_ != address(0),
            "zero address issue"
        );
        
        _worker = newWorker_;
        emit UpdateWorker(msg.sender, newWorker_);
    }
    
    function getActiveTime() public view returns (uint256)
    {
        return _activeTime;
    }
    
    //Declare an Event
    
    event SetMarketPlaceFee(
        address indexed caller,
        uint256 indexed marketplaceFee_
    );
    
    function setMarketPlaceFee(uint256 marketplaceFee_) external onlyOwner {
        _marketplaceFee = marketplaceFee_;
        emit SetMarketPlaceFee(msg.sender, marketplaceFee_);
    }
    
    //Declare an Event
    
    event AddXTExt(
        address indexed caller,
        string indexed nameExt_
    );
    
    function addXTExt( string memory nameExt_) external onlyOwner {
        
        uint loopCnt = _nameXTExt.length;
        
        for(uint i=0; i< _nameXTExt.length; i++){
            if (keccak256(abi.encodePacked(nameExt_)) == keccak256(abi.encodePacked(_nameXTExt[i]))){
                loopCnt = i;
                break;
            }
        }
        
        require(
            loopCnt == _nameXTExt.length,
            "Ext existed"
        );
            
        _nameXTExt.push(nameExt_);
        emit AddXTExt(msg.sender, nameExt_);
    }

    //Declare an Event
    
    event RemoveXTExt(
        address indexed caller,
        string indexed nameExt_
    );
    
    function removeXTExt( string memory nameExt_) external onlyOwner {
        
        uint loopCnt = _nameXTExt.length;
        
        for(uint i=0; i< _nameXTExt.length; i++){
            if (keccak256(abi.encodePacked(nameExt_)) == keccak256(abi.encodePacked(_nameXTExt[i]))){
                loopCnt = i;
                break;
            }
        }
        
        require(
            loopCnt < _nameXTExt.length,
            "Ext isn't existed"
        );

        _nameXTExt[loopCnt] = _nameXTExt[_nameXTExt.length - 1];
        _nameXTExt.pop();
        emit RemoveXTExt(msg.sender, nameExt_);
    }
    
    function getNameExt()  external view returns (string[] memory) {
        return _nameXTExt;
    }
    
    //Declare an Event
    
    event SetTokenForPayment(
        address indexed caller,
        IERC20 indexed token_
    );
    
    //Declare an Event
    
    event SetMintPrice(
        address indexed caller,
        uint indexed newMintPrice
    );
    
    function setMintPrice(uint256 newMintPrice) external onlyOwner {
        mintPrice = newMintPrice;
        emit SetMintPrice(msg.sender, newMintPrice);
    }
    
    function getMintPrice() public view virtual returns (uint256) {
        return mintPrice;
    }
    
    function getCurrentTokenId() external view virtual returns (uint256) {
        return  _tokenIds.current();
    }
    /**
     * @return the token being held.
     */
    function paymentToken(uint paymentId) public view virtual returns (IERC20) {
        require(
            paymentId <= 2,
            "Unknown token"
        );
        
        if(paymentId == 1) return _tokenForRegisterNFT;
        return _tokenForMarketPlace;
    }
    
    function setTokenForRegisterNFTPayment(IERC20 token_) external onlyOwner {
        _tokenForRegisterNFT = token_;
        emit SetTokenForPayment(msg.sender, token_);
    }
    
    function setTokenForMarketPlacePayment(IERC20 token_) external onlyOwner {
        _tokenForMarketPlace = token_;
        emit SetTokenForPayment(msg.sender, token_);
    }
    
    function balanceTokenForPayment(uint paymentId) external view virtual returns (uint256) {
        require(
            paymentId <= 2,
            "Unknown token"
        );
        
        return paymentToken(paymentId).balanceOf(address(this));
    }
    
    //Declare an Event
    
    event WithdrawTokenForPayment(
        address indexed caller,
        address indexed beneficiary_,
        uint256 indexed balance_
    );
    
    function withdrawTokenForPayment(uint paymentId) external {
        require(
            paymentId <= 2,
            "Unknown token"
        );
        
        if(_beneficiary != _newBeneficiary && block.timestamp > _beneficiaryActiveTime) _beneficiary = _newBeneficiary;
        
        require(msg.sender == _worker || msg.sender == owner(), "Invalid caller!");
        
        uint256 currentBalance = paymentToken(paymentId).balanceOf(address(this));
        
        // paymentToken(paymentId).safeTransferFrom(address(this), beneficiary(), currentBalance);
        paymentToken(paymentId).safeTransfer(beneficiary(), currentBalance);
        emit WithdrawTokenForPayment(address(this), beneficiary(), currentBalance);
    }
    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view virtual returns (address) {
        return _beneficiary;
    }
    
    //Declare an Event
    
    event SetBeneficiary(
        address indexed caller,
        address indexed beneficiary_,
        uint256 indexed activeTime
    );
    
    function setBeneficiary( address beneficiary_) external onlyOwner {
        require(
            beneficiary_ != address(0),
            "Zero Address Issue"
        );
        
        _newBeneficiary = beneficiary_;
        _beneficiaryActiveTime = block.timestamp + 24 hours;
        
        emit SetBeneficiary(msg.sender, beneficiary_, _beneficiaryActiveTime);
    }
    
    //Declare an Event
    
    event RegisteredNewNFT(
        address indexed caller,
        string indexed newNFT
    );
    
    function registerNFT(string memory newNFT, uint nameXTExtId_, string memory tokenURI_, uint numOfYear)
        external 
        returns (uint256)
    {
        require(
            block.timestamp > getActiveTime(),
            "Can't register before active time"
        );
        
        if(_beneficiary != _newBeneficiary && block.timestamp > _beneficiaryActiveTime) _beneficiary = _newBeneficiary;
        
        require(paymentToken(1).balanceOf(msg.sender) >= getMintPrice(), "Low Balance");
        
        require(bytes(newNFT).length > 0, "blank");
        
        require(numOfYear >= 1 && numOfYear <= 10, "Can't be <1 || >10");
        
        require(nameXTExtId_ < _nameXTExt.length , "Out of array");
        
        //paymentToken(1).safeTransferFrom(msg.sender, address(this), (1e20 - _burnRate) * numOfYear * getMintPrice() /1e20);
        paymentToken(1).safeTransferFrom(msg.sender, beneficiary(), (1e20 - _burnRate) * numOfYear * getMintPrice() /1e20);
        paymentToken(1).safeTransferFrom(msg.sender, address(0), _burnRate * numOfYear * getMintPrice()/ 1e20);

        nftSaleStats._totalSalePerPaymentToken[address(_tokenForRegisterNFT)] += numOfYear * getMintPrice();
        //string memory NFTName_ = bytes(newNFT).length > 0 ? string(abi.encodePacked(newNFT, _nameXTExt[nameXTExtId_])) : "";
        string memory NFTName_ = string(abi.encodePacked(newNFT, _nameXTExt[nameXTExtId_]));

        require(nftNameMap[NFTName_]._tokenId == 0, "taken");
        
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        
        //_mint(address(this), newItemId);
        //_mint(msg.sender, newItemId);

        nftNameMap[NFTName_]._ownerAddress = msg.sender;//recipient;
        nftNameMap[NFTName_]._payerAddress = msg.sender;
        nftNameMap[NFTName_]._tokenId = newItemId;
        nftNameMap[NFTName_]._beginTime = block.timestamp;
        nftNameMap[NFTName_]._expiryTime = block.timestamp + numOfYear * 365 * 86400;
        nftNameMap[NFTName_]._forSale = false;
        nftNameMap[NFTName_]._salePrice = 0;
        nftNameMap[NFTName_]._tokenURI = tokenURI_;
        nftNameMap[NFTName_]._nftName = newNFT;
        nftNameMap[NFTName_]._nameXTExt = _nameXTExt[nameXTExtId_];
        nftNameMap[NFTName_]._totalPaidForSubscription += numOfYear * getMintPrice();
        
        nftNameMap[NFTName_]._NFTSaleHistory.push(NFTSaleStruct(
            nftNameMap[NFTName_]._ownerAddress,
            msg.sender,
            block.timestamp,
            getMintPrice(),
            address(paymentToken(1)),
            numOfYear
        ));
        //use the map of address with tokenIds for a better performance when get the list of tokenIds by an address
        nftUserTokenMap[msg.sender]._tokenIds.push(newItemId);
        nftUserTokenMap[msg.sender]._tokenIdArrIndexMap[newItemId] = nftUserTokenMap[msg.sender]._tokenIds.length-1;

        nftExtTokenMap[_nameXTExt[nameXTExtId_]]._tokenIds.push(newItemId);
        nftIdNameMap[newItemId] = NFTName_;
        
        //_setTokenURI(nftNameMap[NFTName_]._tokenId, tokenURI_);
        nftNameMap[NFTName_]._URI = tokenURI_;
        //Emit an event
        emit RegisteredNewNFT(msg.sender, NFTName_);
    
        return newItemId;
    }
    
    //Declare an Event
    
    event ExtendNFTSubscription(
        address indexed caller,
        string indexed NFTName_
    );
    
    function extendNFTSubscription(string memory NFTName_, uint numOfYear)
        external 
    {
        require(
            block.timestamp > getActiveTime(),
            "before active time"
        );
        
        if(_beneficiary != _newBeneficiary && block.timestamp > _beneficiaryActiveTime) _beneficiary = _newBeneficiary;
        
        require(paymentToken(1).balanceOf(msg.sender) >= numOfYear * getMintPrice(), "Low Balance");
        
        require(bytes(NFTName_).length > 0, "blank");
        
        require(numOfYear >= 1 && numOfYear <= 10, "Can't be <1 || >10");
        
        //require(nameXTExtId_ < _nameXTExt.length , "Out of array.");
        
        //paymentToken(1).safeTransferFrom(msg.sender, beneficiary(), numOfYear * getMintPrice());
        paymentToken(1).safeTransferFrom(msg.sender, beneficiary(), (1e20 - _burnRate) * numOfYear * getMintPrice() /1e20);
        paymentToken(1).safeTransferFrom(msg.sender, address(0), _burnRate * numOfYear * getMintPrice()/ 1e20);

        nftSaleStats._totalSalePerPaymentToken[address(_tokenForRegisterNFT)] += numOfYear * getMintPrice();
        //string memory NFTName_ = bytes(newNFT).length > 0 ? string(abi.encodePacked(newNFT, _nameXTExt[nameXTExtId_])) : "";
        if(nftNameMap[NFTName_]._expiryTime < block.timestamp){
            nftNameMap[NFTName_]._expiryTime = block.timestamp + numOfYear * 365 * 86400;
        }else{
            nftNameMap[NFTName_]._expiryTime = nftNameMap[NFTName_]._expiryTime + numOfYear * 365 * 86400;
        }
        
        //nftNameMap[NFTName_]._expiryTime = block.timestamp + numOfYear * 365 * 86400;
        nftNameMap[NFTName_]._totalPaidForSubscription += numOfYear * getMintPrice();
        
        nftNameMap[NFTName_]._NFTSaleHistory.push(NFTSaleStruct(
            nftNameMap[NFTName_]._ownerAddress,
            msg.sender,
            block.timestamp,
            getMintPrice(),
            address(paymentToken(1)),
            numOfYear
        ));
        //Emit an event
        emit ExtendNFTSubscription(msg.sender, NFTName_);
    }
    
    //Declare an Event
    
    event ImportNewNFT(
        address indexed caller,
        string indexed newNFT
    );
    
    function importNFT(address recipient, string memory newNFT, string memory nameXTExt, string memory tokenURI_, uint numOfYear)
        external onlyOwner 
        returns (uint256)
    {
        require(
            block.timestamp > getActiveTime(),
            "before active time"
        );
        
        if(_beneficiary != _newBeneficiary && block.timestamp > _beneficiaryActiveTime) _beneficiary = _newBeneficiary;
        
        require(
            recipient != address(0),
            "recipient: zero address"
        );
        
        require(paymentToken(1).balanceOf(msg.sender) >= numOfYear * getMintPrice(), "Low Balance");
        
        require(bytes(newNFT).length > 0, "newNFT: blank");
        
        require(bytes(tokenURI_).length > 0, "tokenURI: blank");
        
        require(numOfYear >= 1 && numOfYear <= 10, "Can't be <1 || >10");
        
        //paymentToken(1).safeTransferFrom(msg.sender, beneficiary(), numOfYear * getMintPrice());
        paymentToken(1).safeTransferFrom(msg.sender, beneficiary(), (1e20 - _burnRate) * numOfYear * getMintPrice() /1e20);
        paymentToken(1).safeTransferFrom(msg.sender, address(0), _burnRate * numOfYear * getMintPrice()/ 1e20);

        nftSaleStats._totalSalePerPaymentToken[address(_tokenForRegisterNFT)] += numOfYear * getMintPrice();
        //string memory NFTName_ = bytes(newNFT).length > 0 ? string(abi.encodePacked(newNFT, nameXTExt)) : "";
        string memory NFTName_ = string(abi.encodePacked(newNFT, nameXTExt));
        
        require(nftNameMap[NFTName_]._tokenId == 0, "taken");
        
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        
        //_mint(address(this), newItemId);
        //_mint(recipient, newItemId);

        nftNameMap[NFTName_]._ownerAddress = recipient;
        nftNameMap[NFTName_]._payerAddress = msg.sender;
        nftNameMap[NFTName_]._tokenId = newItemId;
        nftNameMap[NFTName_]._beginTime = block.timestamp;
        nftNameMap[NFTName_]._expiryTime = block.timestamp + numOfYear * 365 * 86400;
        nftNameMap[NFTName_]._forSale = false;
        nftNameMap[NFTName_]._salePrice = 0;
        nftNameMap[NFTName_]._tokenURI = tokenURI_;
        nftNameMap[NFTName_]._nftName = newNFT;
        nftNameMap[NFTName_]._nameXTExt = nameXTExt;
        nftNameMap[NFTName_]._totalPaidForSubscription += numOfYear * getMintPrice();
        
        nftNameMap[NFTName_]._NFTSaleHistory.push(NFTSaleStruct(
            nftNameMap[NFTName_]._ownerAddress,
            msg.sender,
            block.timestamp,
            getMintPrice(),
            address(paymentToken(1)),
            numOfYear
        ));
        //use the map of address with tokenIds for a better performance when get the list of tokenIds by an address
        nftUserTokenMap[recipient]._tokenIds.push(newItemId);
        nftUserTokenMap[recipient]._tokenIdArrIndexMap[newItemId] = nftUserTokenMap[recipient]._tokenIds.length-1;

        nftExtTokenMap[nameXTExt]._tokenIds.push(newItemId);
        nftIdNameMap[newItemId] = NFTName_;
        
        //_setTokenURI(nftNameMap[NFTName_]._tokenId, tokenURI_);
        nftNameMap[NFTName_]._URI = tokenURI_;
        //Emit an event
        emit ImportNewNFT(recipient, NFTName_);
    
        return newItemId;
    }
    
    //Declare an Event
    
    event ExtendImportedNFTSubscription(
        address indexed caller,
        string indexed NFTName_,
        uint indexed numOfYear
    );
    
    function extendImportedNFTSubscription(string memory NFTName_, uint numOfYear)
        external onlyOwner 
    {
        require(
            block.timestamp > getActiveTime(),
            "before active time"
        );
        
        if(_beneficiary != _newBeneficiary && block.timestamp > _beneficiaryActiveTime) _beneficiary = _newBeneficiary;
        
        require(paymentToken(1).balanceOf(msg.sender) >= numOfYear * getMintPrice(), "Low Balance");
        
        require(bytes(NFTName_).length > 0, "NFTName_: blank");
        
        require(numOfYear >= 1 && numOfYear <= 10, "Can't be <1 || >10");
        
        //paymentToken(1).safeTransferFrom(msg.sender, beneficiary(), numOfYear * getMintPrice());
        paymentToken(1).safeTransferFrom(msg.sender, beneficiary(), (1e20 - _burnRate) * numOfYear * getMintPrice() /1e20);
        paymentToken(1).safeTransferFrom(msg.sender, address(0), _burnRate * numOfYear * getMintPrice()/ 1e20);

        nftSaleStats._totalSalePerPaymentToken[address(_tokenForRegisterNFT)] += numOfYear * getMintPrice();
        //string memory NFTName_ = bytes(newNFT).length > 0 ? string(abi.encodePacked(newNFT, _nameXTExt[nameXTExtId_])) : "";
        if(nftNameMap[NFTName_]._expiryTime < block.timestamp){
            nftNameMap[NFTName_]._expiryTime = block.timestamp + numOfYear * 365 * 86400;
        }else{
            nftNameMap[NFTName_]._expiryTime = nftNameMap[NFTName_]._expiryTime + numOfYear * 365 * 86400;
        }
        
        nftNameMap[NFTName_]._totalPaidForSubscription += numOfYear * getMintPrice(); 
        //nftNameMap[NFTName_]._expiryTime = block.timestamp + numOfYear * 365 * 86400;
        
        nftNameMap[NFTName_]._NFTSaleHistory.push(NFTSaleStruct(
            nftNameMap[NFTName_]._ownerAddress,
            msg.sender,
            block.timestamp,
            getMintPrice(),
            address(paymentToken(1)),
            numOfYear
        ));
        //Emit an event
        emit ExtendImportedNFTSubscription(msg.sender, NFTName_, numOfYear);
    }
    
    //Declare an Event
    
    event BuyNFTFromMarketPlace(
        address indexed caller,
        string indexed NFTName_
    );
    
    function buyNFTFromMarketPlace(string memory NFTName_)
        external
    {
        require(
            block.timestamp > getActiveTime(),
            "before active time"
        );
        
        require(nftNameMap[NFTName_]._forSale, "Not For Sale");
        
        require(bytes(NFTName_).length > 0, "NFTName_: blank");
        
        require(paymentToken(2).balanceOf(msg.sender) >= nftNameMap[NFTName_]._salePrice, "Low Balance");
        
        //Need to approve this contract before this transaction
        //safeTransferFrom( nftNameMap[NFTName_]._ownerAddress, address(this), nftNameMap[NFTName_]._tokenId);
        paymentToken(2).safeTransferFrom(msg.sender, beneficiary(), _marketplaceFee * nftNameMap[NFTName_]._salePrice/ 1e20);
        paymentToken(2).safeTransferFrom(msg.sender, nftNameMap[NFTName_]._ownerAddress, (1e20 - _marketplaceFee - _burnRate) *nftNameMap[NFTName_]._salePrice /1e20);
        
        if(_tokenForRegisterNFT == _tokenForMarketPlace)
            paymentToken(2).safeTransferFrom(msg.sender, address(0), _burnRate * nftNameMap[NFTName_]._salePrice/ 1e20);
        else paymentToken(2).safeTransferFrom(msg.sender, address(this), _burnRate * nftNameMap[NFTName_]._salePrice/ 1e20);

        nftSaleStats._totalSalePerPaymentToken[address(_tokenForMarketPlace)] += nftNameMap[NFTName_]._salePrice;
        //Need to approve this contract before this transaction
        //safeTransferFrom( address(this), msg.sender, nftNameMap[NFTName_]._tokenId);
        
        //safeTransferFrom( nftNameMap[NFTName_]._ownerAddress, msg.sender, nftNameMap[NFTName_]._tokenId);
        
        uint arrayLength = nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds.length;
        /*
        uint foundId = arrayLength;
        for(uint i = 0; i < nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds.length; i++){
            if((nftNameMap[NFTName_]._tokenId == nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds[i])){
                foundId = i;
                break;
            }
        }
        */
        //if(foundId < arrayLength){
            
            nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds[nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIdArrIndexMap[nftNameMap[NFTName_]._tokenId]] = nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds[arrayLength - 1];
            //nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIdArrIndexMap[nftNameMap[NFTName_]._tokenId] = nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds.length;
            nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds.pop();
            
            /*
            nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds[foundId] = nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds[arrayLength - 1];
            nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds.pop();
            */
        //}

        nftNameMap[NFTName_]._ownerAddress = msg.sender;//recipient;
        nftNameMap[NFTName_]._forSale = false;
        nftNameMap[NFTName_]._salePrice = 0;
        
        nftNameMap[NFTName_]._NFTSaleHistory.push(NFTSaleStruct(
            nftNameMap[NFTName_]._ownerAddress,
            msg.sender,
            block.timestamp,
            nftNameMap[NFTName_]._salePrice,
            address(paymentToken(2)),
            0
        ));
        
        //use the map of address with tokenIds for a better performance when get the list of tokenIds by an address
        nftUserTokenMap[msg.sender]._tokenIds.push(nftNameMap[NFTName_]._tokenId);
        nftUserTokenMap[msg.sender]._tokenIdArrIndexMap[nftNameMap[NFTName_]._tokenId] = nftUserTokenMap[msg.sender]._tokenIds.length-1;
        //Emit an event
        emit BuyNFTFromMarketPlace(msg.sender, NFTName_);
    }
    
    //Declare an Event
    
    event TransferNFT(
        address indexed caller,
        address recipient,
        string indexed NFTName_
    );

    function transferNFT(string memory NFTName_, address recipient)
        external
    {
        //address nftOwner = nftNameMap[NFTName_]._ownerAddress;
        
        require(
            nftNameMap[NFTName_]._ownerAddress == msg.sender,
            "not the owner"
        );
        
        require(bytes(NFTName_).length > 0, "NFTName_: blank");
        require(
            recipient != address(0),
            "zero address issue"
        );

        uint arrayLength = nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds.length;
            
        nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds[nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIdArrIndexMap[nftNameMap[NFTName_]._tokenId]] = nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds[arrayLength - 1];
        nftUserTokenMap[nftNameMap[NFTName_]._ownerAddress]._tokenIds.pop();

        nftNameMap[NFTName_]._ownerAddress = recipient;//msg.sender;//recipient;
        nftNameMap[NFTName_]._forSale = false;
        nftNameMap[NFTName_]._salePrice = 0;
        
        nftNameMap[NFTName_]._NFTSaleHistory.push(NFTSaleStruct(
            nftNameMap[NFTName_]._ownerAddress,
            recipient,//msg.sender,
            block.timestamp,
            nftNameMap[NFTName_]._salePrice,
            address(paymentToken(2)),
            0
        ));
        
        //use the map of address with tokenIds for a better performance when get the list of tokenIds by an address
        nftUserTokenMap[recipient]._tokenIds.push(nftNameMap[NFTName_]._tokenId);
        nftUserTokenMap[recipient]._tokenIdArrIndexMap[nftNameMap[NFTName_]._tokenId] = nftUserTokenMap[recipient]._tokenIds.length-1;
        
        emit TransferNFT(msg.sender, recipient, NFTName_);
    }

    //Declare an Event
    
    event SetNFTSalePrice(
        address indexed caller,
        string indexed NFTName_,
        uint256 salePrice_
    );
    
    function setNFTSalePrice(string memory NFTName_, uint256 salePrice_) external {
        
        //address nftOwner = nftNameMap[NFTName_]._ownerAddress;
        
        require(
            nftNameMap[NFTName_]._ownerAddress == msg.sender,
            "not the owner"
        );
        
        nftNameMap[NFTName_]._forSale = true;
        nftNameMap[NFTName_]._salePrice = salePrice_;
        emit SetNFTSalePrice(msg.sender, NFTName_, salePrice_);
    }
    
    //get tokenIds by address
    function getTokenIdsByAddress(address walletAddress, uint256 start, uint256 end) external view returns (uint256[] memory tokenIds)
    {
        require(start <= end, "Invalid counters");
        require(nftUserTokenMap[walletAddress]._tokenIds.length > 0 && nftUserTokenMap[walletAddress]._tokenIds.length > end, "Exceeded array length");
        uint256[] memory tokenIdsInterim =  new uint256[](100);
        uint256 arrayLen = end - start + 1;
        for(uint256 i = 0; i < arrayLen; i++){
            tokenIdsInterim[i]= nftUserTokenMap[walletAddress]._tokenIds[i + start];
        }
        return  tokenIdsInterim;//nftUserTokenMap[walletAddress]._tokenIds;
    }
    
    function getTotalTokenIdsByAddress(address walletAddress) external view returns (uint256 totalTokenIds)
    {
        return  nftUserTokenMap[walletAddress]._tokenIds.length;
    }

    //get tokenIds by ext name
    function getTokenIdsByExt(string memory extName_, uint256 start, uint256 end) external view returns (uint256[] memory tokenIds)
    {
        require(start <= end, "Invalid counters");
        require(nftExtTokenMap[extName_]._tokenIds.length > 0 && nftExtTokenMap[extName_]._tokenIds.length > end, "Exceeded array length");
        uint256[] memory tokenIdsInterim =  new uint256[](100);
        uint256 arrayLen = end - start + 1;
        for(uint256 i = 0; i < arrayLen; i++){
            tokenIdsInterim[i]= nftExtTokenMap[extName_]._tokenIds[i + start];
        }
        return  tokenIdsInterim;//nftExtTokenMap[extName_]._tokenIds;
    }
    
    function getTotalTokenIdsByExt(string memory extName_) external view returns (uint256 totalTokenIds)
    {
        return  nftExtTokenMap[extName_]._tokenIds.length;
    }

    function getNFTURI(string memory NFTName_) external view returns (string memory)
    {
        require(nftNameMap[NFTName_]._expiryTime > block.timestamp, "Expired");
        
        //return tokenURI(nftNameMap[NFTName]._tokenId);
        return nftNameMap[NFTName_]._URI;
    }
    
    function getNFTDataByName(string memory NFTName) external view returns (NFTRegisterStruct memory)
    {
        return nftNameMap[NFTName];
    }
    
    function getNFTDataById(uint256 tokenId_) external view returns (NFTRegisterStruct memory)
    {
        return nftNameMap[nftIdNameMap[tokenId_]];
    }
    
    function getNFTNameById(uint256 tokenId_) external view returns (string memory)
    {
        return nftIdNameMap[tokenId_];
    }

    function getNFTSaleStatsPerToken(IERC20 tokenPaymentAddress) external view returns (uint256)
    {
        return nftSaleStats._totalSalePerPaymentToken[address(tokenPaymentAddress)];
    }
    
    //Declare an Event
    
    event SetNFTURI(
        address indexed caller,
        string indexed NFTName_,
        string indexed tokenURI_
    );
    
    function setNFTURI(string memory NFTName_, string memory tokenURI_) external
    {
        //require(paymentToken(1).balanceOf(msg.sender) >= getMintPrice(), "Low Balance");
        
        //if(_beneficiary != _newBeneficiary && block.timestamp > _beneficiaryActiveTime) _beneficiary = _newBeneficiary;
        
        //address nftOwner = nftNameMap[NFTName_]._ownerAddress;
        
        require(
            nftNameMap[NFTName_]._ownerAddress == msg.sender,
            "not the owner"
        );
        
        //paymentToken(1).safeTransferFrom(msg.sender, beneficiary(), getMintPrice());
        
        require(bytes(NFTName_).length > 0, "NFTName_: blank");
        //require(bytes(tokenURI_).length > 0, "tokenURI: blank");
        
        //_setTokenURI(nftNameMap[NFTName_]._tokenId, tokenURI_);
        nftNameMap[NFTName_]._tokenURI = tokenURI_;
        
        emit SetNFTURI(msg.sender, NFTName_, tokenURI_);
    }
    
    //Declare an Event
    
    event SetBurnRate(
        address indexed caller,
        uint256 indexed burnRate
    );

    function setBurnRate(uint256 burnRate_) external onlyOwner {
        _burnRate = burnRate_;
        emit SetBurnRate(msg.sender, burnRate_);
    }
    
    function getBurnRate() public view virtual returns (uint256) {
        return _burnRate;
    }
}
