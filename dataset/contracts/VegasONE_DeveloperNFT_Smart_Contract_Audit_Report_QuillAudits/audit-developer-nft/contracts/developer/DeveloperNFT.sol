// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {ERC721AStorageCustom} from "./ERC721AStorageCustom.sol";
import "./ERC721AQueryableUpgradeableCustom.sol";
import "./AccessControlUpgradeableCustom.sol";
import "./ERC721URIStorageUpgradeable.sol";
import "./PeriodUpgradeable.sol";

contract DeveloperNFT is
    ERC721AQueryableUpgradeableCustom,
    ERC721URIStorageUpgradeable,
    EIP712Upgradeable,
    PausableUpgradeable,
    PeriodUpgradeable,
    AccessControlUpgradeableCustom,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using ERC721AStorageCustom for ERC721AStorageCustom.Layout;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;

    /**
     * Global Variables
     */

    bytes32 private constant _CHECKTOKEN_TYPEHASH =
        keccak256(
            "CheckToken(string uuid,address userAddress,uint256 deadline,uint256 level,string uri)"
        );

    /**
     * Events
     */

    event SetLevel(uint256 levelVersion, ERC721AStorageCustom.Level[] levels);
    event SetTokenSupply(uint256 level, uint256 tokenSupply);
    event SwitchMintable(uint256 level, bool mintable);
    event SetSignerAddress(address signerAddress);
    event Withdraw(address token, address indexed to, uint256 amount);
    event SetPeriodTokenSupply(uint256 periodTokenSupply);
    event StartPeriod(uint256 curPeriod, uint256 periodTokenSupply);
    event EndPeriod(uint256 curPeriod);

    /**
     * Errors
     */

    error InValidSignerAddress();
    error InValidPaymentContract();
    error LevelLengthInValid();
    error PriceTooLow();
    error maxAgentAmountTooLow();
    error LevelLengthTooLow();
    error ErrLevelNotExist();
    error ErrNewSupplyMustBeGreater();
    error ErrUnMintable();
    error ExceedPeriodTokenSupply();
    error ExceedLevelTokenSupply();
    error PeriodTokenSupplyTooLow();
    error PrevPeriodTokenLeft();
    error ExceedMaximumTokenSupply();
    error ExpiredDeadline();
    error UsedUUID();
    error InvalidUserAddress();

    /**
     * Initialize
     */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory newName,
        string memory newSymbol,
        address newSignerAddress,
        address newPaymentContract,
        ERC721AStorageCustom.Level[] calldata newLevel,
        uint256[] calldata newTokenSupply,
        address newAdmin,
        address[] calldata newWorkers
    ) public initializerERC721A initializer {
        __ERC721A_init(newName, newSymbol);
        __ERC721AQueryable_init();
        __ERC721URIStorage_init();
        __EIP712_init(newName, "1");
        __Pausable_init();
        __DuringPeriod_init();
        __AccessControlCustom_init(newAdmin, newWorkers);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        ERC721AStorageCustom.Layout storage data = ERC721AStorageCustom
            .layout();

        if (newSignerAddress == address(0) || newSignerAddress.isContract()) {
            revert InValidSignerAddress();
        }

        if (
            newPaymentContract == address(0) || !newPaymentContract.isContract()
        ) {
            revert InValidPaymentContract();
        }

        if (newLevel.length < 1 || newLevel.length != newTokenSupply.length) {
            revert LevelLengthInValid();
        }

        data._levelVersion += 1;

        // to set level 0
        for (uint8 i = 0; i < newLevel.length; i++) {
            if (newLevel[i].price == 0) {
                revert PriceTooLow();
            }
            if (newLevel[i].maxAgentAmount == 0) {
                revert maxAgentAmountTooLow();
            }
            data._levels[data._levelVersion].push(newLevel[i]);
            data._levelTokenSupply[i] = newTokenSupply[i];
            data._sumOfLevelTokenSupply += newTokenSupply[i];
        }

        data._paymentContract = newPaymentContract;
        data._signerAddress = newSignerAddress;
    }

    /**
     * View Functions
     */

    /**
     * @dev return sum of all periods NFT supply
     */
    function sumOfPeriodTokenSupply() external view returns (uint256) {
        return ERC721AStorageCustom.layout()._sumOfPeriodTokenSupply;
    }

    /**
     * @dev return number of sold tokens by level
     */
    function soldTokenAmount(uint256 levelNum) external view returns (uint256) {
        return ERC721AStorageCustom.layout()._soldTokenAmount[levelNum - 1];
    }

    /**
     * @dev return NFT supply of current period
     */
    function periodTokenSupply() external view returns (uint256) {
        return ERC721AStorageCustom.layout()._periodTokenSupply;
    }

    /**
     * @dev return address who can sign for mint
     */
    function signerAddress() external view returns (address) {
        return ERC721AStorageCustom.layout()._signerAddress;
    }

    /**
     * @dev return ERC20 which is payment token for buying NFT
     */
    function paymentContract() external view returns (address) {
        return ERC721AStorageCustom.layout()._paymentContract;
    }

    /**
     * @dev return current level version
     */
    function levelVersion() external view returns (uint256) {
        return ERC721AStorageCustom.layout()._levelVersion;
    }

    /**
     * @dev return level details of specific version
     */
    function levels(
        uint256 version
    ) external view returns (ERC721AStorageCustom.Level[] memory) {
        return ERC721AStorageCustom.layout()._levels[version];
    }

    /**
     * @dev return currently level details
     */
    function currentLevel()
        external
        view
        returns (ERC721AStorageCustom.Level[] memory)
    {
        return
            ERC721AStorageCustom.layout()._levels[
                ERC721AStorageCustom.layout()._levelVersion
            ];
    }

    /**
     * @dev return level is mintable or not
     */
    function mintable(uint256 level) external view returns (bool) {
        return ERC721AStorageCustom.layout()._mintable[level - 1];
    }

    /**
     * @dev return NFT supply of specific level
     */
    function levelTokenSupply(uint256 level) external view returns (uint256) {
        return ERC721AStorageCustom.layout()._levelTokenSupply[level - 1];
    }

    /**
     * @dev return sum of all levels' NFT supply
     */
    function sumOfLevelTokenSupply() external view returns (uint256) {
        return ERC721AStorageCustom.layout()._sumOfLevelTokenSupply;
    }

    /**
     * @dev return the level info of specific token
     */
    function levelOfToken(
        uint256 tokenId
    ) public view returns (ERC721AStorageCustom.Level memory) {
        ERC721AStorageCustom.Token memory token = ERC721AStorageCustom
            .layout()
            ._tokenLevel[tokenId];
        return
            ERC721AStorageCustom.layout()._levels[token.levelVersion][
                token.level
            ];
    }

    /**
     * @dev return the total amount of tokens minted in this contract
     */
    function totalMinted() external view returns (uint256) {
        return _totalMinted();
    }

    /**
     * @dev return the total amount of tokens minted in current period
     */
    function periodMinted() public view returns (uint256) {
        return
            _totalMinted() -
            (ERC721AStorageCustom.layout()._sumOfPeriodTokenSupply -
                ERC721AStorageCustom.layout()._periodTokenSupply);
    }

    /**
     * @dev return the total list of owner by page which is start from 1
     */
    function tokenListOfOwner(
        address owner,
        uint256 page,
        uint256 pageSize
    ) external view returns (ERC721AStorageCustom.TokenWithLevel[] memory) {
        uint256 startIndex = (page - 1) * pageSize;
        uint256 endIndex = page * pageSize;
        uint256[] memory tokenIds = tokensOfOwner(owner);
        if (startIndex >= tokenIds.length) {
            return new ERC721AStorageCustom.TokenWithLevel[](0);
        }
        if (tokenIds.length < endIndex) {
            endIndex = tokenIds.length;
        }

        ERC721AStorageCustom.TokenWithLevel[]
            memory res = new ERC721AStorageCustom.TokenWithLevel[](
                endIndex - startIndex
            );
        for (uint256 i = startIndex; i < endIndex; i++) {
            ERC721AStorageCustom.Token memory token = ERC721AStorageCustom
                .layout()
                ._tokenLevel[tokenIds[i]];
            res[i - startIndex] = ERC721AStorageCustom.TokenWithLevel({
                tokenId: tokenIds[i],
                levelNum: token.level + 1,
                level: levelOfToken(tokenIds[i])
            });
        }
        return res;
    }

    /**
     * @dev return the total list of tokens by page which is start from 1
     */
    function tokenListOfAll(
        uint256 page,
        uint256 pageSize
    ) external view returns (ERC721AStorageCustom.TokenWithLevel[] memory) {
        uint256 startIndex = (page - 1) * pageSize;
        uint256 endIndex = page * pageSize;
        uint256 cur = ERC721AStorage.layout()._currentIndex;

        if (startIndex >= cur) {
            return new ERC721AStorageCustom.TokenWithLevel[](0);
        }
        if (cur < endIndex) {
            endIndex = cur;
        }

        ERC721AStorageCustom.TokenWithLevel[]
            memory res = new ERC721AStorageCustom.TokenWithLevel[](
                endIndex - startIndex
            );
        for (uint256 i = startIndex; i < endIndex; i++) {
            ERC721AStorageCustom.Token memory token = ERC721AStorageCustom
                .layout()
                ._tokenLevel[i];
            res[i - startIndex] = ERC721AStorageCustom.TokenWithLevel({
                tokenId: i,
                levelNum: token.level + 1,
                level: levelOfToken(i)
            });
        }
        return res;
    }

    /**
     * Player Functions
     */

    /**
     * @dev mint 1 NFT with signature signed by signerAddress
     * @param uuid - the uuid offered by signerAddress(backend)
     * @param userAddress - the address which wants to mint token
     * @param deadline - this signature's expiration time
     * @param level - the level of NFT
     * @param uri - the uri of NFT
     * @param signature - the signature which sign by signerAddress(backend)
     */
    function checkTokenAndMint(
        string calldata uuid,
        address userAddress,
        uint256 deadline,
        uint256 level,
        string calldata uri,
        bytes memory signature
    ) external nonReentrant {
        _checkToken(uuid, userAddress, deadline, level, uri, signature);
        uint256 amount = _mint(1, level, uri);
        IERC20Upgradeable(ERC721AStorageCustom.layout()._paymentContract)
            .safeTransferFrom(_msgSender(), address(this), amount);
    }

    /**
     * Admin Functions
     */

    /**
     * @dev Admin changes the level setting
     * @param newLevel - new level
     * @notice - Only admin can call this function while not in period.
     */
    function setLevel(
        ERC721AStorageCustom.Level[] calldata newLevel
    ) external onlyRole(WORKER_ROLE) whenNotInPeriod {
        ERC721AStorageCustom.Layout storage data = ERC721AStorageCustom
            .layout();

        // level length cannot small than one
        // also, the new level length cannot smaller than the previous version
        if (
            newLevel.length < 1 ||
            newLevel.length < data._levels[data._levelVersion].length
        ) {
            revert LevelLengthTooLow();
        }

        data._levelVersion += 1;

        for (uint8 i = 0; i < newLevel.length; i++) {
            if (newLevel[i].price == 0) {
                revert PriceTooLow();
            }
            if (newLevel[i].maxAgentAmount == 0) {
                revert maxAgentAmountTooLow();
            }
            data._levels[data._levelVersion].push(newLevel[i]);
        }

        emit SetLevel(data._levelVersion, newLevel);
    }

    /**
     * @dev Admin can change the token supply of each level
     * @param level - the level which is going to be changed
     * @param newLevelTokenSupply - new token supply of the level
     * @notice - Only admin can call this function.
     */
    function setTokenSupply(
        uint256 level,
        uint256 newLevelTokenSupply
    ) external onlyRole(WORKER_ROLE) {
        ERC721AStorageCustom.Layout storage data = ERC721AStorageCustom
            .layout();
        // if the level is not exist, cannot set up token supply
        if (data._levels[data._levelVersion].length < level) {
            revert ErrLevelNotExist();
        }

        if (data._levelTokenSupply[level - 1] >= newLevelTokenSupply) {
            revert ErrNewSupplyMustBeGreater();
        }

        data._sumOfLevelTokenSupply =
            data._sumOfLevelTokenSupply -
            data._levelTokenSupply[level - 1] +
            newLevelTokenSupply;
        data._levelTokenSupply[level - 1] = newLevelTokenSupply;

        emit SetTokenSupply(level, newLevelTokenSupply);
    }

    /**
     * @dev Admin can switch mintable status of specific level
     * @param level - the level which is going to be switched
     * @notice - Only admin can call this function.
     */
    function switchMintable(uint256 level) external onlyRole(WORKER_ROLE) {
        ERC721AStorageCustom.Layout storage data = ERC721AStorageCustom
            .layout();
        // if the level is not exist, cannot switch mintable status
        if (data._levels[data._levelVersion].length < level) {
            revert ErrLevelNotExist();
        }

        data._mintable[level - 1] = !data._mintable[level - 1];

        emit SwitchMintable(level, data._mintable[level - 1]);
    }

    /**
     * @dev Admin can change the signerAddress
     * @param newSignerAddress - the new signer's address
     * @notice - Only admin can call this function.
     */
    function setSignerAddress(
        address newSignerAddress
    ) external onlyRole(WORKER_ROLE) {
        if (newSignerAddress == address(0)) {
            revert InValidSignerAddress();
        }
        ERC721AStorageCustom.layout()._signerAddress = newSignerAddress;
        emit SetSignerAddress(newSignerAddress);
    }

    /**
     * @dev Admin can batch mint NFT
     * @param level - the level of NFT
     * @param uri - the uri of NFT
     * @notice - Only admin can call this function.
     */
    function batchMint(
        uint256 quantity,
        uint256 level,
        string calldata uri
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        _mint(quantity, level, uri);
    }

    /**
     * @dev Admin can withdraw ERC20 from this contract
     * @param token - the token of withdrawal
     * @param to - the address that token transfer to
     * @param amount - the amount of withdrawal
     * @notice - Only admin can call this function.
     */
    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit Withdraw(token, to, amount);
        IERC20Upgradeable(token).safeTransfer(to, amount);
    }

    /**
     * @dev Admin triggers stopped state
     * @notice - Only admin can call this function.
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Admin returns to normal state.
     * @notice - Only admin can call this function.
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Admin starts a new round of sale
     * @param newPeriodTokenSupply - the token supply of next period
     * @notice - Only admin can call this function while not in period.
     */
    function startPeriod(
        uint256 newPeriodTokenSupply
    ) external onlyRole(WORKER_ROLE) whenNotInPeriod {
        _setPeriodTokenSupply(newPeriodTokenSupply);
        _startPeriod();
        emit StartPeriod(currentPeriod(), newPeriodTokenSupply);
    }

    /**
     * @dev Admin end the current period
     * @notice - Only admin can call this function while in period.
     */
    function endPeriod() external onlyRole(WORKER_ROLE) whenInPeriod {
        _endPeriod();
        emit EndPeriod(currentPeriod());
    }

    /**
     * Internal Functions
     */

    /**
     * @dev set up the NFT supply of next period
     * @param newPeriodTokenSupply - the token supply of next period
     */
    function _setPeriodTokenSupply(uint256 newPeriodTokenSupply) internal {
        ERC721AStorageCustom.Layout storage data = ERC721AStorageCustom
            .layout();
        if (newPeriodTokenSupply == 0) {
            revert PeriodTokenSupplyTooLow();
        }

        if (periodMinted() != data._periodTokenSupply) {
            revert PrevPeriodTokenLeft();
        }

        if (
            data._sumOfPeriodTokenSupply + newPeriodTokenSupply >
            data._sumOfLevelTokenSupply
        ) {
            revert ExceedMaximumTokenSupply();
        }

        data._periodTokenSupply = newPeriodTokenSupply;
        data._sumOfPeriodTokenSupply += newPeriodTokenSupply;
        emit SetPeriodTokenSupply(newPeriodTokenSupply);
    }

    /**
     * @dev check the signature is sign by signerAddress
     * @param uuid - the uuid offered by signerAddress(backend)
     * @param userAddress - the address which wants to mint token
     * @param deadline - this signature's expiration time
     * @param level - the level of NFT
     * @param uri - the uri of NFT
     * @param signature - the signature which sign by signerAddress(backend)
     */
    function _checkToken(
        string calldata uuid,
        address userAddress,
        uint256 deadline,
        uint256 level,
        string calldata uri,
        bytes memory signature
    ) internal {
        ERC721AStorageCustom.Layout storage data = ERC721AStorageCustom
            .layout();
        if (block.timestamp > deadline) {
            revert ExpiredDeadline();
        }
        if (data._usedUUID[uuid]) {
            revert UsedUUID();
        }
        if (userAddress != _msgSender()) {
            revert InvalidUserAddress();
        }

        bytes32 structHash = keccak256(
            abi.encode(
                _CHECKTOKEN_TYPEHASH,
                keccak256(bytes(uuid)),
                userAddress,
                deadline,
                level,
                keccak256(bytes(uri))
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSAUpgradeable.recover(hash, signature);
        if (signer != data._signerAddress) {
            revert InValidSignerAddress();
        }
        data._usedUUID[uuid] = true;
    }

    /**
     * @dev mint NFT to msgSender
     * @param quantity - the amounts of NFT which are going to be minted
     * @param level - the level of NFT
     * @param uri - the uri of NFT
     */
    function _mint(
        uint256 quantity,
        uint256 level,
        string calldata uri
    ) internal returns (uint256) {
        ERC721AStorageCustom.Layout storage data = ERC721AStorageCustom
            .layout();
        uint256 cur = ERC721AStorage.layout()._currentIndex;

        if (!data._mintable[level - 1]) {
            revert ErrUnMintable();
        }

        if (cur + quantity > data._sumOfPeriodTokenSupply) {
            revert ExceedPeriodTokenSupply();
        }

        if (
            data._soldTokenAmount[level - 1] + quantity >
            data._levelTokenSupply[level - 1]
        ) {
            revert ExceedLevelTokenSupply();
        }

        data._soldTokenAmount[level - 1] += quantity;

        // _safeMint's second argument now takes in a quantity, not a tokenId.
        _safeMint(_msgSender(), quantity);
        for (uint256 i = cur; i < cur + quantity; i++) {
            _setTokenURI(i, uri);
            data._tokenLevel[i] = ERC721AStorageCustom.Token({
                level: level - 1,
                levelVersion: data._levelVersion
            });
        }

        return data._levels[data._levelVersion][level - 1].price * quantity;
    }

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal override whenNotPaused {
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(WORKER_ROLE) {}

    // The following functions are overrides required by Solidity.
    function _burn(
        uint256 tokenId
    ) internal override(ERC721AUpgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721AUpgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721AUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
