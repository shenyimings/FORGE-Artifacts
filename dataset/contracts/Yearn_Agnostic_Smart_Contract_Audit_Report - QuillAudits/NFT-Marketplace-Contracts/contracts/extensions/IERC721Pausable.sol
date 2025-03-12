// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <= 0.8.6;

interface IERC721Pausable {

    event Paused(uint256 _tokenId);//, uint256 _timeSec);
    event Resumed(uint256 _tokenId);
    
    function pause(uint256 _tokenId) external;

    function resume(uint256 _tokenId) external;
}