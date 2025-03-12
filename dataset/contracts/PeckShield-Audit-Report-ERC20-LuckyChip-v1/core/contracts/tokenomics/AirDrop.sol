// SPDX-License-Identifier: MIT
  
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../token/LCToken.sol";

contract AirDrop is Ownable, ReentrancyGuard{
    using SafeMath for uint256;

    mapping(address => bool) public isClaimedMap;
    LCToken public lcToken;
    uint256 public singleAmount;
    uint256 public totalAmount;
    uint256 public accAmount;

    event ClaimAirDrop(address indexed user, uint256 blockNumber, uint256 amount);

    constructor(address _lcTokenAddr, uint256 _singleAmount, uint256 _totalAmount) public {
        lcToken = LCToken(_lcTokenAddr);
        singleAmount = _singleAmount;
        totalAmount = _totalAmount;
    }

    modifier notContract() {
        require((!_isContract(msg.sender)) && (msg.sender == tx.origin), "no contract");
        _;
    }

    // Judge address is contract or not
    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function claimAirDrop() external nonReentrant notContract{
        bool isClaimed = isClaimedMap[msg.sender];
        require(isClaimed == false, "Has claimed airDrop");
        require(accAmount.add(singleAmount) <= totalAmount, "No AirDrop amount left");
        isClaimedMap[msg.sender] = true;
        accAmount = accAmount.add(singleAmount);
        lcToken.mint(msg.sender, singleAmount);
        emit ClaimAirDrop(msg.sender, block.number, singleAmount); 
    }

    function setSingleAmount(uint256 _singleAmount) external onlyOwner {
        singleAmount = _singleAmount;
    }

    function setTotalAmount(uint256 _totalAmount) external onlyOwner {
        totalAmount = _totalAmount;
    }
}
