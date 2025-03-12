/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract SuperfineAirdrop is Ownable, ReentrancyGuard {
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

    struct AirdropCampaign {
        string campaignId;
        address creator;
        Asset[] assets;
        uint256 maxBatchSize;
        uint256 chargedFee;
        bool airdropStarted;
    }

    uint256 private _maxBatchSize;
    uint256 private _feePerBatch;
    mapping(string => AirdropCampaign) private _campaignById;
    mapping(address => bool) private _operators;

    event AirdropCampaignCreated(
        string campaignId,
        address creator,
        Asset[] assets,
        uint256 maxBatchSize
    );

    event AirdropCampaignUpdated(
        string campaignId,
        address creator,
        Asset[] assets,
        uint256 maxBatchSize
    );

    event AssetsAirdropped(
        string campaignId,
        address creator,
        Asset[] assets,
        address[] recipients
    );

    constructor(uint256 maxBatchSize, uint256 feePerBatch) Ownable() {
        require(
            maxBatchSize > 0,
            "SuperfineAirdrop: the size of the batch must be greater than zero"
        );
        _maxBatchSize = maxBatchSize;
        _feePerBatch = feePerBatch;
        _operators[msg.sender] = true;
    }

    modifier onlyOperators() {
        require(
            _operators[msg.sender],
            "SuperfineAirdrop: the caller is not the operator"
        );
        _;
    }

    function getCampaignById(
        string memory campaignId
    ) external view returns (AirdropCampaign memory) {
        return _campaignById[campaignId];
    }

    function estimateAirdropFee(
        uint256 numAssets
    ) public view returns (uint256) {
        uint256 numRequiredBatches = (numAssets + _maxBatchSize - 1) /
            _maxBatchSize; // ceil(numAssets / _maxBatchSize)
        return numRequiredBatches * _feePerBatch;
    }

    function setOperators(
        address[] calldata operators,
        bool[] calldata isOperators
    ) external onlyOwner {
        require(
            operators.length == isOperators.length,
            "SuperfineAirdrop: the number of operators and the number of statuses must be equal"
        );
        for (uint256 i = 0; i < operators.length; i++)
            _operators[operators[i]] = isOperators[i];
    }

    function setMaxBatchSize(uint256 newSize) external onlyOperators {
        require(
            newSize > 0,
            "SuperfineAirdrop: the size of the batch must be greater than zero"
        );
        _maxBatchSize = newSize;
    }

    function setFeePerBatch(uint256 newFee) external onlyOperators {
        _feePerBatch = newFee;
    }

    function createAirdropCampaign(
        string calldata campaignId,
        Asset[] calldata assets
    ) external payable nonReentrant {
        AirdropCampaign storage campaign = _campaignById[campaignId];

        // Check if campaign exists
        require(
            campaign.creator == address(0),
            "SuperfineAirdrop: the campaign has already been created before"
        );

        // Check payment
        uint256 airdropFee = estimateAirdropFee(assets.length);
        require(
            msg.value >= airdropFee,
            "SuperfineAirdrop: the paid fee is insufficient"
        );
        if (msg.value > airdropFee) {
            (bool success, ) = payable(msg.sender).call{
                value: msg.value - airdropFee
            }("");
            require(
                success,
                "SuperfineAirdrop: the excess is failed to be returned"
            );
        }

        // Validate data
        for (uint256 i = 0; i < assets.length; i++) {
            Asset memory asset = assets[i];
            require(
                uint256(asset.assetType) <= 2,
                "SuperfineAirdrop: the asset type is invalid"
            );
            if (asset.assetType == AssetType.ERC20)
                require(
                    asset.assetId == 0,
                    "SuperfineAirdrop: the asset ID of the ERC20 token must be 0"
                );
            else if (asset.assetType == AssetType.ERC721)
                require(
                    asset.amount == 1,
                    "SuperfineAirdrop: the amount of the ERC721 token must be 1"
                );
        }

        // Create new airdrop campaign
        campaign.campaignId = campaignId;
        campaign.creator = msg.sender;
        for (uint256 k = 0; k < assets.length; k++)
            campaign.assets.push(assets[k]);
        campaign.maxBatchSize = _maxBatchSize;
        campaign.chargedFee = airdropFee;

        emit AirdropCampaignCreated(
            campaignId,
            msg.sender,
            assets,
            _maxBatchSize
        );
    }

    function updateCampaign(
        string calldata campaignId,
        Asset[] calldata assets
    ) external payable nonReentrant {
        AirdropCampaign storage campaign = _campaignById[campaignId];

        // Check campaign ownership
        require(
            campaign.creator == msg.sender,
            "SuperfineAirdrop: the caller is not the owner of the campaign"
        );

        // Make sure that this campaign has not started yet
        require(
            !campaign.airdropStarted,
            "SuperfineAirdrop: the assets of the campaign cannot be updated since the airdrop process has already started"
        );

        // Check payment
        uint256 newAirdropFee = estimateAirdropFee(assets.length);
        if (newAirdropFee > campaign.chargedFee) {
            require(
                msg.value >= newAirdropFee - campaign.chargedFee,
                "SuperfineAirdrop:insufficient airdrop fee"
            );
            if (msg.value > newAirdropFee - campaign.chargedFee) {
                (bool success, ) = payable(msg.sender).call{
                    value: msg.value + campaign.chargedFee - newAirdropFee
                }("");
                require(
                    success,
                    "SuperfineAirdrop: the excess is failed to be returned"
                );
            }
        }

        // Validate data
        for (uint256 i = 0; i < assets.length; i++) {
            Asset memory asset = assets[i];
            require(
                uint256(asset.assetType) <= 2,
                "SuperfineAirdrop: the asset type is invalid"
            );
            if (asset.assetType == AssetType.ERC20)
                require(
                    asset.assetId == 0,
                    "SuperfineAirdrop: the asset ID of the ERC20 token must be 0"
                );
            else if (asset.assetType == AssetType.ERC721)
                require(
                    asset.amount == 1,
                    "SuperfineAirdrop: the amount of the ERC721 token must be 1"
                );
        }

        // Update campaign info
        delete campaign.assets;
        for (uint256 k = 0; k < assets.length; k++)
            campaign.assets.push(assets[k]);
        campaign.maxBatchSize = _maxBatchSize;
        if (newAirdropFee > campaign.chargedFee)
            campaign.chargedFee = newAirdropFee;

        emit AirdropCampaignUpdated(
            campaignId,
            msg.sender,
            assets,
            campaign.maxBatchSize
        );
    }

    function airdrop(
        string calldata campaignId,
        uint256[] calldata assetIndexes,
        address[] calldata recipients
    ) external onlyOperators nonReentrant {
        require(
            _campaignById[campaignId].creator != address(0),
            "SuperfineAirdrop: the campaign does not exist"
        );
        AirdropCampaign storage campaign = _campaignById[campaignId];
        require(
            assetIndexes.length == recipients.length,
            "SuperfineAirdrop: the number of assets and the number of recipients must be equal"
        );
        require(
            assetIndexes.length <= campaign.maxBatchSize,
            "SuperfineAirdrop: the number of assets must not exceed the maximum size of a single batch"
        );
        if (!campaign.airdropStarted) campaign.airdropStarted = true;
        Asset[] memory airdroppedAssets = new Asset[](assetIndexes.length);
        for (uint256 i = 0; i < assetIndexes.length; i++) {
            require(
                assetIndexes[i] < campaign.assets.length,
                "SuperfineAirdrop: the asset index cannot be larger than the total number of assets in this campaign"
            );
            airdroppedAssets[i] = campaign.assets[assetIndexes[i]];
            Asset storage asset = campaign.assets[assetIndexes[i]];
            require(
                asset.amount > 0,
                "SuperfineAirdrop: this reward has already been sent before"
            );
            if (asset.assetType == AssetType.ERC20) {
                bool success = IERC20(asset.assetAddress).transferFrom(
                    campaign.creator,
                    recipients[i],
                    asset.amount
                );
                require(
                    success,
                    "SuperfineAirdrop: the transfer process of the ERC20 assets failed"
                );
                asset.amount = 0;
            } else if (asset.assetType == AssetType.ERC721) {
                IERC721(asset.assetAddress).transferFrom(
                    campaign.creator,
                    recipients[i],
                    asset.assetId
                );
                asset.amount = 0;
            } else if (asset.assetType == AssetType.ERC1155) {
                IERC1155(asset.assetAddress).safeTransferFrom(
                    campaign.creator,
                    recipients[i],
                    asset.assetId,
                    asset.amount,
                    abi.encodePacked("Airdrop ERC1155 assets")
                );
                asset.amount = 0;
            }
        }
        emit AssetsAirdropped(
            campaignId,
            campaign.creator,
            airdroppedAssets,
            recipients
        );
    }

    function withdrawAirdropFee(address recipient) external onlyOwner {
        (bool success, ) = payable(recipient).call{
            value: address(this).balance
        }("");
        require(
            success,
            "SuperfineAirdrop: the process of withdrawing airdrop fee is failed"
        );
    }
}
