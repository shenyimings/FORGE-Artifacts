pragma solidity ^0.8.0;


/**
 * @dev Interface of gamejam .
 */
interface IRentalContract {
    /**
     * @dev update RentNFT pricing, 0 mean not public for rent
     */
    function updateRentPrice(uint256 chainId, address contractAddress, uint256 tokenId, uint256 pricingPerDay) external returns (bool);

    /**
     * @dev rent the NFT
     */
    function rentNFT(uint256 chainId, address contractAddress, uint256 tokenId, uint8 rentedDay, address paidToken, uint256 amount) payable external returns (bool);

    /**
    * @dev add profit to user
     */
    function addProfit(address owner, uint256 addingBalance, string memory receiptId) external returns (bool);


    /**
     * @dev rent the NFT via IAP
     */
    function rentNFTViaIAP(uint256 chainId, address contractAddress, uint256 tokenId, address renter, address owner, uint8 rentedDay, uint256 addingBalance, string memory receiptId) external returns (bool);

    /**
     * @dev Emitted when a nft is updateRentPrice
     */
    event UpdateRentPrice(uint256 chainId, address contractAddress, uint256 tokenId, uint256 pricingPerDay);

    /**
         * @dev Emitted when a nft is rented
     */
    event RentNFT(address indexed renter, uint256 chainId, address contractAddress, uint256 tokenId, uint8 rentedDay, address paidToken, uint256 amount, uint256 profit, uint256 fee);

    /**
         * @dev Emitted when a nft is rented via IAP
     */
    event RentNFTViaIAP(address indexed renter,address indexed owner, uint256 chainId, address contractAddress, uint256 tokenId, uint8 rentedDay, string receiptId, uint256 profit);

}
