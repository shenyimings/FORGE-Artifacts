// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../PRNG.sol";
import "./Auction.sol";
import "./BlindAuction.sol";

contract Marketplace is ReentrancyGuard {
    PRNG public prng;

    Auction[] public auctions;
    BlindAuction[] public blindAuctions;

    struct Royalty {
        // number of decimal position to include in the royalty percent
        uint8 decimals;
        // royalty percent from 0 to 100% with `decimals` decimal position
        uint256 royaltyPercent;
        // address that will receive the royalties for future sales via this
        // smart contract. Other smart contracts functionalities cannot be
        // controlled in any way
        address royaltyReceiver;
        // address of the one who can edit all this royalty settings
        address royaltyInitializer;
    }

    /**
        This mapping is a workaround for a double map with 2 indexes.
        index: keccak256(
            abi.encode(
                nft smart contract address,
                nft identifier
            )
        )
        map: Royalty
     */
    mapping(bytes32 => Royalty) public royalties;

    /*
     *     bytes4(keccak256("balanceOf(address)")) == 0x70a08231
     *     bytes4(keccak256("ownerOf(uint256)")) == 0x6352211e
     *     bytes4(keccak256("approve(address,uint256)")) == 0x095ea7b3
     *     bytes4(keccak256("getApproved(uint256)")) == 0x081812fc
     *     bytes4(keccak256("setApprovalForAll(address,bool)")) == 0xa22cb465
     *     bytes4(keccak256("isApprovedForAll(address,address)")) == 0xe985e9c5
     *     bytes4(keccak256("transferFrom(address,address,uint256)")) == 0x23b872dd
     *     bytes4(keccak256("safeTransferFrom(address,address,uint256)")) == 0x42842e0e
     *     bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)")) == 0xb88d4fde
     *
     *     => 0x70a08231 ^ 0x6352211e ^ 0x095ea7b3 ^ 0x081812fc ^
     *        0xa22cb465 ^ 0xe985e9c5 ^ 0x23b872dd ^ 0x42842e0e ^ 0xb88d4fde == 0x80ac58cd
     */
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    /*
     *     bytes4(keccak256("name()")) == 0x06fdde03
     *     bytes4(keccak256("symbol()")) == 0x95d89b41
     *     bytes4(keccak256("tokenURI(uint256)")) == 0xc87b56dd
     *
     *     => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd == 0x5b5e139f
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;

    event AuctionCreated(address auction, uint256 nftId, address nftContract);
    event BlindAuctionCreated(
        address auction,
        uint256 nftId,
        address nftContract
    );
    event RoyaltyUpdated(
        uint256 nftId,
        address nftContract,
        uint256 royaltyPercent,
        address royaltyReceiver,
        address royaltyInitializer
    );

    modifier onlyERC721(address _contract) {
        prng.rotate();

        require(
            // check the SC doesn't supports the ERC721 openzeppelin interface
            ERC165Checker.supportsInterface(_contract, _INTERFACE_ID_ERC721) &&
                // check the SC doesn't supports the ERC721-Metadata openzeppelin interface
                ERC165Checker.supportsInterface(
                    _contract,
                    _INTERFACE_ID_ERC721_METADATA
                ),
            "The provided address does not seem to implement the ERC721 NFT standard"
        );

        _;
    }

    constructor(address _prng) {
        prng = PRNG(_prng);
    }

    /**
        Create a public auction. The auctioner *must* own the NFT to sell.
        Once the auction ends anyone can trigger the release of the funds raised.
        All the participant can also release their bids at anytime if they are not the
        higher bidder.
        This contract is not responsible for handling the real auction but only for its creation.

        NOTE: Before actually starting the creation of the auction the user needs
        to allow the transfer of the nft.

        @param _nftId The unique identifier of the NFT that is being sold
        @param _nftContract The address of the contract of the NFT
        @param _payee The address where the highest big will be credited
        @param _auctionDuration Number of seconds the auction will be valid
        @param _minimumPrice The minimum bid that must be placed in order for the auction to start.
                Bid lower than this amount are refused.
                If no bid is higher than this amount at the end of the auction the NFT will be sent
                to the beneficiary
        @param _royaltyReceiver The address of the royalty receiver for a given auction
        @param _royaltyPercentage The 18 decimals percentage of the highest bid that will be sent to 
                the royalty receiver
		@param _blind Whether the auction to be created is a blind auction or a simple one
     */
    function _createAuction(
        uint256 _nftId,
        address _nftContract,
        address _payee,
        uint256 _auctionDuration,
        uint256 _minimumPrice,
        address _royaltyReceiver,
        uint256 _royaltyPercentage,
        bool _blind
    ) private returns (address) {
        prng.rotate();

        // do not run any check on the contract as the checks are already performed by the
        // parent call

        // load the instance of the nft contract into the ERC721 interface in order
        // to expose all its methods
        ERC721 nftContractInstance = ERC721(_nftContract);

        address _auctionAddress;

        if (!_blind) {
            // create a new auction for the user
            Auction auction = new Auction(
                _auctionDuration,
                payable(_payee),
                _nftId,
                _nftContract,
                _minimumPrice,
                _royaltyReceiver,
                _royaltyPercentage,
                address(prng)
            );
            auctions.push(auction);
            _auctionAddress = address(auction);

            emit AuctionCreated(_auctionAddress, _nftId, _nftContract);
        } else {
            // create a new blind auction for the user
            BlindAuction blindAuction = new BlindAuction(
                _auctionDuration,
                1 days,
                payable(_payee),
                _nftId,
                _nftContract,
                _minimumPrice,
                _royaltyReceiver,
                _royaltyPercentage,
                address(prng)
            );
            blindAuctions.push(blindAuction);
            _auctionAddress = address(blindAuction);

            emit BlindAuctionCreated(_auctionAddress, _nftId, _nftContract);
        }

        // move the NFT from the owner to the auction contract
        nftContractInstance.safeTransferFrom(
            msg.sender,
            _auctionAddress,
            _nftId
        );

        return _auctionAddress;
    }

    /**
		Initialize a new royalty or return the already initialized for a
		(contract, nft id) pair

		@param _nftId The unique identifier of the NFT that is being sold
        @param _nftContract The address of the contract of the NFT
		@param _royaltyPercent The 18 decimals percentage of the highest bid that will be sent to 
                the royalty receiver
        @param _royaltyReceiver The address of the royalty receiver for a given auction
        @param _royaltyInitializer The address that will be allowed to edit the royalties, if the
                null address is provided sender address will be used
     */
    function initializeRoyalty(
        uint256 _nftId,
        address _nftContract,
        uint256 _royaltyPercent,
        address _royaltyReceiver,
        address _royaltyInitializer
    ) private returns (Royalty memory) {
        prng.rotate();

        bytes32 royaltyIdentifier = keccak256(abi.encode(_nftContract, _nftId));

        // check if the royalty is already defined, in case it is this is not
        // the call to edit it, the user *must* use the correct call to edit it
        Royalty memory royalty = royalties[royaltyIdentifier];

        // if the royalty initializer is the null address then the royalty is not
        // yet initialized and can be initialized now
        if (royalty.royaltyInitializer == address(0)) {
            // Check that _royaltyPercent is less or equal to 50% of the sold amount
            require(
                _royaltyPercent <= 50 ether,
                "Royalty percentage too high, max value is 50%"
            );

            // if the royalty initializer is set to the null address automatically
            // use the caller address
            if (_royaltyInitializer == address(0)) {
                _royaltyInitializer = msg.sender;
            }

            royalties[royaltyIdentifier] = Royalty({
                decimals: 18,
                royaltyPercent: _royaltyPercent, // the provided value *MUST* be padded to 18 decimal positions
                royaltyReceiver: _royaltyReceiver,
                royaltyInitializer: _royaltyInitializer
            });

            emit RoyaltyUpdated(
                _nftId,
                _nftContract,
                _royaltyPercent,
                _royaltyReceiver,
                _royaltyInitializer
            );

            return royalties[royaltyIdentifier];
        }

        return royalty;
    }

    /**
        Create a public auction and if not initialized yet, init the royalty for the
        (smart contract address, nft identifier) pair

        NOTE: This method cannot be used to edit royalties values
        WARNING: Only ERC721 compliant NFTs can be sold, other standards are not supported

        @param _nftId The unique identifier of the NFT that is being sold
        @param _nftContract The address of the contract of the NFT
        @param _payee The address where the highest big will be credited
        @param _auctionDuration Number of seconds the auction will be valid
        @param _minimumPrice The minimum bid that must be placed in order for the auction to start.
                Bid lower than this amount are refused.
                If no bid is higher than this amount at the end of the auction the NFT will be sent
                to the beneficiary
        @param _royaltyPercent The 18 decimals percentage of the highest bid that will be sent to 
                the royalty receiver
        @param _royaltyReceiver The address of the royalty receiver for a given auction
        @param _royaltyInitializer The address that will be allowed to edit the royalties, if the
                null address is provided sender address will be used
     */
    function createAuction(
        uint256 _nftId,
        address _nftContract,
        address _payee,
        uint256 _auctionDuration,
        uint256 _minimumPrice,
        uint256 _royaltyPercent,
        address _royaltyReceiver,
        address _royaltyInitializer
    ) public nonReentrant onlyERC721(_nftContract) returns (address) {
        // load the instance of the nft contract into the ERC721 interface in order
        // to expose all its methods
        ERC721 nftContractInstance = ERC721(_nftContract);

        // check that the marketplace is allowed to transfer the provided nft
        // for the user
        // ALERT: checking the approval does not check that the user actually owns the nft
        // as parameters can per forged to pass this check without the caller to actually
        // own the it. This won"t be a problem in a standard context but as we"re setting
        // up the royalty base here a check must be done in order to check if it is should be
        // set by the caller or not
        require(
            nftContractInstance.getApproved(_nftId) == address(this),
            "Trasfer not allowed for Marketplace operator"
        );

        // check if the caller is the owner of the nft in case it is then proceed with further setup
        require(
            nftContractInstance.ownerOf(_nftId) == msg.sender,
            "Not owning the provided NFT"
        );

        Royalty memory royalty = initializeRoyalty(
            _nftId,
            _nftContract,
            _royaltyPercent,
            _royaltyReceiver,
            _royaltyInitializer
        );

        return
            _createAuction(
                _nftId,
                _nftContract,
                _payee,
                _auctionDuration,
                _minimumPrice,
                royalty.royaltyReceiver,
                royalty.royaltyPercent,
                false
            );
    }

    /**
        This call let the royalty initializer of a (smart contract, nft) pair
        edit the royalty settings.

        NOTE: The maximum royalty that can be taken is 50%
        WARNING: Only ERC721 compliant NFTs can be sold, other standards are not supported

		@param _nftId The unique identifier of the NFT that is being sold
		@param _nftContract The address of the contract of the NFT
		@param _royaltyPercent The 18 decimals percentage of the highest bid that will be sent to 
                the royalty receiver
		@param _royaltyReceiver The address of the royalty receiver for a given auction
		@param _royaltyInitializer The address that will be allowed to edit the royalties, if the
                null address is provided sender address will be used
     */
    function updateRoyalty(
        uint256 _nftId,
        address _nftContract,
        uint256 _royaltyPercent,
        address _royaltyReceiver,
        address _royaltyInitializer
    ) public nonReentrant onlyERC721(_nftContract) returns (Royalty memory) {
        bytes32 royaltyIdentifier = keccak256(abi.encode(_nftContract, _nftId));

        Royalty memory royalty = royalties[royaltyIdentifier];

        require(
            msg.sender == royalty.royaltyInitializer,
            "You're not the owner of the royalty"
        );

        // Check that _royaltyPercent is less or equal to 50% of the sold amount
        require(
            _royaltyPercent <= 50 ether,
            "Royalty percentage too high, max value is 50%"
        );

        // if the royalty initializer is set to the null address automatically
        // use the caller address
        if (_royaltyInitializer == address(0)) {
            _royaltyInitializer = msg.sender;
        }

        royalties[royaltyIdentifier] = Royalty({
            decimals: 18,
            royaltyPercent: _royaltyPercent, // the provided value *MUST* be padded to 18 decimal positions
            royaltyReceiver: _royaltyReceiver,
            royaltyInitializer: _royaltyInitializer
        });

        emit RoyaltyUpdated(
            _nftId,
            _nftContract,
            _royaltyPercent,
            _royaltyReceiver,
            _royaltyInitializer
        );

        return royalties[royaltyIdentifier];
    }

    function createBlindAuction(
        uint256 _nftId,
        address _nftContract,
        address _payee,
        uint256 _auctionDuration,
        uint256 _minimumPrice,
        uint256 _royaltyPercent,
        address _royaltyReceiver,
        address _royaltyInitializer
    ) public nonReentrant onlyERC721(_nftContract) returns (address) {
        // load the instance of the nft contract into the ERC721 interface in order
        // to expose all its methods
        ERC721 nftContractInstance = ERC721(_nftContract);

        // check that the marketplace is allowed to transfer the provided nft
        // for the user
        // ALERT: checking the approval does not check that the user actually owns the nft
        // as parameters can per forged to pass this check without the caller to actually
        // own the it. This won"t be a problem in a standard context but as we"re setting
        // up the royalty base here a check must be done in order to check if it is should be
        // set by the caller or not
        require(
            nftContractInstance.getApproved(_nftId) == address(this),
            "Trasfer not allowed for Marketplace operator"
        );

        // check if the caller is the owner of the nft in case it is then proceed with further setup
        require(
            nftContractInstance.ownerOf(_nftId) == msg.sender,
            "Not owning the provided NFT"
        );
        Royalty memory royalty = initializeRoyalty(
            _nftId,
            _nftContract,
            _royaltyPercent,
            _royaltyReceiver,
            _royaltyInitializer
        );

        return
            _createAuction(
                _nftId,
                _nftContract,
                _payee,
                _auctionDuration,
                _minimumPrice,
                royalty.royaltyReceiver,
                royalty.royaltyPercent,
                true
            );
    }
}