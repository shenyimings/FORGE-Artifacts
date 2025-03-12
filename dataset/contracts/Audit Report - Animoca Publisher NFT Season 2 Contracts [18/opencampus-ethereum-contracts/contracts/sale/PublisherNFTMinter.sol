// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC721Mintable} from "@animoca/ethereum-contracts/contracts/token/ERC721/interfaces/IERC721Mintable.sol";
import {ILayerZeroEndpoint} from "@layerzerolabs/solidity-examples/contracts/interfaces/ILayerZeroEndpoint.sol";
import {ILayerZeroReceiver} from "@layerzerolabs/solidity-examples/contracts/interfaces/ILayerZeroReceiver.sol";
import {ContractOwnershipStorage} from "@animoca/ethereum-contracts/contracts/access/libraries/ContractOwnershipStorage.sol";
import {ContractOwnership} from "@animoca/ethereum-contracts/contracts/access/ContractOwnership.sol";

/// @title PublisherNFTMinter
/// @notice This contract is used to mint season 2 Publisher NFTs on the Polygon.
contract PublisherNFTMinter is ILayerZeroReceiver, ContractOwnership {
    using ContractOwnershipStorage for ContractOwnershipStorage.Layout;

    IERC721Mintable public immutable PUBLISHER_NFT;
    ILayerZeroEndpoint public immutable LZ_ENDPOINT;
    uint16 public immutable LZ_SRC_CHAINID;
    address public immutable LZ_SRC_ADDRESS;
    uint256 public immutable MINT_SUPPLY_LIMIT;

    uint256 public mintCount;

    /// @dev Thrown when the caller of lzReceive is not the LayerZero endpoint.
    /// @param sender The caller of the lzReceive function
    error UnauthorizedSender(address sender);

    /// @dev Thrown when the source chain identifier is incorrect.
    /// @param srcChainId The incorrect source chain identifier.
    error IncorrectSrcChainId(uint16 srcChainId);

    /// @dev Thrown when the source address is incorrect.
    /// @param srcAddress The incorrect source address.
    error IncorrectSrcAddress(address srcAddress);

    /// @dev Thrown when the mint supply limit is reached.
    error InsufficientMintSupply();

    constructor(
        IERC721Mintable publisherNFT,
        ILayerZeroEndpoint lzEndpoint,
        uint16 lzSrcChainId,
        address lzSrcAddress,
        uint256 mintSupplyLimit
    ) ContractOwnership(msg.sender) {
        PUBLISHER_NFT = publisherNFT;
        LZ_ENDPOINT = lzEndpoint;
        LZ_SRC_CHAINID = lzSrcChainId;
        LZ_SRC_ADDRESS = lzSrcAddress;
        MINT_SUPPLY_LIMIT = mintSupplyLimit;
    }

    /// @notice LayerZero endpoint will invoke this function to deliver minting requests from the PublisherNFTSale contract.
    /// @dev Reverts with `UnauthorizedSender` if the sender is not the LayerZero endpoint.
    /// Reverts with `IncorrectSrcChainId` if the source chain identifier is incorrect.
    /// Reverts with `IncorrectSrcAddress` if the source address is incorrect.
    /// Reverts with `InsufficientMintSupply` if the mint supply limit is reached.
    /// @param srcChainId The source endpoint identifier
    /// @param dstPath The concatenation of the source contract address and this contract address.
    // / @param nonce The ordered message nonce
    /// @param payload The payload which contains the token owner and the number of tokens to mint.
    function lzReceive(uint16 srcChainId, bytes memory dstPath, uint64, bytes calldata payload) external {
        if (msg.sender != address(LZ_ENDPOINT)) revert UnauthorizedSender(msg.sender);
        if (srcChainId != LZ_SRC_CHAINID) revert IncorrectSrcChainId(srcChainId);
        address srcAddress;
        assembly {
            srcAddress := mload(add(dstPath, 20))
        }
        if (srcAddress != LZ_SRC_ADDRESS) revert IncorrectSrcAddress(srcAddress);
        (address tokenOwner, uint256 nbTokens) = abi.decode(payload, (address, uint256));

        uint256 currentMintCount = mintCount;
        if (currentMintCount + nbTokens > MINT_SUPPLY_LIMIT) revert InsufficientMintSupply();
        uint256[] memory tokenIds = new uint256[](nbTokens);
        for (uint256 i; i != nbTokens; ++i) {
            tokenIds[i] = currentMintCount;
            ++currentMintCount;
        }
        mintCount = currentMintCount;
        PUBLISHER_NFT.batchMint(tokenOwner, tokenIds);
    }

    function forceResumeReceive() external {
        ContractOwnershipStorage.layout().enforceIsContractOwner(_msgSender());
        LZ_ENDPOINT.forceResumeReceive(LZ_SRC_CHAINID, abi.encodePacked(LZ_SRC_ADDRESS, address(this)));
    }

    function retryPayload(address minter, uint256 nbTokens) external {
        LZ_ENDPOINT.retryPayload(LZ_SRC_CHAINID, abi.encodePacked(LZ_SRC_ADDRESS, address(this)), abi.encode(minter, nbTokens));
    }
}
