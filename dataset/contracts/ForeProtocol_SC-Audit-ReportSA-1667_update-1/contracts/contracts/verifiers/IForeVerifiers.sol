// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IForeVerifiers is IERC721 {
    function decreasePower(uint256 id, uint256 amount) external;

    function protocol() external view returns (address);

    function height() external view returns (uint256);

    function increasePower(
        uint256 id,
        uint256 amount,
        bool increaseValidationNum
    ) external;

    function mintWithPower(
        address to,
        uint256 amount,
        uint256 tier,
        uint256 validationNum
    ) external returns (uint256 mintedId);

    function increaseValidation(uint256 id) external;

    function initialPowerOf(uint256 id) external view returns (uint256);

    function powerOf(uint256 id) external view returns (uint256);

    function burn(uint256 tokenId) external;

    function nftTier(uint256 id) external view returns (uint256);

    function verificationsSum(uint256 id) external view returns (uint256);

    function multipliedPowerOf(uint256 id) external view returns (uint256);

    function transferFrom(address from, address to, uint256 tokenId) external;

    function marketTransfer(address from, uint256 amount) external;

    function marketBurn(uint256 amount) external;
}
