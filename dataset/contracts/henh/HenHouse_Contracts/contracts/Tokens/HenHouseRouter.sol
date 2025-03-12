// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract HenHouseRouter is Ownable {
    using SafeMath for uint256;

    mapping(address => bool) public hatchers;
    mapping(address => bool) public farmOwners;
    mapping(uint256 => uint256) public eggPrice;
    mapping(address => bool) public nftContract;
    
    uint256 public chickenTokenId;
    uint256 public henhouseTokenId;
    address public feeAddress;
    uint256 public feeEgg = 15;
    uint256 public feeMarket = 10;
    uint256 public feeHatch = 20;
    uint256 public divPercent = 1000;

    constructor() {
        feeAddress = _msgSender();
    }

    
    modifier onlyHatcher(address _hatcher) {
        require(hatchers[_hatcher], "not hatched");
        _;
    }

    modifier onlyNFTContract() {
        require(nftContract[msg.sender], "not NFT Contract");
        _;
    }

    function setFarmOwners(address _farmer) public onlyOwner {
        farmOwners[_farmer] = true;
    }

    function setNFTContracts(address _contract) public onlyOwner {
        nftContract[_contract] = true;
    }

    function setHatchers(address _chester) public onlyOwner {
        hatchers[_chester] = true;
    }

    function setFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
    }

    function setEggPrice(uint256 _tier,uint256 _price) public onlyOwner {
        eggPrice[_tier] = _price * 10**18;
    }

    function setFeeEgg(uint256 _fee) public onlyOwner {
        feeEgg = _fee;
    }

    function setFeeMarket(uint256 _fee) public onlyOwner {
        feeMarket = _fee;
    }
    function setFeeHatch(uint256 _fee) public onlyOwner {
        feeHatch = _fee;
    }    

    function incrementTokenId(uint8 _type) public onlyNFTContract {
        if (_type == 0){
            chickenTokenId++;
        }
        else{
            henhouseTokenId++;
        }
    }

    function getNextTokenId(uint8  _type) public view onlyNFTContract returns (uint256)  {
        if (_type == 0){
            return chickenTokenId.add(1);
        }
        else{
           return henhouseTokenId.add(1);
        }
    }    
        

    function getLastId(uint8 _type) public view returns (uint256)  {
       if (_type == 0){
            return chickenTokenId;
        }
        else{
           return henhouseTokenId;
        }
    }    
}