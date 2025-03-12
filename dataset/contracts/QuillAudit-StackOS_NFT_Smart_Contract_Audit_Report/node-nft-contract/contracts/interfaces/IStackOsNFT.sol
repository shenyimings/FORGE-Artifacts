//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IStackOsNFT is IERC721 {

    function whitelist(address _addr) external;

    function getMaxSupply() external view returns (uint256);

    function getDelegatee(uint256 _tokenId) external view returns (address);

    function transferOwnership(address newOwner) external;

    function exists(uint256 _tokenId) external returns (bool);

}
