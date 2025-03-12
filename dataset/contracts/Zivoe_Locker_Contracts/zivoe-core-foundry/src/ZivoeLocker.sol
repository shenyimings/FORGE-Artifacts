// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./libraries/OwnableLocked.sol";

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";



/// @notice  This contract standardizes communication between the DAO and lockers.
abstract contract ZivoeLocker is OwnableLocked, ERC1155Holder, ERC721Holder {
    
    using SafeERC20 for IERC20;

    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeLocker contract.
    constructor() {}



    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for calling pushToLocker().
    function canPush() public virtual view returns (bool) { return false; }

    /// @notice Permission for calling pullFromLocker().
    function canPull() public virtual view returns (bool) { return false; }

    /// @notice Permission for calling pullFromLockerPartial().
    function canPullPartial() public virtual view returns (bool) { return false; }

    /// @notice Permission for calling pushToLockerMulti().
    function canPushMulti() public virtual view returns (bool) { return false; }

    /// @notice Permission for calling pullFromLockerMulti().
    function canPullMulti() public virtual view returns (bool) { return false; }

    /// @notice Permission for calling pullFromLockerMultiPartial().
    function canPullMultiPartial() public virtual view returns (bool) { return false; }

    /// @notice Permission for calling pushToLockerERC721().
    function canPushERC721() public virtual view returns (bool) { return false; }

    /// @notice Permission for calling pullFromLockerERC721().
    function canPullERC721() public virtual view returns (bool) { return false; }

    /// @notice Permission for calling pushToLockerMultiERC721().
    function canPushMultiERC721() public virtual view returns (bool) { return false; }

    /// @notice Permission for calling pullFromLockerMultiERC721().
    function canPullMultiERC721() public virtual view returns (bool) { return false; }

    /// @notice Permission for calling pushToLockerERC1155().
    function canPushERC1155() public virtual view returns (bool) { return false; }

    /// @notice Permission for calling pullFromLockerERC1155().
    function canPullERC1155() public virtual view returns (bool) { return false; }

    /// @notice Migrates specific amount of ERC20 from owner() to locker.
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pushToLocker(address asset, uint256 amount, bytes calldata data) external virtual onlyOwner {
        require(canPush(), "ZivoeLocker::pushToLocker() !canPush()");
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
    }

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external virtual onlyOwner {
        require(canPull(), "ZivoeLocker::pullFromLocker() !canPull()");
        IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
    }

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(address asset, uint256 amount, bytes calldata data) external virtual onlyOwner {
        require(canPullPartial(), "ZivoeLocker::pullFromLockerPartial() !canPullPartial()");
        IERC20(asset).safeTransfer(owner(), amount);
    }

    /// @notice Migrates specific amounts of ERC20s from owner() to locker.
    /// @param  assets The assets to migrate.
    /// @param  amounts The amounts of "assets" to migrate, corresponds to "assets" by position in array.
    /// @param  data Accompanying transaction data.
    function pushToLockerMulti(
        address[] calldata assets, uint256[] calldata amounts, bytes[] calldata data
    ) external virtual onlyOwner {
        require(canPushMulti(), "ZivoeLocker::pushToLockerMulti() !canPushMulti()");
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransferFrom(owner(), address(this), amounts[i]);
        }
    }

    /// @notice Migrates full amount of ERC20s from locker to owner().
    /// @param  assets The assets to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerMulti(address[] calldata assets, bytes[] calldata data) external virtual onlyOwner {
        require(canPullMulti(), "ZivoeLocker::pullFromLockerMulti() !canPullMulti()");
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransfer(owner(), IERC20(assets[i]).balanceOf(address(this)));
        }
    }

    /// @notice Migrates specific amounts of ERC20s from locker to owner().
    /// @param  assets The assets to migrate.
    /// @param  amounts The amounts of "assets" to migrate, corresponds to "assets" by position in array.
    /// @param  data Accompanying transaction data.
    function pullFromLockerMultiPartial(
        address[] calldata assets, uint256[] calldata amounts, bytes[] calldata data
    ) external virtual onlyOwner {
        require(canPullMultiPartial(), "ZivoeLocker::pullFromLockerMultiPartial() !canPullMultiPartial()");
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransfer(owner(), amounts[i]);
        }
    }

    /// @notice Migrates an ERC721 from owner() to locker.
    /// @param  asset The NFT contract.
    /// @param  tokenId The ID of the NFT to migrate.
    /// @param  data Accompanying transaction data.
    function pushToLockerERC721(address asset, uint256 tokenId, bytes calldata data) external virtual onlyOwner {
        require(canPushERC721(), "ZivoeLocker::pushToLockerERC721() !canPushERC721()");
        IERC721(asset).safeTransferFrom(owner(), address(this), tokenId, data);
    }

    /// @notice Migrates an ERC721 from locker to owner().
    /// @param  asset The NFT contract.
    /// @param  tokenId The ID of the NFT to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerERC721(address asset, uint256 tokenId, bytes calldata data) external virtual onlyOwner {
        require(canPullERC721(), "ZivoeLocker::pullFromLockerERC721() !canPullERC721()");
        IERC721(asset).safeTransferFrom(address(this), owner(), tokenId, data);
    }

    /// @notice Migrates ERC721s from owner() to locker.
    /// @param  assets The NFT contracts.
    /// @param  tokenIds The IDs of the NFTs to migrate.
    /// @param  data Accompanying transaction data.
    function pushToLockerMultiERC721(
        address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data
    ) external virtual onlyOwner {
        require(canPushMultiERC721(), "ZivoeLocker::pushToLockerMultiERC721() !canPushMultiERC721()");
        for (uint256 i = 0; i < assets.length; i++) {
           IERC721(assets[i]).safeTransferFrom(owner(), address(this), tokenIds[i], data[i]);
        }
    }

    /// @notice Migrates ERC721s from locker to owner().
    /// @param  assets The NFT contracts.
    /// @param  tokenIds The IDs of the NFTs to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerMultiERC721(
        address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data
    ) external virtual onlyOwner {
        require(canPullMultiERC721(), "ZivoeLocker::pullFromLockerMultiERC721() !canPullMultiERC721()");
        for (uint256 i = 0; i < assets.length; i++) {
           IERC721(assets[i]).safeTransferFrom(address(this), owner(), tokenIds[i], data[i]);
        }
    }

    /// @notice Migrates ERC1155 assets from owner() to locker.
    /// @param  asset The ERC1155 contract.
    /// @param  ids The IDs of the assets within the ERC1155 to migrate.
    /// @param  amounts The amounts to migrate.
    /// @param  data Accompanying transaction data.
    function pushToLockerERC1155(
        address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data
    ) external virtual onlyOwner {
        require(canPushERC1155(), "ZivoeLocker::pushToLockerERC1155() !canPushERC1155()");
        IERC1155(asset).safeBatchTransferFrom(owner(), address(this), ids, amounts, data);
    }

    /// @notice Migrates ERC1155 assets from locker to owner().
    /// @param  asset The ERC1155 contract.
    /// @param  ids The IDs of the assets within the ERC1155 to migrate.
    /// @param  amounts The amounts to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerERC1155(
        address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data
    ) external virtual onlyOwner {
        require(canPullERC1155(), "ZivoeLocker::pullFromLockerERC1155() !canPullERC1155()");
        IERC1155(asset).safeBatchTransferFrom(address(this), owner(), ids, amounts, data);
    }

}
