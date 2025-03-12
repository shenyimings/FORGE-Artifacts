// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

/*

    ███████╗██████╗  █████╗ ███╗   ██╗██╗  ██╗███████╗███╗   ██╗███████╗████████╗███████╗██╗███╗   ██╗
    ██╔════╝██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝██╔════╝████╗  ██║██╔════╝╚══██╔══╝██╔════╝██║████╗  ██║
    █████╗  ██████╔╝███████║██╔██╗ ██║█████╔╝ █████╗  ██╔██╗ ██║███████╗   ██║   █████╗  ██║██╔██╗ ██║
    ██╔══╝  ██╔══██╗██╔══██║██║╚██╗██║██╔═██╗ ██╔══╝  ██║╚██╗██║╚════██║   ██║   ██╔══╝  ██║██║╚██╗██║
    ██║     ██║  ██║██║  ██║██║ ╚████║██║  ██╗███████╗██║ ╚████║███████║   ██║   ███████╗██║██║ ╚████║
    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚══════╝╚═╝╚═╝  ╚═══╝
                                                                      
    Website: https://frankenstein.finance/
    twitter: https://twitter.com/FrankenDefi
*/

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBEP20.sol";
import "./libraries/SafeBEP20.sol";
import "./interfaces/IHelp.sol";

contract LotteryNFT is ERC721, Ownable {

    using SafeBEP20 for IBEP20;
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;
    
    // The TOKEN
    IBEP20 public token;
    // lotteryAddress
    address public lottery;
    // admin Address
    address public admin;

    mapping (uint256 => uint8[4]) public lotteryInfo;
    mapping (uint256 => uint256) public lotteryAmount;
    mapping (uint256 => uint256) public issueIndex;
    mapping (uint256 => bool) public claimInfo;

    constructor(IBEP20 _token, string memory _name, string memory _alias) public ERC721(_name, _alias) {
        token = _token;
        admin = msg.sender;
    }

    function setLottery(address _lottery) external onlyOwner {
        require(lottery == address(0), "!lottery");
        lottery = _lottery;
        token.approve(lottery, uint(~0));
    }

    function setApprove() external {
        require(msg.sender == admin, "!admin");
        token.approve(lottery, uint(~0));
    }

    function newLotteryItem(address player, uint8[4] memory _lotteryNumbers, uint256 _amount, uint256 _issueIndex) external onlyOwner returns (uint256){
        tokenIds.increment();
        uint256 newItemId = tokenIds.current();
        _mint(player, newItemId);
        lotteryInfo[newItemId] = _lotteryNumbers;
        lotteryAmount[newItemId] = _amount;
        issueIndex[newItemId] = _issueIndex;
        return newItemId;
    }

    function getLotteryNumbers(uint256 tokenId) external view returns (uint8[4] memory) {
        return lotteryInfo[tokenId];
    }

    function getLotteryAmount(uint256 tokenId) external view returns (uint256) {
        return lotteryAmount[tokenId];
    }

    function getLotteryIssueIndex(uint256 tokenId) external view returns (uint256) {
        return issueIndex[tokenId];
    }

    function claimReward(uint256 tokenId) external onlyOwner {
        claimInfo[tokenId] = true;
    }

    function multiClaimReward(uint256[] memory _tokenIds) external onlyOwner {
        for (uint i = 0; i < _tokenIds.length; i++) {
            claimInfo[_tokenIds[i]] = true;
        }
    }

    function burn(uint256 tokenId) external onlyOwner {
        _burn(tokenId);
    }

    function getClaimStatus(uint256 tokenId) external view returns (bool) {
        return claimInfo[tokenId];
    }

}