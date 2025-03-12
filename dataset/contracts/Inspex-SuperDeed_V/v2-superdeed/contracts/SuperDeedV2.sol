// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./core/DataStore.sol";
import "./logic/Vesting.sol";
import "./interfaces/IEmergency.sol";

contract SuperDeedV2 is ERC721Enumerable, IEmergency, ERC1155Holder, ERC721Holder, DataStore, ReentrancyGuard {

    using SafeERC20 for IERC20;
    using MerkleClaims for DataType.Group;
    using Groups for *;
    using Vesting for *;

    string private constant SUPER_DEED = "SuperDeed";
    string private constant BASE_URI = "https://superlauncher.io/metadata/";

    constructor(
        IRoleAccess roles,
        address projectOwnerAddress, 
        string memory tokenSymbol, 
        string memory deedName
    ) 
        ERC721(deedName, SUPER_DEED)  
        DataStore(roles, projectOwnerAddress)
    {
        _setAsset(tokenSymbol, deedName);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, ERC1155Receiver) returns (bool) {
        return ERC721Enumerable.supportsInterface(interfaceId) || 
            ERC1155Receiver.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 /*tokenId*/) public view virtual override returns (string memory) {
        return  string(abi.encodePacked(BASE_URI, _store().asset.deedName));
    }

    //--------------------//
    //   SETUP & CONFIG   //
    //--------------------//

    function appendGroups(string[] memory names) external notLive onlyProjectOwnerOrConfigurator {
        uint added = _groups().appendGroups(names);
        _recordHistory(DataType.ActionType.AppendGroups, added);
    }

    function defineVesting(uint groupId, string memory groupName, DataType.VestingItem[] calldata vestItems) external  notLive onlyProjectOwnerOrConfigurator {    
        _check(groupId, groupName);
        uint added = _groups().defineVesting(groupId, vestItems);
        _recordHistory(DataType.ActionType.DefineVesting, added);
    }

    function uploadUsersData(uint groupId, string memory groupName, bytes32 merkleRoot, uint totalTokens) external  notLive onlyProjectOwnerOrConfigurator {   
        _check(groupId, groupName);
        _groups().uploadUsersData(groupId, merkleRoot, totalTokens);
        _recordHistory(DataType.ActionType.UploadUsersData, groupId, totalTokens);
    }

    function setAssetDetails(address tokenAddress, DataType.AssetType tokenType, uint tokenIdFor1155) external notLive onlyProjectOwnerOrConfigurator {
        _setAssetDetails(tokenAddress, tokenType, tokenIdFor1155);
        _recordHistory(DataType.ActionType.SetAssetAddress, uint160(tokenAddress), uint(tokenType));
    }

    function setGroupFinalized(uint groupId, string memory groupName) external notLive onlyProjectOwnerOrApprover {
        _check(groupId, groupName);
        _groups().setFinalized(groupId, groupName);
        emit FinalizeGroup(msg.sender, groupId, groupName);
        _recordHistory(DataType.ActionType.FinalizeGroup, groupId);
    }

    function fundInForGroup(uint groupId, string memory groupName, uint tokenAmount) external notLive onlyProjectOwnerOrApprover {
        _check(groupId, groupName);
        _require(_asset().tokenAddress != Constant.ZERO_ADDRESS, "Invalid address");
        
        // Check required token Amount is correct?
        DataType.Group storage group = _groups().items[groupId];
        _require(tokenAmount == group.info.totalEntitlement, "Wrong token amount");

        // Group must be finalized and not yet fund in
        _require(group.state.finalized, "Not yet finalized");
        _require(!group.state.funded, "Already funded");
        group.state.funded = true;
        
        DataType.AssetType assetType = _asset().tokenType;
        if (assetType == DataType.AssetType.ERC20) {
            IERC20(_asset().tokenAddress).safeTransferFrom(msg.sender, address(this), tokenAmount); 
        } else if (assetType == DataType.AssetType.ERC1155) {
            IERC1155(_asset().tokenAddress).safeTransferFrom(msg.sender, address(this), _asset().tokenId, tokenAmount, ""); 
        } else {
            // Verify that the amount has been deposied already ?
            DataType.Erc721Handler storage handler = _store().erc721Handler;

            uint totalDeposited721 = handler.erc721IdArray.length;
            _require(totalDeposited721 >= (handler.numUsedByVerifiedGroups + tokenAmount), "Insufficient deposited erc721");
            handler.numUsedByVerifiedGroups += tokenAmount;
        }   
        emit FundInForGroup(msg.sender, groupId, groupName, tokenAmount);
        _recordHistory(DataType.ActionType.FundInForGroup, groupId, tokenAmount);
    }

    // For projects that are unable to fund in fully, but able to do progressive fund-ins, the MS DAO can override the
    // full FundIn requirement. In this case the project need to prove to SuperLauncher that they can provide the 
    // required assets on time without failure. For example, project can provide a funding contract for this purpose.
    function fundInForGroupOverride(uint groupId, string memory groupName) external notLive onlyDaoMultiSig {

        _check(groupId, groupName);
        _require(_asset().tokenAddress != Constant.ZERO_ADDRESS, "Invalid address");
        
        // Check required token Amount is correct?
        DataType.Group storage group = _groups().items[groupId];
        // Group must be finalized and not yet fund in
        _require(group.state.finalized, "Not yet finalized");
        _require(!group.state.funded, "Already funded");
        group.state.funded = true;

        emit FundInForGroupOverrided(msg.sender, groupId, groupName);
        _recordHistory(DataType.ActionType.FundInForGroupOverrided, groupId, 0);
    }

    function notifyErc721Deposited(uint[] calldata ids) external notLive onlyProjectOwnerOrApprover {

        _require(_asset().tokenType == DataType.AssetType.ERC721, "Not Erc721 asset");
        address token = _asset().tokenAddress;

        DataType.Erc721Handler storage handler = _store().erc721Handler;

        uint id;
        uint len = ids.length;
        for (uint n=0; n<len; n++) {

            // Make sure it is owned by this contract
            id = ids[n];
            _require(IERC721(token).ownerOf(id) == address(this), "Nft Id not deposited");
            
            if (!handler.idExistMap[id]) {
                handler.idExistMap[id] = true;
                handler.erc721IdArray.push(id);
            }
        }
    }

    // If startTime is 0, the vesting wil start immediately.
    function startVesting(uint startTime) external notLive onlyProjectOwnerOrApprover {

        // Make sure that the asset address are set before start vesting
        _require(_asset().tokenAddress != Constant.ZERO_ADDRESS, "Set token address first");

        if (startTime==0) {
            startTime = block.timestamp;
        } 
        _require(startTime >= block.timestamp, "Cannot back-date vesting");
        _groups().vestingStartTime = startTime;
        emit StartVesting(msg.sender, startTime);
        _recordHistory(DataType.ActionType.StartVesting, startTime);
    }

    //--------------------//
    //   USER OPERATION   //
    //--------------------//

    // A user address can participate in multiple groups. In this way, a user address can claim multiple deeds.
    function claimDeeds(uint[] calldata groupIds, uint[] calldata indexes, uint[] calldata amounts, bytes32[][] calldata merkleProofs) external nonReentrant {
        
        uint len = groupIds.length;
        _require(len > 0 && len == indexes.length && len == merkleProofs.length, "Invalid parameters");

        uint grpId;
        uint claimIndex;
        uint amount;
        uint nftId;

        DataType.Groups storage groups = _groups();
        for (uint n=0; n<len; n++) {
            
            grpId = groupIds[n];
            claimIndex = indexes[n];
            amount = amounts[n]; 

            DataType.Group storage item = groups.items[grpId];
            _require(item.state.finalized, "Not finalized");
            _require(!item.isClaimed(claimIndex), "Already claimed");

            item.claim(claimIndex, msg.sender, amount, merkleProofs[n]);
            
            // Mint NFT
            nftId = _mintInternal(msg.sender, grpId, amount, 0);
            emit ClaimDeed(msg.sender, block.timestamp, grpId, claimIndex, amount, nftId);
            _recordHistory(DataType.ActionType.ClaimDeed, grpId, nftId);
        }
    }

    function getGroupReleasable(uint groupId) external view returns (uint percentReleasable, uint totalEntitlement) {
        
        if (getGroupState(groupId).finalized) {
            totalEntitlement =  getGroupInfo(groupId).totalEntitlement;
            percentReleasable = _groups().getClaimable(groupId);
        }
    }

    function getClaimable(uint nftId) public view returns (uint claimable, uint totalClaimed, uint totalEntitlement) {
        DataType.NftInfo memory nft = getNftInfo(nftId);
        if (nft.valid) {
            totalEntitlement =  nft.totalEntitlement;
            totalClaimed = nft.totalClaimed;

            uint percentReleasable = _groups().getClaimable(nft.groupId);
            if (percentReleasable > 0) {
                uint totalReleasable = (percentReleasable * totalEntitlement) / Constant.PCNT_100;
                if (totalReleasable > totalClaimed) {
                    claimable = totalReleasable - totalClaimed;
                }
            }
        }
    }

    // ERC721 cannot be batchTransfer. In order to make sure the claim will not fail due to claiming
    // a huge number of ERC721 token, we allow specifying a claim amount 'maxAmount'. This way, the
    // user can claim multiple times without having gas limitation issue.
    // If maxAmount is set to 0, it will claim all available tokens.
    function claimTokens(uint nftId, uint maxAmount) external nonReentrant {
        _require(ownerOf(nftId) == msg.sender, "Not owner");

        // if this group is not yet funded, it should not be claimable
        uint groupId = getNftInfo(nftId).groupId;
        require(getGroupState(groupId).funded, "Group not funded yet");

        (uint claimable, ,) =  getClaimable(nftId);
        _require(claimable > 0, "Nothing to claim");
        
        // Partial claim ?
        if (maxAmount != 0 && claimable > maxAmount) {
            claimable = maxAmount;
        }
    
        DataType.NftInfo storage nft = _store().nftInfoMap[nftId];
        nft.totalClaimed += claimable;

        _transferAssetOut(msg.sender, claimable);
        emit ClaimTokens(msg.sender, block.timestamp, nftId, claimable);
        _recordHistory(DataType.ActionType.ClaimTokens, nftId, claimable);
    }

    // Split an amount of entitlement out from the "remaining" entitlement from an exceeding Deed and becomes a new Deed.
    // After the split, both Deeds should have non-zero remaining entitlement left.
    function split(uint id, uint amount) external nonReentrant returns (uint newId) {
        _require(ownerOf(id) == msg.sender, "Not owner");
        
        DataType.NftInfo storage nft = _store().nftInfoMap[id];

        uint entitlementLeft = nft.totalEntitlement - nft.totalClaimed;
        _require(amount > 0 && entitlementLeft > amount, "Invalid amount");

        // Calculate the new NFT's required totalEntitlemnt totalClaimed, in a way that these values are distributed 
        // as fairly as possible between the parent and child NFT. 
        // Important note is that the sum of the totalEntitlement and totalClaimed before and after the split 
        // should remain the same. Nothing more or less is resulted due to the split.
        uint neededTotalEnt = (amount * nft.totalEntitlement) / entitlementLeft;
        _require(neededTotalEnt > 0, "Invalid amount");
        uint neededTotalClaimed = neededTotalEnt - amount;

        nft.totalEntitlement -= neededTotalEnt;
        nft.totalClaimed -= neededTotalClaimed;

        // Sanity Check
        _require(nft.totalEntitlement > 0 && nft.totalClaimed < nft.totalEntitlement, "Fail check");
        
        // mint new nft
        newId = _mintInternal(msg.sender, nft.groupId, neededTotalEnt, neededTotalClaimed);
        emit Split(block.timestamp, id, newId, amount);
    }

    function combine(uint id1, uint id2) external nonReentrant {
        _require(ownerOf(id1) == msg.sender && ownerOf(id2) == msg.sender, "Not owner");

        DataType.NftInfo storage nft1 = _store().nftInfoMap[id1];
        DataType.NftInfo memory nft2 = _store().nftInfoMap[id2];
        
        // Must be the same group
        _require(nft1.groupId == nft2.groupId, "Not same group");

        // Since the vesting items are the same, we can just add up the 2 nft 
        nft1.totalEntitlement += nft2.totalEntitlement;
        nft1.totalClaimed += nft2.totalClaimed;
         
        // Burn NFT 2 
        _burn(id2);
        delete _store().nftInfoMap[id2];

        emit Combine(block.timestamp, id1, id2);
    }

    function version() external pure returns (uint) {
        return Constant.SUPERDEED_VERSION;
    }

    // Implements IEmergency 
    function approveEmergencyAssetWithdraw(uint maxAmount) external override onlyProjectOwner {
        _emergencyMaxAmount = maxAmount;
        _emergencyExpiryTime = block.timestamp + Constant.EMERGENCY_WINDOW;
        emit ApprovedEmergencyWithdraw(msg.sender, _emergencyMaxAmount, _emergencyExpiryTime);
    }

    function daoMultiSigEmergencyWithdraw(address tokenAddress, address to, uint amount) external override onlyDaoMultiSig {
       
        // If withdrawn token is the asset, then we will require projectOwner to approve.
        // Every approval allow 1 time withdraw only.
        if (tokenAddress == _asset().tokenAddress) {
            _require((amount <= _emergencyMaxAmount) && (block.timestamp <= _emergencyExpiryTime), "Criteria not met");
           
            // Reset 
            _emergencyMaxAmount = 0;
            _emergencyExpiryTime = 0;

            _transferAssetOut(to, amount);
        } else {
            // Withdraw non asset ERC20   
            _transferOutErc20(tokenAddress, to, amount); 
        }
        emit DaoMultiSigEmergencyWithdraw(to, tokenAddress, amount);
    }

    //--------------------//
    // INTERNAL FUNCTIONS //
    //--------------------//
 
    function _mintInternal(address to, uint groupId, uint totalEntitlement, uint totalClaimed) internal returns (uint id) {
        _require(totalEntitlement > 0, "Invalid entitlement");
        id = _nextNftIdIncrement();
        _mint(to, id);

        // Setup the certificate's info
        _store().nftInfoMap[id] = DataType.NftInfo(groupId, totalEntitlement, totalClaimed, true);
    }
}
