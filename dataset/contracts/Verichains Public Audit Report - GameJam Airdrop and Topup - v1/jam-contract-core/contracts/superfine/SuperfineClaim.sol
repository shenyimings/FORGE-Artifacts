/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract SuperfineClaim is Ownable {
    using ECDSA for bytes32;

    enum AssetType {
        ERC20,
        ERC721,
        ERC1155
    }

    struct Asset {
        AssetType assetType;
        address assetAddress;
        uint256 assetId; // 0 for ERC20
        uint256 amount; // 1 for ERC721
    }

    mapping(address => mapping(string => Asset[])) private _claimedAssets; // maps (user address + campaign ID) => claimed assets
    mapping(address => bool) private _operators;

    constructor() Ownable() {}

    function getClaimedAssets(
        address claimant,
        string calldata campaignId
    ) external view returns (Asset[] memory) {
        return _claimedAssets[claimant][campaignId];
    }

    function setOperators(
        address[] memory operators,
        bool[] memory isOperators
    ) external onlyOwner {
        require(
            operators.length == isOperators.length,
            "SuperfineClaim: lengths mismatch"
        );
        for (uint256 i = 0; i < operators.length; i++)
            _operators[operators[i]] = isOperators[i];
    }

    function claimAssets(
        string calldata campaignId,
        address campaignCreator,
        Asset[] calldata assets,
        bytes calldata signature
    ) external {
        // Build signing message
        address signer = _verifySignature(
            campaignId,
            msg.sender,
            assets,
            signature
        );
        require(_operators[signer], "SuperfineClaim: invalid signer");

        // Claim assets
        for (uint256 i = 0; i < assets.length; i++) {
            Asset memory asset = assets[i];
            _claimedAssets[msg.sender][campaignId].push(asset);
            if (asset.assetType == AssetType.ERC20) {
                require(asset.assetId == 0, "SuperfineClaim: invalid asset ID");
                bool success = IERC20(asset.assetAddress).transferFrom(
                    campaignCreator,
                    msg.sender,
                    asset.amount
                );
                require(success, "SuperfineClaim: failed to claim");
            } else if (asset.assetType == AssetType.ERC721) {
                require(
                    asset.amount == 1,
                    "SuperfineClaim: invalid asset amount"
                );
                IERC721(asset.assetAddress).safeTransferFrom(
                    campaignCreator,
                    msg.sender,
                    asset.assetId
                );
            } else if (asset.assetType == AssetType.ERC1155) {
                IERC1155(asset.assetAddress).safeTransferFrom(
                    campaignCreator,
                    msg.sender,
                    asset.assetId,
                    asset.amount,
                    abi.encodePacked(
                        asset.assetAddress,
                        asset.assetId,
                        asset.amount
                    )
                );
            }
        }
    }

    function _verifySignature(
        string calldata campaignId,
        address userAddress,
        Asset[] calldata assets,
        bytes calldata signature
    ) private pure returns (address) {
        // Build siging message
        bytes memory message = abi.encodePacked(campaignId, userAddress);
        for (uint256 i = 0; i < assets.length; i++) {
            message = bytes.concat(
                message,
                abi.encodePacked(
                    uint256(assets[i].assetType),
                    assets[i].assetAddress,
                    assets[i].assetId,
                    assets[i].amount
                )
            );
        }

        // Validate operator's signature
        bytes32 messageHash = keccak256(message).toEthSignedMessageHash();
        return messageHash.recover(signature);
    }
}
