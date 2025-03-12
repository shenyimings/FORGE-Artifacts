// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
 
contract KojiAuth is Ownable {

    modifier onlyAuthorized() {
        require(authorized[_msgSender()] || owner() == address(_msgSender()), "User not Authorized to Directory");
        _;
    }

    address public getKojiEarth; 
    address public getKojiPair;
    address public getKojiOracle;
    address public getKojiFlux;
    address public getKojiStaking;
    address public getKojiNFT;
    address public getKojiRewards;
    address public getKojiNFTPoster;

    address public getMarketOrder;
    address public getMarketplace;
    address public getGameContract;
    address public getGamePass;
    address public getInserter;
    address public getAdmin;
    address public getCharity;
    address public DEAD = 0x000000000000000000000000000000000000dEaD;
    
    mapping(address => bool) internal authorized;

    function addAuthorized(address _toAdd) onlyOwner public {
        require(_toAdd != address(0), "Address is the zero address");
        authorized[_toAdd] = true;
    }

    function removeAuthorized(address _toRemove) onlyOwner public {
        require(_toRemove != address(0), "Address is the zero address");
        authorized[_toRemove] = false;
    }

    function isAuthorized(address _address) external view returns (bool) {
        return authorized[_address];
    }

    constructor() {
        authorized[_msgSender()] = true;
    }

    receive() external payable {}

    function updateOne(
        address a1,
        address a2,
        address a3,
        address a4,
        address a5,
        address a6,
        address a7,
        address a8
    ) 
    external onlyAuthorized {
        getKojiEarth = a1; 
        getKojiPair = a2;
        getKojiOracle = a3;
        getKojiFlux = a4;
        getKojiStaking = a5;
        getKojiNFT = a6;
        getKojiRewards = a7;
        getKojiNFTPoster = a8;
    }

    function updateTwo(
        address a9,
        address a10,
        address a11,
        address a12,
        address a13,
        address a14,
        address a15
    ) 
    external onlyAuthorized {
        getMarketOrder = a9;
        getMarketplace = a10;
        getGameContract = a11;
        getGamePass = a12;
        getInserter = a13;
        getAdmin = a14;
        getCharity = a15;
    }

    function rescueETHFromContract() external onlyAuthorized {
        address payable _owner = payable(_msgSender());
        _owner.transfer(address(this).balance);
    }

    function transferERC20Tokens(address _tokenAddr, address _to, uint _amount) external onlyAuthorized {
        IERC20(_tokenAddr).transfer(_to, _amount);
    }

}
