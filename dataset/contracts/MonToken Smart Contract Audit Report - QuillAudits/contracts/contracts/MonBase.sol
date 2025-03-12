// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IMonNFT.sol";

contract MonBase is Ownable, IERC721Receiver{
    uint256 public MULTIPLIER = 1000;
    
    IERC20 private _monToken;
    IMonNFT private _monNFT;
    
    uint256 private _feePercent;    //Multipled by 1000
    
    constructor(address monTokenAddress, address monNFTAddress){
        _monToken = IERC20(monTokenAddress);
        _monNFT = IMonNFT(monNFTAddress);
        _feePercent = 5000;    //5%
    }
    
    /**
     * @dev Get MON token 
     */
    function getMonToken() public view returns(IERC20){
        return _monToken;
    }
    
    /**
     * @dev Get MON NFT
     */
    function getMonNFT() public view returns(IMonNFT){
        return _monNFT;
    }

    function getFeePercent() public view returns(uint){
        return _feePercent;
    }
    
    function setTokenNFT(address newAddress) public onlyOwner{
        require(newAddress != address(0), "Zero address");
        _monNFT = IMonNFT(newAddress);
    }
    
    function setMonToken(address newAddress) public onlyOwner{
        require(newAddress != address(0), "Zero address");
        _monToken = IERC20(newAddress);
    }
    
    function setFeePercent(uint feePercent) public onlyOwner{
        _feePercent = feePercent;
    }
    
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external view override returns (bytes4){
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}