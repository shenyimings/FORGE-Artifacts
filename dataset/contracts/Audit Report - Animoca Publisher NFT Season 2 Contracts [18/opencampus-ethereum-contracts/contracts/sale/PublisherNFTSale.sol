// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {IERC1155} from "@animoca/ethereum-contracts/contracts/token/ERC1155/interfaces/IERC1155.sol";
import {ILayerZeroEndpoint} from "@layerzerolabs/solidity-examples/contracts/interfaces/ILayerZeroEndpoint.sol";
import {ContractOwnershipStorage} from "@animoca/ethereum-contracts/contracts/access/libraries/ContractOwnershipStorage.sol";
import {ContractOwnership} from "@animoca/ethereum-contracts/contracts/access/ContractOwnership.sol";
import {EDUCreditsManager} from "./../payment/EDUCreditsManager.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ForwarderRegistryContextBase} from "@animoca/ethereum-contracts/contracts/metatx/base/ForwarderRegistryContextBase.sol";
import {ForwarderRegistryContext} from "@animoca/ethereum-contracts/contracts/metatx/ForwarderRegistryContext.sol";

/// @title PublisherNFTSale
/// @notice Sale contract to be deployed on BSC for the OpenCampus Publisher NFT season 2.
/// @notice On a succesful mint, the contract will send a LayerZero message to a minter contract on Polygon where the minting will take place.
contract PublisherNFTSale is ContractOwnership, ForwarderRegistryContext {
    using ContractOwnershipStorage for ContractOwnershipStorage.Layout;

    uint256 public constant MINT_LIMIT_PER_TX = 10;

    IERC1155 public immutable GENESIS_TOKEN;
    EDUCreditsManager public immutable EDU_CREDITS_MANAGER;

    ILayerZeroEndpoint public immutable LZ_ENDPOINT;
    uint16 public immutable LZ_DST_CHAINID;

    uint256 public immutable MINT_PRICE;
    uint256 public immutable MINT_SUPPLY_LIMIT;
    uint256 public immutable MINT_LIMIT_PER_ADDRESS;

    uint256 public immutable PHASE1_START_TIMESTAMP;
    uint256 public immutable PHASE2_START_TIMESTAMP;
    uint256 public immutable PHASE3_START_TIMESTAMP;
    uint256 public immutable SALE_END_TIMESTAMP;

    uint256 public immutable DISCOUNT_THRESHOLD_1;
    uint256 public immutable DISCOUNT_THRESHOLD_2;
    uint256 public immutable DISCOUNT_THRESHOLD_3;

    uint256 public immutable DISCOUNT_PERCENTAGE_1;
    uint256 public immutable DISCOUNT_PERCENTAGE_2;
    uint256 public immutable DISCOUNT_PERCENTAGE_3;

    address public lzDstAddress;
    uint256 public mintCount;
    mapping(address => uint256) public mintCountPerAddress;

    /// @notice Emitted when a mint is initiated.
    /// @param sender The sender of the mint.
    /// @param nbTokens The number of tokens to mint.
    /// @param discountThreshold The discount threshold that was reached at the moment of the mint.
    event MintInitiated(address sender, uint256 nbTokens, uint256 discountThreshold);

    /// @notice Thrown at construction if the timestamps are not in increasing order.
    error InvalidTimestamps();

    /// @notice Thrown at construction if the discount thresholds are not in increasing order.
    error InvalidDiscountThresholds();

    /// @notice Thrown at construction if the discount percentages are not in increasing order.
    error InvalidDiscountPercentages();

    /// @notice Thrown when trying to set the LZ destination address but it is already set.
    error LzDstAddressAlreadySet();

    /// @notice Thrown when trying to mint zero tokens.
    error MintingZeroTokens();

    /// @notice Thrown when trying to mint more than the limit of tokens per address.
    error MintingTooManyTokens();

    /// @notice Thrown when trying to mint but the sender mint limit is overflowing.
    error AddressMintingLimitReached();

    /// @notice Thrown when trying to mint but the sale has not started yet.
    error SaleNotStarted();

    /// @notice Thrown when trying to mint during phase 1 but the sender is not a diamond hand.
    error NotADiamondHand();

    /// @notice Thrown when trying to mint during phase 2 but the sender is not a diamond hand nor a genesis NFT owner.
    error NotADiamondHandNorAGenesisNFTOwner();

    /// @notice Thrown when trying to mint but the sale has ended.
    error SaleEnded();

    /// @notice Thrown when trying to mint but the LZ destination address is not set.
    error LzDstAddressNotSet();

    /// @notice Thrown when trying to mint but the mint supply limit has been reached.
    error InsufficientMintSupply();

    /// @dev Reverts with `InvalidTimestamps` if the timestamps are not in increasing order.
    /// @dev Reverts with `InvalidDiscountThresholds` if the discount thresholds are not in increasing order.
    /// @dev Reverts with `InvalidDiscountPercentages` if the discount percentages are not in increasing order.
    /// @param genesisToken The address of the Genesis Token contract.
    /// @param eduCreditsManager The address of the EDUCreditsManager contract.
    /// @param lzEndpoint The address of the LayerZeroEndpoint contract.
    /// @param lzDstChainId The destination chain identifier for LayerZeroEndpoint.
    /// @param mintPrice The price of a mint.
    /// @param mintSupplyLimit The maximum number of tokens that can be minted.
    /// @param timestamps The timestamps of the sale phases.
    /// @param discountThresholds The discount thresholds of the sale phases.
    /// @param discountPercentages The discount percentages of the sale phases.
    /// @param forwarderRegistry The address of the ForwarderRegistry contract.
    constructor(
        IERC1155 genesisToken,
        EDUCreditsManager eduCreditsManager,
        ILayerZeroEndpoint lzEndpoint,
        uint16 lzDstChainId,
        uint256 mintPrice,
        uint256 mintSupplyLimit,
        uint256 mintLimitPerAddress,
        uint256[] memory timestamps,
        uint256[] memory discountThresholds,
        uint256[] memory discountPercentages,
        IForwarderRegistry forwarderRegistry
    ) payable ContractOwnership(msg.sender) ForwarderRegistryContext(forwarderRegistry) {
        GENESIS_TOKEN = genesisToken;
        EDU_CREDITS_MANAGER = eduCreditsManager;
        LZ_ENDPOINT = lzEndpoint;
        LZ_DST_CHAINID = lzDstChainId;
        MINT_PRICE = mintPrice;
        MINT_SUPPLY_LIMIT = mintSupplyLimit;
        MINT_LIMIT_PER_ADDRESS = mintLimitPerAddress;
        if (timestamps[1] <= timestamps[0] || timestamps[2] <= timestamps[1] || timestamps[3] <= timestamps[2]) revert InvalidTimestamps();
        PHASE1_START_TIMESTAMP = timestamps[0];
        PHASE2_START_TIMESTAMP = timestamps[1];
        PHASE3_START_TIMESTAMP = timestamps[2];
        SALE_END_TIMESTAMP = timestamps[3];
        if (discountThresholds[1] <= discountThresholds[0] || discountThresholds[2] <= discountThresholds[1]) revert InvalidDiscountThresholds();
        DISCOUNT_THRESHOLD_1 = discountThresholds[0];
        DISCOUNT_THRESHOLD_2 = discountThresholds[1];
        DISCOUNT_THRESHOLD_3 = discountThresholds[2];
        if (discountPercentages[1] <= discountPercentages[0] || discountPercentages[2] <= discountPercentages[1]) revert InvalidDiscountPercentages();
        DISCOUNT_PERCENTAGE_1 = discountPercentages[0];
        DISCOUNT_PERCENTAGE_2 = discountPercentages[1];
        DISCOUNT_PERCENTAGE_3 = discountPercentages[2];
    }

    receive() external payable {}

    /// @notice Sets the LZ destination address.
    /// @dev Reverts with `NotContractOwner` if the sender is not the contract owner.
    /// @dev Reverts with `LzDstAddressAlreadySet` if the LZ destination address is already set.
    /// @param lzDstAddress_ The LZ destination address.
    function setLzDstAddress(address lzDstAddress_) external {
        ContractOwnershipStorage.layout().enforceIsContractOwner(_msgSender());
        if (lzDstAddress != address(0)) revert LzDstAddressAlreadySet();
        lzDstAddress = lzDstAddress_;
    }

    /// @notice Withdraws the contract's balance.
    /// @dev Reverts with `NotContractOwner` if the sender is not the contract owner.
    /// @param to The address to receive the withdrawn balance.
    function withdraw(address to) external {
        ContractOwnershipStorage.layout().enforceIsContractOwner(_msgSender());
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(to).transfer(balance);
        }
    }

    /// @notice Mints tokens.
    /// @dev Reverts with `MintingZeroTokens` if the number of tokens to mint is zero.
    /// @dev Reverts with `MintingTooManyTokens` if the number of tokens to mint is greater then the mint limit per tx.
    /// @dev Reverts with `SaleNotStarted` if the sale has not started yet.
    /// @dev Reverts with `NotADiamondHand` if the sender is not a diamond hand and the sale is in phase 1.
    /// @dev Reverts with `NotADiamondHandNorAGenesisNFTOwner` if the sender is not a diamond hand nor a genesis NFT owner and the sale is in phase 2.
    /// @dev Reverts with `SaleEnded` if the sale has ended.
    /// @dev Reverts with `LzDstAddressNotSet` if the LZ destination address is not set.
    /// @dev Reverts with `AddressMintingLimitReached` if the sender mint limit is overflowing.
    /// @dev Reverts with `InsufficientMintSupply` if the mint supply limit has been reached.
    /// @dev Emits a `MintInitiated` event.
    /// @param nbTokens The number of tokens to mint.
    function mint(uint256 nbTokens) external {
        if (nbTokens == 0) revert MintingZeroTokens();
        if (nbTokens > MINT_LIMIT_PER_TX) revert MintingTooManyTokens();

        address sender = _msgSender();

        uint256 salePhase = currentSalePhase();
        if (salePhase == 0) {
            revert SaleNotStarted();
        } else if (salePhase == 1) {
            if (!EDU_CREDITS_MANAGER.diamondHand(sender)) revert NotADiamondHand();
        } else if (salePhase == 2) {
            if (!EDU_CREDITS_MANAGER.diamondHand(sender) && GENESIS_TOKEN.balanceOf(sender, 1) == 0 && GENESIS_TOKEN.balanceOf(sender, 2) == 0)
                revert NotADiamondHandNorAGenesisNFTOwner();
        } else if (salePhase == 3) {
            // no restrictions, open sale
        } else {
            revert SaleEnded();
        }
        address dstAddress = lzDstAddress;
        if (dstAddress == address(0)) revert LzDstAddressNotSet();

        uint256 currentMintCount = mintCount;
        uint256 newMintCount = currentMintCount + nbTokens;
        if (newMintCount > MINT_SUPPLY_LIMIT) revert InsufficientMintSupply();
        mintCount = newMintCount;

        uint256 currentAddressMintCount = mintCountPerAddress[sender];
        uint256 newAdressMintCount = currentAddressMintCount + nbTokens;
        if (newAdressMintCount > MINT_LIMIT_PER_ADDRESS) revert AddressMintingLimitReached();
        mintCountPerAddress[sender] = newAdressMintCount;

        (uint256 price, uint256 discountThreshold) = currentMintPrice();
        EDU_CREDITS_MANAGER.spend(sender, price * nbTokens);

        bytes memory payload = abi.encode(sender, nbTokens);
        uint256 gasUsage = 125000 + 30000 * nbTokens;
        bytes memory adapterParams = abi.encodePacked(uint16(1), gasUsage);
        (uint256 fees, ) = LZ_ENDPOINT.estimateFees(LZ_DST_CHAINID, dstAddress, payload, false, adapterParams);
        // solhint-disable-next-line check-send-result
        LZ_ENDPOINT.send{value: fees}(
            LZ_DST_CHAINID,
            abi.encodePacked(dstAddress, address(this)),
            payload,
            payable(address(this)),
            address(0),
            adapterParams
        );
        emit MintInitiated(sender, nbTokens, discountThreshold);
    }

    /// @notice Returns the current mint price and discount threshold.
    /// @return price The current mint price.
    /// @return discountThreshold The current discount threshold.
    function currentMintPrice() public view returns (uint256 price, uint256 discountThreshold) {
        price = MINT_PRICE;
        uint256 currentCreditsInPool = EDU_CREDITS_MANAGER.totalCredits();
        if (currentCreditsInPool >= DISCOUNT_THRESHOLD_3) {
            price = (price * (100 - DISCOUNT_PERCENTAGE_3)) / 100;
            discountThreshold = 3;
        } else if (currentCreditsInPool >= DISCOUNT_THRESHOLD_2) {
            price = (price * (100 - DISCOUNT_PERCENTAGE_2)) / 100;
            discountThreshold = 2;
        } else if (currentCreditsInPool >= DISCOUNT_THRESHOLD_1) {
            price = (price * (100 - DISCOUNT_PERCENTAGE_1)) / 100;
            discountThreshold = 1;
        }
    }

    /// @notice Returns the current sale phase.
    /// @return The current sale phase.
    function currentSalePhase() public view returns (uint256) {
        if (block.timestamp > SALE_END_TIMESTAMP) {
            return 4;
        } else if (block.timestamp >= PHASE3_START_TIMESTAMP) {
            return 3;
        } else if (block.timestamp >= PHASE2_START_TIMESTAMP) {
            return 2;
        } else if (block.timestamp >= PHASE1_START_TIMESTAMP) {
            return 1;
        } else {
            return 0;
        }
    }

    /// @notice Returns whether the specified account can mint.
    /// @param account The account to check.
    /// @return Whether the specified account can mint.
    function canMint(address account) public view returns (bool) {
        uint256 salePhase = currentSalePhase();
        if (salePhase == 0) {
            return false;
        } else if (salePhase == 1) {
            return EDU_CREDITS_MANAGER.diamondHand(account);
        } else if (salePhase == 2) {
            return EDU_CREDITS_MANAGER.diamondHand(account) || GENESIS_TOKEN.balanceOf(account, 1) != 0 || GENESIS_TOKEN.balanceOf(account, 2) != 0;
        } else if (salePhase == 3) {
            return true;
        } else {
            return false;
        }
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgSender() internal view virtual override(Context, ForwarderRegistryContextBase) returns (address) {
        return ForwarderRegistryContextBase._msgSender();
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgData() internal view virtual override(Context, ForwarderRegistryContextBase) returns (bytes calldata) {
        return ForwarderRegistryContextBase._msgData();
    }
}
