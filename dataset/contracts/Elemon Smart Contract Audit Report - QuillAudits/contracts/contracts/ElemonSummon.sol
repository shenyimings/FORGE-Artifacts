// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IElemonInfo.sol";
import "./interfaces/IElemonNFT.sol";
import "./utils/ReentrancyGuard.sol";

contract ElemonSummon is ReentrancyGuard, VRFConsumerBase, ConfirmedOwner(msg.sender) {
    struct RequestInfo {
        uint256 tokenId;
        uint256 level;
    }

    mapping(uint256 => uint256) public _levelPrices;

    address public _paymentTokenAddress;
    address public _recepientTokenAddress;
    IElemonInfo public _elemonInfo;
    IElemonNFT public _elemonNFT;

    bytes32 public s_keyHash;
    uint256 public s_fee;

    mapping (address => bool) _isBoughts;
    uint256 public _affiliatePercent;   //Multipled by 1000

    mapping(bytes32 => RequestInfo) public _requestInfos;
    
    //Rarity: 1,2,3,4
    uint256[] public _rarities;
    
    //Ability to appear Rarity
    //Level -> Rarity -> Ability
    //Ability is multipled by 100
    mapping(uint256 => mapping(uint256 => uint256)) public _rarityAbilities;

    //List of base card id by rarity
    //Rarity => base card id list
    mapping(uint256 => uint256[]) public _baseCardIds;

    //Body parts
    //Rarity => Base card id => body part (1, 2, 3, 4, 5, 6) => list of body part
    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256[]))) public _bodyParts;

    //Quality
    //Rarity => Base card id => list of quality
    mapping(uint256 => mapping(uint256 => uint256[])) public _qualities;

    //Classes
    //Rarity => Base card id => list of class
    mapping(uint256 => mapping(uint256 => uint256[])) public _classes;

    uint256 internal _processValue = 0;

    constructor(
        address paymentTokenAddress, address recepientTokenAddress, address elemonInfoAddress, address elemonNFTAddress,
        uint256 affiliatePercent,
        address vrfCoordinator, address link, bytes32 keyHash, uint256 fee) VRFConsumerBase(vrfCoordinator, link){
        s_keyHash = keyHash;
        s_fee = fee;

        _paymentTokenAddress = paymentTokenAddress;
        _recepientTokenAddress = recepientTokenAddress;
        _elemonInfo = IElemonInfo(elemonInfoAddress);
        _elemonNFT = IElemonNFT(elemonNFTAddress);
        _affiliatePercent = affiliatePercent;

        _rarities = [1, 2, 3, 4];

        _levelPrices[1] = 100000000000000000000;
        _levelPrices[2] = 500000000000000000000;
        _levelPrices[3] = 1000000000000000000000;

        _rarityAbilities[1][1] = 6000;
        _rarityAbilities[1][2] = 3800;
        _rarityAbilities[1][3] = 189;
        _rarityAbilities[1][4] = 10;
        _rarityAbilities[1][5] = 1;

        _rarityAbilities[2][1] = 0;
        _rarityAbilities[2][2] = 50;
        _rarityAbilities[2][3] = 35;
        _rarityAbilities[2][4] = 15;
        _rarityAbilities[2][5] = 0;

        _rarityAbilities[3][1] = 0;
        _rarityAbilities[3][2] = 0;
        _rarityAbilities[3][3] = 50;
        _rarityAbilities[3][4] = 40;
        _rarityAbilities[3][5] = 10;

        _baseCardIds[1] = [4,6,9,10,12,16,17,20];
        _baseCardIds[2] = [4,6,9,10,12,16,17,20];
        _baseCardIds[3] = [4,6,9,10,12,16,17,20];
        _baseCardIds[4] = [17];
    }
    
    function setRarities(uint256[] memory rarities) external onlyOwner{
        require(rarities.length > 0, "Invalid parameters");
        _rarities = rarities;
    }

    function setRarityAbility(uint256 level, uint256 rarity, uint256 ability) external onlyOwner{
        require(level > 0 && rarity > 0 && ability > 999, "Invalid parameters");
        _rarityAbilities[level][rarity] = ability;
    }

    function setRarityAbilities(uint256 level, uint256[] memory rarities, uint256[] memory abilities) external onlyOwner{
        require(level > 0, "Invalid parameters");
        require(rarities.length > 0, "Rarities is invalid");
        require(rarities.length == abilities.length, "Rarities or abilities parameter is invalid");

        for(uint index = 0; index < rarities.length; index++){
            uint256 ability = abilities[index];
            require(ability > 999, "ability should be greater than 999");
            _rarityAbilities[level][rarities[index]] = ability;
        }
    }

    function setBaseCardIds(uint256 level, uint256[] memory baseCardIds) external onlyOwner{
        require(level > 0, "Level should be greater than 0");
        require(baseCardIds.length > 0, "baseCardIds should be not empty");
        _baseCardIds[level] = baseCardIds;
    }

    function setBodyPart(uint256 rarity, uint256 baseCardId, uint256 part, uint256[] memory bodyParts) external onlyOwner{
        require(rarity > 0, "rarity should be greater than 0");
        require(baseCardId > 0, "baseCardId should be greater than 0");
        require(part > 0 && part <= 6, "part is invalid");
        require(bodyParts.length > 0, "bodyParts should be not empty");
        _bodyParts[rarity][baseCardId][part] = bodyParts;
    }

    function setProperties(uint256 rarity, uint256 baseCardId, 
        uint256[] memory bodyParts1, uint256[] memory bodyParts2, uint256[] memory bodyParts3, 
        uint256[] memory bodyParts4, uint256[] memory bodyParts5, uint256[] memory bodyParts6,
        uint256[] memory qualities, uint256[] memory classes) external onlyOwner{
        require(rarity > 0, "rarity should be greater than 0");
        require(baseCardId > 0, "baseCardId should be greater than 0");
        _bodyParts[rarity][baseCardId][1] = bodyParts1;
        _bodyParts[rarity][baseCardId][2] = bodyParts2;
        _bodyParts[rarity][baseCardId][3] = bodyParts3;
        _bodyParts[rarity][baseCardId][4] = bodyParts4;
        _bodyParts[rarity][baseCardId][5] = bodyParts5;
        _bodyParts[rarity][baseCardId][6] = bodyParts6;
        
        _qualities[rarity][baseCardId] = qualities;
        _classes[rarity][baseCardId] = classes;
    }

    function setQuality(uint256 rarity, uint256 baseCardId, uint256[] memory qualities) external onlyOwner{
        require(rarity > 0, "rarity should be greater than 0");
        require(baseCardId > 0, "baseCardId should be greater than 0");
        require(qualities.length > 0, "qualities should be not empty");
        _qualities[rarity][baseCardId] = qualities;
    }

    function setClass(uint256 rarity, uint256 baseCardId, uint256[] memory classes) external onlyOwner{
        require(rarity > 0, "rarity should be greater than 0");
        require(baseCardId > 0, "baseCardId should be greater than 0");
        require(classes.length > 0, "classes should be not empty");
        _classes[rarity][baseCardId] = classes;
    }

    function setPaymentTokenAddress(address paymentTokenAddress) external onlyOwner{
        require(paymentTokenAddress != address(0), "Address 0");
        _paymentTokenAddress = paymentTokenAddress;
    }

    function setRecepientTokenAddress(address recepientTokenAddress) external onlyOwner{
        require(recepientTokenAddress != address(0), "Address 0");
        _recepientTokenAddress = recepientTokenAddress;
    }

    function setAffiliatePercent(uint256 percent) external onlyOwner{
        _affiliatePercent = percent;
    }

    function setElemonInfo(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Address 0");
        _elemonInfo = IElemonInfo(newAddress);
    }

    function setElemonNFT(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Address 0");
        _elemonNFT = IElemonNFT(newAddress);
    }

    function setLevelPrice(uint256 level, uint256 price) external onlyOwner{
        require(level > 0, "Level should be greater than 0");
        _levelPrices[level] = price;
        emit LevelPriceSetted(level, price);
    }

    function open(uint256 level, address affiliateAddress) external nonReentrant{
        require(level > 0, "Level should be greater than 0");
        require(_recepientTokenAddress != address(0), "Recepient address is not setted");
        uint256 price = _levelPrices[level];
        require(price > 0, "Price should be greater than 0");

        if(!_isBoughts[affiliateAddress]){
            IERC20(_paymentTokenAddress).transferFrom(_msgSender(), _recepientTokenAddress, price);
        }else{
            uint256 affiliateQuantity = price * _affiliatePercent / 1000 / 100;
            IERC20(_paymentTokenAddress).transferFrom(_msgSender(), affiliateAddress, affiliateQuantity);
            IERC20(_paymentTokenAddress).transferFrom(_msgSender(), _recepientTokenAddress, price - affiliateQuantity);
        }

        //Mint NFT
        uint256 tokenId = _elemonNFT.mint(msg.sender);

        //Request chainlink VRF
        require(LINK.balanceOf(address(this)) >= s_fee, "Not enough LINK to pay fee");
        bytes32 requestId = requestRandomness(s_keyHash, s_fee);
        _requestInfos[requestId] = RequestInfo({
            tokenId: tokenId,
            level: level
        });

        _isBoughts[_msgSender()] = true;
        
        emit Purchased(_msgSender(), tokenId, level, block.timestamp);
    }

    function setKeyHash(bytes32 keyHash) public onlyOwner {
        s_keyHash = keyHash;
    }

    function setFee(uint256 fee) public onlyOwner {
        s_fee = fee;
    }

    function withdrawToken(address tokenAddress, address recepient, uint256 value) public onlyOwner {
        IERC20(tokenAddress).transfer(recepient, value);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        RequestInfo storage requestInfo = _requestInfos[requestId];
        require(requestInfo.tokenId > 0, "Request is invalid");
        //Get rarity
        _processValue = 0;
        for(uint256 index = 0; index < _rarities.length; index++){
            _processValue += _rarityAbilities[requestInfo.level][_rarities[index]];
        }
        uint256 rarityNumber = randomness % _processValue + 1;
        _processValue = 0;
        uint256 rarity = 0;
        for(uint256 index = 0; index < _rarities.length; index++){
            _processValue += _rarityAbilities[requestInfo.level][_rarities[index]];
            if(rarityNumber <= _processValue){
                rarity = _rarities[index];
                break;
            }
        }

        require(rarity > 0, "Fail to get rarity");

        //Get base cardId
        uint256[] memory baseCardIds = _baseCardIds[rarity];
        _processValue = baseCardIds.length - 1;

        uint256 baseCardId = 0;
        if(_processValue == 0)
            baseCardId = baseCardIds[_processValue];
        else
            baseCardId = baseCardIds[randomness % _processValue];

        //Get body parts
        uint256 bodyPart01 = _getBodyPartItem(randomness, _bodyParts[rarity][baseCardId][1]);
        uint256 bodyPart02 = _getBodyPartItem(randomness, _bodyParts[rarity][baseCardId][2]);
        uint256 bodyPart03 = _getBodyPartItem(randomness, _bodyParts[rarity][baseCardId][3]);
        uint256 bodyPart04 = _getBodyPartItem(randomness, _bodyParts[rarity][baseCardId][4]);
        uint256 bodyPart05 = _getBodyPartItem(randomness, _bodyParts[rarity][baseCardId][5]);
        uint256 bodyPart06 = _getBodyPartItem(randomness, _bodyParts[rarity][baseCardId][6]);

        uint256 quality = _getBodyPartItem(randomness, _qualities[rarity][baseCardId]);
        uint256 class = _getBodyPartItem(randomness, _classes[rarity][baseCardId]);

        _elemonInfo.setInfo(requestInfo.tokenId, rarity, baseCardId, 
            bodyPart01, bodyPart02, bodyPart03, bodyPart04, bodyPart05, bodyPart06, 
            quality, class);

        uint256 tokenId = requestInfo.tokenId;
        requestInfo.tokenId = 0;

        emit ElemonOpened(tokenId, rarity, 
            baseCardId, bodyPart01, bodyPart02, bodyPart03, 
            bodyPart04, bodyPart05, bodyPart06, quality, class);
    }
    
    function _getBodyPartItem(uint256 number, uint256[] memory bodyParts) internal pure returns(uint256){
        uint256 processValue = 0;
        for(uint256 index = 0; index < bodyParts.length; index++){
            processValue += bodyParts[index];
        }
        uint256 rarityNumber = number % processValue + 1;
        processValue = 0;
        for(uint256 index = 0; index < bodyParts.length; index++){
            processValue += bodyParts[index];
            if(rarityNumber <= processValue){
                return index + 1;
            }
        }
        return 1;
    }

    function _msgSender() internal view returns(address){
        return msg.sender;
    }
    
    event LevelPriceSetted(uint256 level, uint256 price);
    event Purchased(address account, uint256 tokenId, uint256 level, uint256 time);
    event ElemonOpened(uint256 tokenId, uint256 rarity, uint256 baseCardId, 
        uint256 bodyPart01, uint256 bodyPart02, uint256 bodyPart03, uint256 bodyPart04, uint256 bodyPart05, uint256 bodyPart06, 
        uint256 quality, uint256 class);
}