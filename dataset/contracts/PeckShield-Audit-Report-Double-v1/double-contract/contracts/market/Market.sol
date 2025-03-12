// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./IMarket.sol";
import "../OwnableContract.sol";
import "../IBaseDoNFT.sol";
import "./MarketReentrancyGuard.sol";
contract Market is OwnableContract,MarketReentrancyGuard,Initializable,IMarket{
    uint64 constant private E5 = 1e5;
    mapping(address=>Credit) internal creditMap;
    mapping(address=>Royalty) internal royaltyMap;
    uint256 public fee;
    uint256 public balanceOfFee;
    address payable public beneficiary;
    uint64 public version;
    bool public isPausing;

    modifier onlyApprovedOrOwner(address spender,address nftAddress,uint256 tokenId) {
        address owner = ERC721(nftAddress).ownerOf(tokenId);
        require(owner != address(0),"ERC721: operator query for nonexistent token");
        require(spender == owner || ERC721(nftAddress).getApproved(tokenId) == spender || ERC721(nftAddress).isApprovedForAll(owner, spender),"only approved or owner");
        _;
    }

    modifier whenNotPaused(){
        require(!isPausing,"is pausing");
        _;
    }

    function initialize() public initializer {
        version = 1;
        initReentrancyGuard();
        initOwnableContract();
    }

    function mintAndCreateLendOrder (
        address doNftAddress,
        uint256 oNftId,
        uint64 maxEndTime,
        uint64 minDuration,
        uint256 pricePerSecond
    ) public nonReentrant whenNotPaused onlyApprovedOrOwner(msg.sender,IBaseDoNFT(doNftAddress).getOriginalNftAddress(),oNftId){
        require(maxEndTime > block.timestamp,"invalid maxEndTime");
        require(minDuration > 0 && minDuration % 86400 == 0,"must be an integer multiple of days");
        uint256 nftId = IBaseDoNFT(doNftAddress).mintXNft(oNftId);
        createLendOrder(doNftAddress, nftId, maxEndTime,minDuration, pricePerSecond);
    }

    function createLendOrder(
        address nftAddress,
        uint256 nftId,
        uint64 maxEndTime,
        uint64 minDuration,
        uint256 pricePerSecond
    ) public whenNotPaused onlyApprovedOrOwner(msg.sender,nftAddress,nftId){
        require(maxEndTime > block.timestamp,"invalid maxEndTime");
        require(minDuration > 0 && minDuration % 86400 == 0,"must be an integer multiple of days");
        require(IERC165(nftAddress).supportsInterface(type(IBaseDoNFT).interfaceId),"not doNFT");
        (,,uint64 dEnd) = IBaseDoNFT(nftAddress).getDurationByIndex(nftId, 0);
        if(maxEndTime > dEnd){
            maxEndTime = dEnd;
        }
        address owner = ERC721(nftAddress).ownerOf(nftId);
        Lending storage lending = creditMap[nftAddress].lendingMap[nftId];
        lending.lender = owner;
        lending.nftAddress = nftAddress;
        lending.nftId = nftId;
        lending.maxEndTime = maxEndTime;
        lending.minDuration = minDuration;
        lending.pricePerSecond = pricePerSecond;
        lending.nonce = IBaseDoNFT(nftAddress).getNonce(nftId);
        lending.version = version;
        emit CreateLendOrder(owner,nftAddress, nftId, maxEndTime,minDuration,pricePerSecond);
    }

    function cancelLendOrder(address nftAddress, uint256 nftId) public whenNotPaused onlyApprovedOrOwner(msg.sender,nftAddress,nftId){
        delete creditMap[nftAddress].lendingMap[nftId];
        emit CancelLendOrder(msg.sender,nftAddress, nftId);
    }

    function getLendOrder(address nftAddress,uint256 nftId) public view returns (Lending memory lenting){
        lenting = creditMap[nftAddress].lendingMap[nftId];
    }
    
    
    function fulfillOrder(address nftAddress,uint256 tokenId,uint256 durationId,uint64 startTime,uint64 endTime) public whenNotPaused nonReentrant payable virtual returns(uint256 tid){
        Lending storage lending = creditMap[nftAddress].lendingMap[tokenId];
        require(isLendOrderValid(nftAddress,tokenId),"invalid order");
        require(endTime <= lending.maxEndTime,"endTime > lending.maxEndTime ");
        (,uint64 dEnd) = IBaseDoNFT(nftAddress).getDuration(durationId);
        if(startTime < block.timestamp){
            startTime = uint64(block.timestamp);
        }

        if(!(startTime == block.timestamp && (endTime == dEnd || endTime == lending.maxEndTime))){
            require(endTime - startTime >= lending.minDuration,"duration < minDuration");
        }
        distributePayment(nftAddress, tokenId, startTime, endTime);
        tid = IBaseDoNFT(nftAddress).mint(tokenId, durationId, startTime, endTime, msg.sender);
        emit FulfillOrder(msg.sender, lending.lender, lending.nftAddress, lending.nftId, startTime, endTime, lending.pricePerSecond,tid);
    }

    function fulfillOrderNow(address nftAddress,uint256 tokenId,uint256 durationId,uint64 duration) public payable virtual returns(uint256 tid){
        require(isLendOrderValid(nftAddress,tokenId),"invalid order");
        Lending storage lending = creditMap[nftAddress].lendingMap[tokenId];
        uint64 endTime = uint64(block.timestamp + duration);
        if(endTime > lending.maxEndTime) {
            endTime = lending.maxEndTime;
        }
        (,uint64 dEnd) = IBaseDoNFT(nftAddress).getDuration(durationId);
        if(endTime > dEnd) {
            endTime = dEnd;
        }
        uint64 startTime = uint64(block.timestamp);
        if(!(endTime == dEnd || endTime == lending.maxEndTime)){
            require(endTime - startTime >= lending.minDuration,"duration < minDuration");
        }
        distributePayment(nftAddress, tokenId, startTime, endTime);
        tid = IBaseDoNFT(nftAddress).mint(tokenId, durationId, startTime, endTime, msg.sender);
        emit FulfillOrder(msg.sender, lending.lender, lending.nftAddress, lending.nftId, startTime, endTime, lending.pricePerSecond,tid);
    }

    function distributePayment(address nftAddress,uint256 nftId,uint64 startTime,uint64 endTime) internal returns (uint256 totalPrice,uint256 leftTotalPrice,uint256 curFee,uint256 curRoyalty){
        Lending storage lending = creditMap[nftAddress].lendingMap[nftId];
        totalPrice = lending.pricePerSecond * (endTime - startTime);
        curFee = totalPrice * fee / E5;
        curRoyalty = totalPrice * royaltyMap[nftAddress].fee / E5;
        royaltyMap[nftAddress].balance += curRoyalty;
        balanceOfFee += curFee;
        leftTotalPrice = totalPrice - curFee - curRoyalty;
        require(msg.value >= totalPrice,"payment is not enough");
        payable(ERC721(nftAddress).ownerOf(nftId)).transfer(leftTotalPrice);

        if (msg.value > totalPrice) {
           payable(msg.sender).transfer(msg.value - totalPrice);
        }
    }

    function setFee(uint256 fee_) public onlyAdmin{
        require(fee_< E5,"invalid fee");
        fee = fee_;
    }

    function setMarketBeneficiary(address payable beneficiary_) public onlyAdmin{
        beneficiary = beneficiary_;
    }

    function claimFee() public whenNotPaused{
        require(msg.sender==beneficiary,"not beneficiary");
        beneficiary.transfer(balanceOfFee);
        balanceOfFee = 0;
    }

    function setRoyalty(address nftAddress,uint256 fee_) public onlyAdmin{
        require(fee_< E5,"invalid fee");
        royaltyMap[nftAddress].fee = fee_;
    }

    function setRoyaltyBeneficiary(address nftAddress,address payable beneficiary_) public onlyAdmin{
        royaltyMap[nftAddress].beneficiary = beneficiary_;
    }

    function claimRoyalty(address nftAddress) public whenNotPaused{
        require(msg.sender==royaltyMap[nftAddress].beneficiary,"not beneficiary");
        royaltyMap[nftAddress].beneficiary.transfer(royaltyMap[nftAddress].balance);
        royaltyMap[nftAddress].balance = 0;
    }

    function isLendOrderValid(address nftAddress,uint256 nftId) public view returns (bool){
        Lending storage lending = creditMap[nftAddress].lendingMap[nftId];
        if(isPausing){
            return false;
        }
        return  lending.nftId > 0 && 
                lending.maxEndTime > block.timestamp && 
                lending.nonce == IBaseDoNFT(nftAddress).getNonce(nftId);
    }

    function setPause(bool pause_) public onlyAdmin{
        isPausing = pause_;
        if(isPausing){
            emit Paused(address(this));
        }else{
            emit Unpaused(address(this));
        }
    }

}