// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../verifiers/IForeVerifiers.sol";
import "./config/IProtocolConfig.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../token/IERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ForeProtocol is ERC721, ERC721Enumerable, ERC721Burnable, Ownable {
    using Strings for uint256;
    using SafeERC20 for IERC20Burnable;

    error MarketAlreadyExists();
    error FactoryIsNotWhitelisted();

    event BaseURI(string value);

    event MarketCreated(
        address indexed factory,
        address indexed creator,
        bytes32 marketHash,
        address market,
        uint256 marketIdx
    );

    event UpgradeTier(
        uint256 indexed oldTokenId,
        uint256 indexed newTokenId,
        uint256 newTier,
        uint256 verificationsNum
    );

    /// @notice ForeToken
    IERC20Burnable public immutable foreToken;

    /// @notice Protocol Config
    IProtocolConfig public immutable config;

    /// @notice ForeVerifiers
    IForeVerifiers public immutable foreVerifiers;

    /// @notice Market address for hash (ipfs hash without first 2 bytes)
    mapping(bytes32 => address) public market;

    /// @notice True if address is ForeMarket
    mapping(address => bool) public isForeMarket;

    /// @notice All markets array
    address[] public allMarkets;

    /// @dev base uri
    string internal bUri;

    /// @param cfg Protocol Config address
    /// @param uriBase Base Uri
    constructor(
        IProtocolConfig cfg,
        string memory uriBase
    ) ERC721("Fore Markets", "MFORE") {
        config = cfg;
        foreToken = IERC20Burnable(cfg.foreToken());
        foreVerifiers = IForeVerifiers(cfg.foreVerifiers());
        bUri = uriBase;
        emit BaseURI(uriBase);
    }

    /// @notice Returns base uri
    function _baseURI() internal view override returns (string memory) {
        return bUri;
    }

    function editBaseUri(string memory newBaseUri) external onlyOwner {
        bUri = newBaseUri;
        emit BaseURI(newBaseUri);
    }

    /// @notice Returns token uri for existing token
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(tokenId < allMarkets.length, "Non minted token");
        return string(abi.encodePacked(_baseURI(), tokenId.toString()));
    }

    /// @notice Returns true if Address is ForeOperator
    /// @dev ForeOperators: ForeMarkets(as factory), ForeMarket contracts and marketplace
    function isForeOperator(address addr) public view returns (bool) {
        return (addr != address(0) &&
            (addr == address(this) ||
                isForeMarket[addr] ||
                config.isFactoryWhitelisted(addr) ||
                addr == config.marketplace()));
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @dev Allow tokens to be used by market contracts
    function isApprovedForAll(
        address owner,
        address operator
    ) public view override(ERC721, IERC721) returns (bool) {
        if (isForeMarket[operator]) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    /// @notice Returns length of all markets array / nft height
    function allMarketLength() external view returns (uint256) {
        return allMarkets.length;
    }

    /// @notice Mints Verifier Nft (ForeVerifier)
    /// @param receiver receiver address
    function mintVerifier(address receiver) external {
        uint256 mintPrice = config.verifierMintPrice();
        foreToken.safeTransferFrom(
            msg.sender,
            address(foreVerifiers),
            mintPrice
        );
        foreVerifiers.mintWithPower(receiver, mintPrice, 0, 0);
    }

    /// @notice Upgrades tier for NFT
    /// @param id Token id ((ForeVerifier))
    function upgradeTier(uint256 id) external {
        uint256 actualTier = foreVerifiers.nftTier(id);
        uint256 verificationsDone = foreVerifiers.verificationsSum(id);
        uint256 power = foreVerifiers.powerOf(id);
        (uint256 verificationsRequirement, uint256 tierMultiplier) = config
            .getTier(actualTier + 1);
        require(
            tierMultiplier > 0,
            "ForeProtocol: Cant upgrade, next tier invalid"
        );
        address nftOwner = foreVerifiers.ownerOf(id);
        require(
            verificationsDone >= verificationsRequirement,
            "ForeProtocol: Cant upgrade"
        );
        foreVerifiers.burn(id);
        uint256 minted = foreVerifiers.mintWithPower(
            nftOwner,
            power,
            actualTier + 1,
            verificationsDone
        );
        emit UpgradeTier(id, minted, actualTier + 1, verificationsDone);
    }

    /// @notice Buys additional power (ForeVerifier)
    /// @param id token id
    /// @param amount amount to buy
    function buyPower(uint256 id, uint256 amount) external {
        require(
            foreVerifiers.powerOf(id) + amount <= config.verifierMintPrice(),
            "ForeFactory: Buy limit reached"
        );
        foreToken.safeTransferFrom(msg.sender, address(foreVerifiers), amount);
        foreVerifiers.increasePower(id, amount, false);
    }

    /// @notice Creates Market
    /// @param marketHash market hash
    /// @param receiver Receiver of market token
    /// @param marketAddress Created market address
    /// @return marketId Created market id
    function createMarket(
        bytes32 marketHash,
        address creator,
        address receiver,
        address marketAddress
    ) external returns (uint256 marketId) {
        if (market[marketHash] != address(0)) {
            revert MarketAlreadyExists();
        }

        if (!config.isFactoryWhitelisted(msg.sender)) {
            revert FactoryIsNotWhitelisted();
        }

        market[marketHash] = marketAddress;
        isForeMarket[marketAddress] = true;

        uint256 marketIdx = allMarkets.length;

        _safeMint(receiver, marketIdx);
        emit MarketCreated(
            msg.sender,
            creator,
            marketHash,
            marketAddress,
            marketIdx
        );

        allMarkets.push(marketAddress);

        return (marketIdx);
    }
}
