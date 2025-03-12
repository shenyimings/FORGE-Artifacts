// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

interface ITokenManager {
    function isBattlePlace(address _address) external view returns (bool);

    function isFarmer(address _address) external view returns (bool);

    function isTrainer(address _address) external view returns (bool);

    function getExpLevel(uint256 _exp) external view returns (uint256);

    function randomRareLevel(uint256 _tokenId) external view returns (uint256);

    function getChestPrice() external view returns (uint256);

    function getMarketFeeAddress() external view returns (address);

    function getMarketFee(uint256 _price) external view returns (uint256);

    function getTransferFeeAddress() external view returns (address);

    function getTransferFeeRate() external view returns (uint256);
}
