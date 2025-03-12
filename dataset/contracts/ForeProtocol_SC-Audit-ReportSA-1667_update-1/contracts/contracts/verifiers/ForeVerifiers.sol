// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../protocol/IForeProtocol.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../protocol/config/IProtocolConfig.sol";

contract ForeVerifiers is ERC721, ERC721Enumerable, ERC721Burnable, Ownable {
    using Strings for uint256;
    using SafeERC20 for IERC20Burnable;

    error ProtocolAlreadySet();
    error TokenNotExists();
    error OnlyProtocolAllowed();
    error OnlyOperatorAllowed();
    error NothingToWithdraw();
    error AmountExceedLimit(uint256 limit);
    error TransferAllowedOnlyForOperator();
    error NotAuthorized();

    event BaseURI(string value);
    event ProtocolChanged(address newAddress);
    event TransferAllowanceChanged(bool status);
    event TokenMinted(
        uint id,
        address to,
        uint power,
        uint tier,
        uint validationCount
    );
    event TokenPowerIncreased(uint id, uint powerDelta, uint newPower);
    event TokenPowerDecreased(uint id, uint powerDelta, uint newPower);
    event TokenValidationIncreased(uint id, uint newValidationCount);

    /// @notice Markets factory contract
    IForeProtocol public protocol;

    /// @dev Tokens counter
    uint256 internal _height;

    /// @notice Current token power (may be reduced / increased)
    mapping(uint256 => uint256) internal _power;

    /// @notice Inital power
    mapping(uint256 => uint256) internal _initialPower;

    /// @notice Transfers may be restricted to operators
    bool internal _transfersAllowed;

    /// @notice Number of verifications for token
    mapping(uint256 => uint256) public verificationsSum;

    /// @notice Tier of token
    mapping(uint256 => uint256) public nftTier;

    /// @dev base uri
    string internal bUri;

    // Modifier that will only allow valid markets
    modifier onlyMarket() {
        require(
            protocol.isForeMarket(msg.sender),
            "ForeVerifiers: Not a market"
        );
        _;
    }

    constructor(string memory uriBase) ERC721("ForeNFT", "FORE") {
        bUri = uriBase;
        emit BaseURI(uriBase);
    }

    /**
     * @notice Transfers may be restricted to operators
     */
    function transfersAllowed() external view returns (bool) {
        return _transfersAllowed;
    }

    /**
     * @notice Tokens counter
     */
    function height() external view returns (uint256) {
        return _height;
    }

    /**
     * @notice Returns current power of token
     */
    function powerOf(uint256 id) external view returns (uint256) {
        return _power[id];
    }

    /// @notice Returns multiplied power for foreVerifiers token
    /// @param id Token id
    function multipliedPowerOf(uint256 id) external view returns (uint256) {
        IProtocolConfig config = IProtocolConfig(protocol.config());
        uint256 multiplier = config.getTierMultiplier(nftTier[id]);
        return ((_power[id] * multiplier) / 10000);
    }

    /**
     * @notice Returns initial power of token
     */
    function initialPowerOf(uint256 id) external view returns (uint256) {
        return _initialPower[id];
    }

    /// @notice Returns base uri
    function _baseURI() internal view override returns (string memory) {
        return bUri;
    }

    function editBaseUri(string memory newBaseUri) external onlyOwner {
        bUri = newBaseUri;
        emit BaseURI(newBaseUri);
    }

    /**
     * @notice Changes factory contract
     * @param newAddress New protocol address
     */
    function setProtocol(address newAddress) external onlyOwner {
        require(
            newAddress != address(0),
            "ForeVerifiers: Procotol address cannot be zero"
        );
        protocol = IForeProtocol(newAddress);

        emit ProtocolChanged(newAddress);
    }

    /**
     * @notice Changes transferability feature
     * @param status Status
     */
    function setTransferAllowance(bool status) external onlyOwner {
        _transfersAllowed = status;

        emit TransferAllowanceChanged(status);
    }

    /**
     * @notice Mints token with defined power
     * @param to Recipient
     * @param power Power
     * @param tier Tier
     * @param validationNum Validation num
     */
    function mintWithPower(
        address to,
        uint256 power,
        uint256 tier,
        uint256 validationNum
    ) external returns (uint256) {
        if (address(protocol) != msg.sender) {
            revert OnlyProtocolAllowed();
        }
        uint256 h = _height;

        _power[h] = power;
        _initialPower[h] = power;
        verificationsSum[h] = validationNum;
        nftTier[h] = tier;

        _safeMint(to, h);

        _height++;
        emit TokenMinted(h, to, power, tier, validationNum);
        return (h);
    }

    function increaseValidation(uint256 id) external {
        if (!_exists(id)) {
            revert TokenNotExists();
        }

        if (!protocol.isForeOperator(msg.sender)) {
            revert OnlyOperatorAllowed();
        }

        verificationsSum[id]++;
        emit TokenValidationIncreased(id, verificationsSum[id]);
    }

    /**
     * @notice Increase token power
     * @param id Token Id
     * @param powerDelta Power delta
     *  @param increaseValidationNum Increases validation num for token
     */
    function increasePower(
        uint256 id,
        uint256 powerDelta,
        bool increaseValidationNum
    ) external {
        if (!_exists(id)) {
            revert TokenNotExists();
        }

        if (!protocol.isForeOperator(msg.sender)) {
            revert OnlyOperatorAllowed();
        }

        if (increaseValidationNum) {
            verificationsSum[id]++;
            emit TokenValidationIncreased(id, verificationsSum[id]);
        }

        _power[id] += powerDelta;

        emit TokenPowerIncreased(id, powerDelta, _power[id]);
    }

    /**
     * @notice Decrease token power (f.e. penalty)
     * @param id Token Id
     * @param powerDelta Power delta
     */
    function decreasePower(uint256 id, uint256 powerDelta) external {
        if (!_exists(id)) {
            revert TokenNotExists();
        }
        if (powerDelta == 0) {
            revert NothingToWithdraw();
        }

        uint256 currentPower = _power[id];

        // limit withdraw value
        uint256 maxAmount = 0;

        if (protocol.isForeMarket(msg.sender)) {
            // market can ultimately reduce power
            maxAmount = currentPower;
        } else if (ownerOf(id) == msg.sender) {
            // user can withdraw only value larger than initial power
            maxAmount = currentPower > _initialPower[id]
                ? currentPower - _initialPower[id]
                : 0;
        } else {
            // different user can't withdraw
            revert NotAuthorized();
        }

        if (powerDelta > maxAmount) {
            revert AmountExceedLimit(maxAmount);
        }

        currentPower -= powerDelta;
        _power[id] = currentPower;

        if (currentPower == 0) {
            _burn(id);
        }

        IERC20Burnable foreToken = IERC20Burnable(protocol.foreToken());
        foreToken.safeTransfer(msg.sender, powerDelta);

        emit TokenPowerDecreased(id, powerDelta, _power[id]);
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

    /**
     * @inheritdoc ERC721
     * @dev It is always allowed for Fore operator
     */
    function isApprovedForAll(
        address owner,
        address operator
    ) public view override(ERC721, IERC721) returns (bool) {
        if (protocol.isForeOperator(operator)) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @inheritdoc ERC721
     * @dev In case transfers are disabled only Fore operator is allowed to transfer from or transfer to
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        if (!_transfersAllowed) {
            if (
                !protocol.isForeOperator(to) && !protocol.isForeOperator(from)
            ) {
                revert TransferAllowedOnlyForOperator();
            }
        }

        super._transfer(from, to, tokenId);
    }

    /**
     * @inheritdoc ERC721
     */
    function _burn(uint256 tokenId) internal virtual override {
        _power[tokenId] = 0;
        super._burn(tokenId);
    }

    /**
     * @notice Allows a market to transfer FORE that are inside the verifier nft
     * @param to Receiver address
     * @param amount Amount of FORE to be transfered
     * @dev Only allowed for a market to call this function
     */
    function marketTransfer(address to, uint256 amount) public onlyMarket {
        IERC20Burnable foreToken = IERC20Burnable(protocol.foreToken());
        foreToken.safeTransfer(to, amount);
    }

    /**
     * @notice Allows a market to burn FORE that are inside the verifier nft
     * @param amount Amount of FORE to be burned
     * @dev Only allowed for a market to call this function
     */
    function marketBurn(uint256 amount) public onlyMarket {
        IERC20Burnable foreToken = IERC20Burnable(protocol.foreToken());
        foreToken.burn(amount);
    }
}

interface IERC20Burnable is IERC20 {
    function burnFrom(address account, uint256 amount) external;

    function burn(uint256 amount) external;
}
