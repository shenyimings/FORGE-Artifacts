// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./core/Ownable.sol";
import "./interfaces/IAvatarArtArtistKYC.sol";

contract AvatarArtArtistKYC is IAvatarArtArtistKYC, Ownable{
    mapping(address => bool) private _isVerifieds;
    
    function isVerified(address account) external override view returns(bool){
        return _isVerifieds[account];
    }
    
    function toggleVerify(address account) external onlyOwner{
        _isVerifieds[account] = !_isVerifieds[account];
    }
}