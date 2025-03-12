// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IForeProtocol is IERC721 {
    function allMarketLength() external view returns (uint256);

    function allMarkets(uint256) external view returns (address);

    function burn(uint256 tokenId) external;

    function buyPower(uint256 id, uint256 amount) external;

    function config() external view returns (address);

    function market(bytes32 mHash) external view returns (address);

    function createMarket(
        bytes32 marketHash,
        address creator,
        address receiver,
        address marketAddress
    ) external returns (uint256);

    function foreToken() external view returns (address);

    function foreVerifiers() external view returns (address);

    function isForeMarket(address market) external view returns (bool);

    function isForeOperator(address addr) external view returns (bool);

    function mintVerifier(address receiver) external;

    event MarketCreated(
        address indexed factory,
        address indexed creator,
        bytes32 marketHash,
        address market,
        uint256 marketIdx
    );
}
