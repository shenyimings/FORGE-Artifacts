// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "./IStarNFT.sol";

interface INFTLogic {
    function setBonusToke(uint256 _tokenId,uint256 _amountBonus) external;
    function disposeBonusToke(uint256 _tokenId) view external returns (uint256);
}

interface INFTMarket {
    function getUserTokensLength(address _user) view external returns (uint256);
    function getUserTokens(address _user) view external returns (uint256[] memory);
}

interface IStarFarm {
    function getUserStakingNFTAmount(address _user) view external returns (uint256);
    function getUserNFTs(address _user) view external returns (uint256[] memory);
}

contract Bonus is ContextUpgradeable, OwnableUpgradeable {

    using SafeMathUpgradeable for uint256;
    IERC20Upgradeable public starToken;
    IERC721Upgradeable public starNFT;
    INFTLogic public NFTLogic;
    INFTMarket public NFTMarket;
    IStarFarm public StarFarm;
    IStarNFT public StarNFT1;
    address public lockAddr;
    uint256 public lockRatio;
    uint256 public bonusWithdrawn;
    uint256 public lockWithdrawn;
    uint256 public totalAmount;

    mapping(uint256 => uint256) public tokenWithdraw;

    address public nodeAddr;

    function initialize(address _starToken, address _lock, uint256 _lockRatio) public initializer {
        __bonus_init(_starToken, _lock, _lockRatio);
    }

    function __bonus_init(address _starToken, address _lock, uint256 _lockRatio) internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __bonus_init_unchained(_starToken, _lock, _lockRatio);
    }

    function __bonus_init_unchained(address _starToken, address _lock, uint256 _lockRatio) internal initializer {
        require(_lockRatio < 10000, 'ratio error');
        starToken = IERC20Upgradeable(_starToken);
        lockAddr = _lock;
        lockRatio = _lockRatio;
    }

    function setLockRatio(uint256 _newRatio) onlyOwner public {
        require(_newRatio < 10000, 'ratio error');
        lockRatio = _newRatio;
    }

    function lockWithdraw(uint256 _amount) onlyLockUser public {
        require(_amount > 0, "amount error");
        uint256 _balance = starToken.balanceOf(address(this));
        uint256 _availLock = _balance.add(lockWithdrawn).add(bonusWithdrawn).mul(lockRatio).div(10000).sub(lockWithdrawn);
        require(_amount <= _availLock, 'amount error');
        lockWithdrawn = lockWithdrawn.add(_amount);
        starToken.transfer(_msgSender(), _amount);
    }

    function _getBonus(uint256 _tokenId) internal view returns (uint256) {
        uint256 bonunsAmount = NFTLogic.disposeBonusToke(_tokenId);
        return bonunsAmount;
    }

    function getTokenWithdraw(uint256 _tokenId) public view returns(uint256){
        return tokenWithdraw[_tokenId];
    }

    function allWithdrawal(address owner) public{
        owner = _msgSender();
        uint256 _amount = 0;
        for (uint256 i = 0 ; i < StarNFT1.balanceOf(owner); i ++){
            uint256 _tokenId = StarNFT1.tokenOfOwnerByIndex(owner,i);
            uint256 _number = _getBonus(_tokenId);
            tokenWithdraw[_tokenId] = tokenWithdraw[_tokenId].add(_number);
            NFTLogic.setBonusToke(_tokenId,0);
            _amount += _number;
        }
        for (uint256 i = 0 ; i < NFTMarket.getUserTokensLength(owner); i ++){
            uint256[] memory _tokenIds = NFTMarket.getUserTokens(owner);
            for (uint256 j = 0 ; j < _tokenIds.length; j ++){
                uint256 _tokenId = _tokenIds[j];
                uint256 _number = _getBonus(_tokenIds[j]);
                tokenWithdraw[_tokenId] = tokenWithdraw[_tokenId].add(_number);
                NFTLogic.setBonusToke(_tokenIds[j],0);
                _amount += _number;
            }
        }
        for (uint256 i = 0 ; i < StarFarm.getUserStakingNFTAmount(owner); i ++){
            uint256[] memory _tokenIds = StarFarm.getUserNFTs(owner);
            for (uint256 j = 0 ; j < _tokenIds.length; j ++){
                uint256 _tokenId = _tokenIds[j];
                uint256 _number = _getBonus(_tokenId);
                tokenWithdraw[_tokenId] = tokenWithdraw[_tokenId].add(_number);
                NFTLogic.setBonusToke(_tokenId,0);
                _amount += _number;
            }
        }
        bonusWithdrawn = bonusWithdrawn.add(_amount);
        if(_amount != 0){
            starToken.transfer(_msgSender(), _amount);
        }
    }

    function transferMarket(address _owner,uint256 _amount) external onlyMarket {
        starToken.transfer(_owner, _amount);
    }

    function addTotalAmount(uint256 _amount) external onlyTotalAmount {
        totalAmount += _amount;
    }
	
    function getTotalAmount() external view returns (uint256) {
        return totalAmount;
    }

    function getlockRatio() external view returns (uint256) {
        return lockRatio;
    }

    function getlockAddress() external view returns (address) {
        return lockAddr;
    }

    function setTokenWithdraw(uint256 _tokenId,uint256 _amount) external onlyTotalAmount {
        tokenWithdraw[_tokenId] = tokenWithdraw[_tokenId].add(_amount);
    }

    function setBonusWithdrawn(uint256 _amount) external onlyTotalAmount {
        bonusWithdrawn = bonusWithdrawn.add(_amount);
    }

    function getBonus(uint256 _tokenId) view external returns (uint256) {
        return _getBonus(_tokenId);
    }

    function setNode(address _node) onlyOwner public {
        require(address(0) != _node, 'node address error');
        nodeAddr = _node;
    }

    function setLock(address _addr) onlyOwner public {
        require(address(0) != _addr, 'lock address error');
        lockAddr = _addr;
    }

    function setNFT(address _addr) onlyOwner public {
        require(address(0) != _addr, 'NFT address error');
        starNFT = IERC721Upgradeable(_addr);
        StarNFT1 = IStarNFT(_addr);
    }

    function setNFTLogic(address _addr) onlyOwner public {
        require(address(0) != _addr, 'NFTLogic address error');
        NFTLogic = INFTLogic(_addr);
    }

    function setNFTMarket(address _addr) onlyOwner public {
        require(address(0) != _addr, 'NFTMarket address error');
        NFTMarket = INFTMarket(_addr);
    }

    function setStarFarm(address _addr) onlyOwner public {
        require(address(0) != _addr, 'StarFarm address error');
        StarFarm = IStarFarm(_addr);
    }

    modifier onlyLockUser() {
        require(_msgSender() == lockAddr, 'no permission');
        _;
    }

    modifier onlyMarket() {
        require(INFTMarket(_msgSender()) == NFTMarket, 'no permission');
        _;
    }
	
    modifier onlyTotalAmount() {
        require(_msgSender() == owner() || _msgSender() == nodeAddr || IStarFarm(_msgSender()) == StarFarm || INFTLogic(_msgSender()) == NFTLogic || INFTMarket(_msgSender()) == NFTMarket , 'no permission');
        _;
    }
}