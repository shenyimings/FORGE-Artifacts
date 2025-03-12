// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import "../citizenid/CitizenIDV1.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";

/// @title NomadicYeti NFT contract
/// @author Tevaera Labs
/// @notice Allows users to mint the guardian NFT of NomadicYeti
/// @dev It extends ERC721 and ERC2981 standards
contract NomadicYetiV1 is
    ERC721RoyaltyUpgradeable,
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    CitizenIDV1 private citizenIdContract;

    modifier isNotBlacklisted() {
        require(
            !citizenIdContract.blacklisted(msg.sender),
            "Tevan Blacklisted!"
        );
        _;
    }

    modifier isTevan() {
        require(citizenIdContract.balanceOf(msg.sender) > 0, "Not a Tevan");
        _;
    }

    address payable public charityAddress;
    uint16 public charityBps = 500; // default to 5%

    uint256 public constant MAX_YETIS = 10000;
    uint256 public constant YETI_PRICE = 30000000000000000; //0.03 ETH

    address payable private safeAddress;

    mapping(address => bool) private addressToHasMintedMap;
    mapping(uint256 => uint256) private availableTokens;
    uint256 private randomNonce = 0;
    uint256 private numAvailableTokens;
    string private tokenBaseUri;

    /// @dev Initializes the upgradable contract
    /// @param _safeAddress the safe address
    /// @param _charityAddress the charity address
    /// @param _citizenIdContract the citizen id contract address
    function initialize(
        address payable _safeAddress,
        address payable _charityAddress,
        CitizenIDV1 _citizenIdContract,
        string calldata _tokenBaseUri
    ) external initializer {
        __ERC721_init("NomadicYeti", "YETI");
        __ERC721Enumerable_init();
        __ERC721Royalty_init();
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        safeAddress = _safeAddress;
        charityAddress = _charityAddress;
        citizenIdContract = _citizenIdContract;
        tokenBaseUri = _tokenBaseUri;

        // set default royalty to 5%
        _setDefaultRoyalty(msg.sender, 500);

        // set random nonce starting index
        randomNonce = uint256(
            keccak256(
                abi.encodePacked(
                    keccak256(
                        abi.encode(
                            tx.gasprice,
                            block.number,
                            block.timestamp,
                            block.prevrandao,
                            blockhash(block.number - 1),
                            address(this)
                        )
                    )
                )
            )
        );

        numAvailableTokens = MAX_YETIS;
    }

    /// @dev Mints Guardian NFT
    function mint()
        external
        payable
        isTevan
        isNotBlacklisted
        whenNotPaused
        nonReentrant
    {
        // make sure caller has not already minted
        require(addressToHasMintedMap[msg.sender] == false, "already minted");

        // make sure yetis are not sold out
        require(totalSupply() + 1 <= MAX_YETIS, "sold out");

        // make sure caller is paying the right value
        require(msg.value == YETI_PRICE, "invalid amount");

        // get the random token id
        uint256 tokenId = getRandomAvailableTokenId(msg.sender, randomNonce);

        // mint the guardian nft
        _mint(msg.sender, tokenId);

        // mark address as minted
        addressToHasMintedMap[msg.sender] = true;

        // increase the nonce
        randomNonce++;

        // reduce the available token count
        --numAvailableTokens;
    }

    /// @dev Allows owner to withdraw funds. Specified percentage goes to charity by default
    function withdrawFunds() external onlyOwner {
        uint256 availableBalance = address(this).balance;
        uint256 charityAmount = 0;

        if (charityBps > 0) {
            // make sure charity address is configured
            require(charityAddress != address(0), "Missing charity address!");

            // calculate the charity amount
            charityAmount = (availableBalance / 10000) * charityBps;

            // transfer charity funds to charity address
            (bool charityTxSuccess, ) = payable(charityAddress).call{
                value: (charityAmount)
            }("");
            // make sure the transaction was successful
            require(charityTxSuccess, "Transfer to charity address failed.");
        }

        // make sure safe address is configured
        require(safeAddress != address(0), "Missing safe address!");

        uint256 amountAfterCharity = availableBalance - charityAmount;
        (bool safeTxSuccess, ) = payable(safeAddress).call{
            value: (amountAfterCharity)
        }("");
        require(safeTxSuccess, "Transfer to safe address failed.");
    }

    /// @dev Allows owner to update charity address and charity share in basis points
    /// @param _charity a charity wallet address
    /// @param _charityBps a charity share in percentage (basis points) i.e. 100 for 1%
    function updateCharityConfig(
        address payable _charity,
        uint16 _charityBps
    ) external onlyOwner whenNotPaused {
        require(charityAddress != address(0), "Invalid address!");
        charityAddress = _charity;
        charityBps = _charityBps;
    }

    /// @dev Allows owner to update the safe address
    /// @param _safeAddress a safe wallet address
    function updateSafeAddress(
        address payable _safeAddress
    ) external onlyOwner whenNotPaused {
        require(_safeAddress != address(0), "Invalid address!");
        safeAddress = _safeAddress;
    }

    /// @dev Sets the token base uri
    /// @param _tokenBaseUri the token base uri
    function setTokenBaseUri(
        string calldata _tokenBaseUri
    ) external onlyOwner whenNotPaused {
        tokenBaseUri = _tokenBaseUri;
    }

    // ----- system default functions -----

    /// @dev Allows owner to pause sale if active
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /// @dev Allows owner to acticvate sale
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    function getRandomAvailableTokenId(
        address to,
        uint256 nonce
    ) internal returns (uint256) {
        uint256 randomNum = uint256(
            keccak256(
                abi.encodePacked(
                    keccak256(
                        abi.encode(
                            to,
                            nonce,
                            tx.gasprice,
                            block.number,
                            block.timestamp,
                            block.prevrandao,
                            blockhash(block.number - 1),
                            address(this)
                        )
                    )
                )
            )
        ) % numAvailableTokens;

        return getAvailableTokenAtIndex(randomNum);
    }

    function getAvailableTokenAtIndex(
        uint256 indexToUse
    ) internal returns (uint256) {
        uint256 valAtIndex = availableTokens[indexToUse];
        uint256 result;
        if (valAtIndex == 0) {
            // This means the index itself is still an available token
            result = indexToUse;
        } else {
            // This means the index itself is not an available token, but the val at that index is.
            result = valAtIndex;
        }

        uint256 lastIndex = numAvailableTokens - 1;
        uint256 lastValInArray = availableTokens[lastIndex];
        if (indexToUse != lastIndex) {
            // Replace the value at indexToUse, now that it's been used.
            // Replace it with the data from the last index in the array, since we are going to decrease the array size afterwards.
            if (lastValInArray == 0) {
                // This means the index itself is still an available token
                availableTokens[indexToUse] = lastIndex;
            } else {
                // This means the index itself is not an available token, but the val at that index is.
                availableTokens[indexToUse] = lastValInArray;
            }
        }
        if (lastValInArray != 0) {
            // Gas refund courtsey of @dievardump
            delete availableTokens[lastIndex];
        }

        return result;
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721RoyaltyUpgradeable) {
        super._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _baseURI()
        internal
        view
        override(ERC721Upgradeable)
        returns (string memory)
    {
        return tokenBaseUri;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721Upgradeable) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721EnumerableUpgradeable, ERC721RoyaltyUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
