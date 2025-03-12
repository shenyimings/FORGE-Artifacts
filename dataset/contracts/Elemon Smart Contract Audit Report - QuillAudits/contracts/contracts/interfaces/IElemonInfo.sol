//SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IElemonInfo {
    function setInfo(uint256 tokenId, uint256 rarity, uint256 baseCardId,
        uint256 bodyPart01, uint256 bodyPart02, uint256 bodyPart03, uint256 bodyPart04,
        uint256 bodyPart05, uint256 bodyPart06, uint256 quality, uint256 class) external;

    function getRarity(uint256 tokenId) external view returns(uint256);
}