// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title Growth type Lightweight SBT interface developed by SoulSociety
/// @notice There is a part where the gas fee required by Ethereum is too expensive to contain various information. 
/// Therefore, by considering each contract as a piece of information, we tried to implement growth-type SBT through minimum information and minimum gas cost by managing growth in the contract.
interface ISoulSocietySBT {

    event ContractCreated(address indexed creator, uint256 creationTime, string name, string symbol, string uri);
    
    event SetTokenURI(address indexed sender, string uri);

    /**
     * @dev Emitted when `tokenId` token is minted from `from(Contract Owner)` to `to`.
     */
    event Mint(address from, address indexed to, uint256 indexed tokenId, uint256 indexed tokenType);

    event Reset(address indexed to, uint indexed tokenId);

    // @notice Emitted when user grows
    // @param to Address that user Address
    // @param tokenId SBT Token ID
    // @param growth User growth
    event GrowUp(address indexed to, uint256 tokenId, uint256 indexed growth);

    function mint(address to, uint256 tokenType) external returns (uint256);

    // @notice Function to grow users
    // @param Address of the user you want to grow
    // function growUp(address) external returns (uint256);
    function growUp(address to, uint256 tokenId) external returns (uint256);

    function reset(address to, uint256 tokenId) external ; 

    function setTokenURI(string memory tokenURI) external returns(string memory);

    // @notice A function that makes the SBT you hold private
    // @param protected flag
    // @return true when normally private, false when already locked or failed
    function setProtected(bool isProtected) external returns (bool);

    function setApprovalGrowth(uint256 tokenId_, bool approved_) external;

    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    // @notice A function that provides the number of currently registered users
    // @return Number of currently registered users
    function totalUser() external view  returns (uint256);

    // @notice Function to check whether a specific SBT is public
    // @param user address
    // @return true when public, false when private
    function isProtected(address) external view returns (bool);

    // @notice This function contains user growth information.
    // @param tokem Id
    function getGrowth(uint256 tokenId) external view returns (uint256);

    function getTokenType(uint256 tokenId_) external view returns (uint256);

    function getApprovalGrowth(address owner_, uint256 tokenId_ ) external view returns(bool);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

}