// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./libraries/OwnableLocked.sol";

import "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";

interface ILocker_DAO {
    /// @notice Migrates specific amount of ERC20 from owner() to locker.
    /// @param  asset   The asset to migrate.
    /// @param  amount  The amount of "asset" to migrate.
    /// @param  data    Accompanying transaction data.
    function pushToLocker(address asset, uint256 amount, bytes calldata data) external;

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset   The asset to migrate.
    /// @param  data    Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external;

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset   The asset to migrate.
    /// @param  amount  The amount of "asset" to migrate.
    /// @param  data    Accompanying transaction data.
    function pullFromLockerPartial(address asset, uint256 amount, bytes calldata data) external;

    /// @notice Migrates specific amounts of ERC20s from owner() to locker.
    /// @param  assets  The assets to migrate.
    /// @param  amounts The amounts of "assets" to migrate, corresponds to "assets" by position in array.   
    /// @param  data    Accompanying transaction data.
    function pushToLockerMulti(address[] calldata assets, uint256[] calldata amounts, bytes[] calldata data) external;

    /// @notice Migrates full amount of ERC20s from locker to owner().
    /// @param  assets  The assets to migrate.
    /// @param  data    Accompanying transaction data.
    function pullFromLockerMulti(address[] calldata assets, bytes[] calldata data) external;

    /// @notice Migrates specific amounts of ERC20s from locker to owner().
    /// @param  assets  The assets to migrate.
    /// @param  amounts The amounts of "assets" to migrate, corresponds to "assets" by position in array.
    /// @param  data    Accompanying transaction data.
    function pullFromLockerMultiPartial(
        address[] calldata assets, uint256[] calldata amounts, bytes[] calldata data
    ) external;

    /// @notice Migrates an ERC721 from owner() to locker.
    /// @param  asset   The NFT contract.
    /// @param  tokenId The ID of the NFT to migrate.
    /// @param  data    Accompanying transaction data.  
    function pushToLockerERC721(address asset, uint256 tokenId, bytes calldata data) external;

    /// @notice Migrates an ERC721 from locker to owner().
    /// @param  asset   The NFT contract.
    /// @param  tokenId The ID of the NFT to migrate.
    /// @param  data    Accompanying transaction data.
    function pullFromLockerERC721(address asset, uint256 tokenId, bytes calldata data) external;

    /// @notice Migrates ERC721s from owner() to locker.
    /// @param  assets      The NFT contracts.
    /// @param  tokenIds    The IDs of the NFTs to migrate.
    /// @param  data        Accompanying transaction data.   
    function pushToLockerMultiERC721(
        address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data
    ) external;

    /// @notice Migrates ERC721s from locker to owner().
    /// @param  assets      The NFT contracts.
    /// @param  tokenIds    The IDs of the NFTs to migrate.
    /// @param  data        Accompanying transaction data.
    function pullFromLockerMultiERC721(
        address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data
    ) external;

    /// @notice Migrates ERC1155 assets from owner() to locker.
    /// @param  asset   The ERC1155 contract.
    /// @param  ids     The IDs of the assets within the ERC1155 to migrate.
    /// @param  amounts The amounts to migrate.
    /// @param  data    Accompanying transaction data.   
    function pushToLockerERC1155(
        address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data
    ) external;

    /// @notice Migrates ERC1155 assets from locker to owner().
    /// @param  asset   The ERC1155 contract.
    /// @param  ids     The IDs of the assets within the ERC1155 to migrate.
    /// @param  amounts The amounts to migrate.
    /// @param  data    Accompanying transaction data.
    function pullFromLockerERC1155(
        address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data
    ) external;

    /// @notice Permission for calling pushToLocker().
    function canPush() external view returns (bool);

    /// @notice Permission for calling pullFromLocker().  
    function canPull() external view returns (bool);

    /// @notice Permission for calling pullFromLockerPartial().
    function canPullPartial() external view returns (bool);

    /// @notice Permission for calling pushToLockerMulti().  
    function canPushMulti() external view returns (bool);

    /// @notice Permission for calling pullFromLockerMulti(). 
    function canPullMulti() external view returns (bool);

    /// @notice Permission for calling pullFromLockerMultiPartial().   
    function canPullMultiPartial() external view returns (bool);

    /// @notice Permission for calling pushToLockerERC721().
    function canPushERC721() external view returns (bool);

    /// @notice Permission for calling pullFromLockerERC721().
    function canPullERC721() external view returns (bool);

    /// @notice Permission for calling pushToLockerMultiERC721().
    function canPushMultiERC721() external view returns (bool);

    /// @notice Permission for calling pullFromLockerMultiERC721().    
    function canPullMultiERC721() external view returns (bool);

    /// @notice Permission for calling pushToLockerERC1155().    
    function canPushERC1155() external view returns (bool);

    /// @notice Permission for calling pullFromLockerERC1155().   
    function canPullERC1155() external view returns (bool);
}

interface IZivoeGlobals_DAO {
    /// @notice Returns "true" if a locker is whitelisted for DAO interactions and accounting accessibility.
    /// @param  locker  The address of the locker to check for.
    function isLocker(address locker) external view returns (bool);
}



/// @notice This contract escrows assets for the Zivoe protocol and is governed by TimelockController.
///         This contract MUST be owned by TimelockController. This ownership MUST be locked through OwnableLocked.
///         This contract MUST be capable of owning ERC721s & ERC1155s via ERC721Holder and ERC1155Holder.
///         This contract has the following responsibilities:
///          - Manage the asset(s) held in escrow:
///             - Push assets (ERC20, ERC721, ERC1155) to a locker.
///             - Pull assets (ERC20, ERC721, ERC1155) from a locker.
///          - MUST enforce a whitelist of lockers for pushing assets, MUST NOT enforce whitelist for pulling asset(s).
///          - MUST enforce validity of lockers when pushing or pulling through respective endpoint(s), i.e. canPush().
contract ZivoeDAO is ERC1155Holder, ERC721Holder, OwnableLocked, ReentrancyGuard {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;   /// @dev The ZivoeGlobals contract.



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeDAO contract.
    /// @param _GBL The ZivoeGlobals contract.
    constructor(address _GBL) { GBL = _GBL; }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during push() and pushMulti().
    /// @param  locker  The locker receiving "asset".
    /// @param  asset   The asset being pushed.
    /// @param  amount  The amount of "asset" being pushed.
    /// @param  data    Accompanying transaction data.
    event Pushed(address indexed locker, address indexed asset, uint256 amount, bytes data);

    /// @notice Emitted during pull() and pullMulti().
    /// @param  locker  The locker "asset" is pulled from.
    /// @param  asset   The asset being pulled.
    /// @param  data    Accompanying transaction data.
    event Pulled(address indexed locker, address indexed asset, bytes data);

    /// @notice Emitted during pullPartial() and pullMultiPartial().
    /// @param  locker  The locker "asset" is pulled from.
    /// @param  asset   The asset being pulled.
    /// @param  amount  The amount of "asset" being pulled (or could represent a percentage, in basis points).
    /// @param  data    Accompanying transaction data.
    event PulledPartial(address indexed locker, address indexed asset, uint256 amount, bytes data);

    /// @notice Emitted during pushERC721() and pushMultiERC721().
    /// @param  locker  The locker receiving "asset".
    /// @param  asset   The ERC721 contract.
    /// @param  tokenId The ID for a given "asset" / NFT.
    /// @param  data    Accompanying data for the transaction.
    event PushedERC721(address indexed locker, address indexed asset, uint256 indexed tokenId, bytes data);
    
    /// @notice Emitted during pullERC721() and pullMultiERC721().
    /// @param  locker  The locker "assets" are pulled from.
    /// @param  asset   The ERC721 contract.
    /// @param  tokenId The ID for a given "asset" / NFT.
    /// @param  data    Accompanying data for the transaction.
    event PulledERC721(address indexed locker, address indexed asset, uint256 indexed tokenId, bytes data);
    
    /// @notice Emitted during pushERC1155().
    /// @param  locker  The locker receiving "asset".
    /// @param  asset   The ERC1155 contract.
    /// @param  ids     The IDs for a given "asset" (ERC1155), corresponds to "amounts".
    /// @param  amounts The amount of "id" to transfer.
    /// @param  data    Accompanying data for the transaction.
    event PushedERC1155(address indexed locker, address indexed asset, uint256[] ids, uint256[] amounts, bytes data);

    /// @notice Emitted during pullERC1155().
    /// @param  locker  The locker "asset" is pulled from.
    /// @param  asset   The ERC1155 contract.
    /// @param  ids     The IDs for a given "asset" (ERC1155), corresponds to "amounts".
    /// @param  amounts The amount of "id" to transfer.
    /// @param  data    Accompanying data for the transaction.
    event PulledERC1155(address indexed locker, address indexed asset, uint256[] ids, uint256[] amounts, bytes data);

    

    // ----------------
    //    Functions
    // ----------------

    /// @notice Pushes an ERC20 token from ZivoeDAO to locker.
    /// @dev    Only the owner (TimelockController) can call this. MUST be marked onlyOwner and nonReentrant.
    /// @param  locker  The locker to push an ERC20 token to.
    /// @param  asset   The ERC20 token to push.
    /// @param  amount  The amount of "asset" to push.
    /// @param  data    Accompanying transaction data.
    function push(address locker, address asset, uint256 amount, bytes calldata data) external onlyOwner nonReentrant {
        require(IZivoeGlobals_DAO(GBL).isLocker(locker), "ZivoeDAO::push() !IZivoeGlobals_DAO(GBL).isLocker(locker)");
        require(ILocker_DAO(locker).canPush(), "ZivoeDAO::push() !ILocker_DAO(locker).canPush()");
        emit Pushed(locker, asset, amount, data);
        IERC20(asset).safeIncreaseAllowance(locker, amount);
        ILocker_DAO(locker).pushToLocker(asset, amount, data);
        // ZivoeDAO MUST ensure "locker" has 0 allowance before this function concludes.
        if (IERC20(asset).allowance(address(this), locker) > 0) { 
            IERC20(asset).safeDecreaseAllowance(locker, IERC20(asset).allowance(address(this), locker)); 
        }
    }

    /// @notice Pulls ERC20 from locker to ZivoeDAO.
    /// @dev    This function SHOULD pull the entire balance of "asset" from the locker.
    /// @dev    Only the owner (TimelockController) can call this. MUST be marked onlyOwner and nonReentrant.
    /// @param  locker  The locker to pull from.
    /// @param  asset   The asset to pull.
    /// @param  data    Accompanying transaction data.
    function pull(address locker, address asset, bytes calldata data) external onlyOwner nonReentrant {
        require(ILocker_DAO(locker).canPull(), "ZivoeDAO::pull() !ILocker_DAO(locker).canPull()");
        emit Pulled(locker, asset, data);
        ILocker_DAO(locker).pullFromLocker(asset, data);
    }

    /// @notice Pulls specific amount of ERC20 from locker to ZivoeDAO.
    /// @dev    The input "amount" might represent a ratio, BIPS, or an absolute amount, depending on the context.
    /// @dev    Only the owner (TimelockController) can call this. MUST be marked onlyOwner and nonReentrant.
    /// @param  locker  The locker to pull from.
    /// @param  asset   The asset to pull.
    /// @param  amount  The amount to pull (may not refer to "asset", but rather a different asset within the locker).
    /// @param  data    Accompanying transaction data.
    function pullPartial(
        address locker, address asset, uint256 amount, bytes calldata data
    ) external onlyOwner nonReentrant {
        require(ILocker_DAO(locker).canPullPartial(), "ZivoeDAO::pullPartial() !ILocker_DAO(locker).canPullPartial()");
        emit PulledPartial(locker, asset, amount, data);
        ILocker_DAO(locker).pullFromLockerPartial(asset, amount, data);
    }

    /// @notice Pushes ERC20(s) from locker to ZivoeDAO.
    /// @dev    Only the owner (TimelockController) can call this. MUST be marked onlyOwner and nonReentrant.
    /// @param  locker  The locker to push capital to.
    /// @param  assets  The assets to push to locker.
    /// @param  amounts The amount of "asset" to push.
    /// @param  data    Accompanying transaction data.
    function pushMulti(
        address locker, address[] calldata assets, uint256[] calldata amounts, bytes[] calldata data
    ) external onlyOwner nonReentrant {
        require(
            IZivoeGlobals_DAO(GBL).isLocker(locker), 
            "ZivoeDAO::pushMulti() !IZivoeGlobals_DAO(GBL).isLocker(locker)"
        );
        require(assets.length == amounts.length, "ZivoeDAO::pushMulti() assets.length != amounts.length");
        require(amounts.length == data.length, "ZivoeDAO::pushMulti() amounts.length != data.length");
        require(ILocker_DAO(locker).canPushMulti(), "ZivoeDAO::pushMulti() !ILocker_DAO(locker).canPushMulti()");
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeIncreaseAllowance(locker, amounts[i]);
            emit Pushed(locker, assets[i], amounts[i], data[i]);
        }
        ILocker_DAO(locker).pushToLockerMulti(assets, amounts, data);
        for (uint256 i = 0; i < assets.length; i++) {
            // ZivoeDAO MUST ensure "locker" has 0 allowance for each ERC20 token before this function concludes.
            if (IERC20(assets[i]).allowance(address(this), locker) > 0) { 
                IERC20(assets[i]).safeDecreaseAllowance(locker, IERC20(assets[i]).allowance(address(this), locker));
             }
        }
    }

    /// @notice Pulls ERC20(s) from locker to ZivoeDAO.
    /// @dev    This function SHOULD pull the entire balance of each "asset" from the locker.
    /// @dev    Only the owner (TimelockController) can call this. MUST be marked onlyOwner and nonReentrant.
    /// @param  locker  The locker to pull from.
    /// @param  assets  The assets to pull.
    /// @param  data    Accompanying transaction data.
    function pullMulti(
        address locker, address[] calldata assets, bytes[] calldata data
    ) external onlyOwner nonReentrant {
        require(ILocker_DAO(locker).canPullMulti(), "ZivoeDAO::pullMulti() !ILocker_DAO(locker).canPullMulti()");
        require(assets.length == data.length, "ZivoeDAO::pullMulti() assets.length != data.length");
        for (uint256 i = 0; i < assets.length; i++) { emit Pulled(locker, assets[i], data[i]); }
        ILocker_DAO(locker).pullFromLockerMulti(assets, data);
    }

    /// @notice Pulls specific amount(s) of ERC20(s) from locker to ZivoeDAO.
    /// @dev    The input "amounts" might represent a ratio, BIPS, or an absolute amount, depending on the context.
    /// @dev    Only the owner (TimelockController) can call this. MUST be marked onlyOwner and nonReentrant.
    /// @param  locker  The locker to pull from.
    /// @param  assets  The asset(s) to pull.
    /// @param  amounts The amount(s) to pull (may not refer to "asset", rather a different asset within the locker).
    /// @param  data    Accompanying transaction data.
    function pullMultiPartial(
        address locker, address[] calldata assets, uint256[] calldata amounts, bytes[] calldata data
    ) external onlyOwner nonReentrant {
        require(
            ILocker_DAO(locker).canPullMultiPartial(), 
            "ZivoeDAO::pullMultiPartial() !ILocker_DAO(locker).canPullMultiPartial()"
        );
        require(assets.length == amounts.length, "ZivoeDAO::pullMultiPartial() assets.length != amounts.length");
        require(amounts.length == data.length, "ZivoeDAO::pullMultiPartial() amounts.length != data.length");
        for (uint256 i = 0; i < assets.length; i++) { emit PulledPartial(locker, assets[i], amounts[i], data[i]); }
        ILocker_DAO(locker).pullFromLockerMultiPartial(assets, amounts, data);
    }

    /// @notice Pushes an NFT from ZivoeDAO to locker.
    /// @dev    Only the owner (TimelockController) can call this. MUST be marked onlyOwner and nonReentrant.
    /// @param  locker  The locker to push an NFT to.
    /// @param  asset   The NFT contract.
    /// @param  tokenId The NFT tokenId to push.
    /// @param  data    Accompanying data for the transaction.
    function pushERC721(
        address locker, address asset, uint256 tokenId, bytes calldata data
    ) external onlyOwner nonReentrant {
        require(
            IZivoeGlobals_DAO(GBL).isLocker(locker), 
            "ZivoeDAO::pushERC721() !IZivoeGlobals_DAO(GBL).isLocker(locker)"
        );
        require(ILocker_DAO(locker).canPushERC721(), "ZivoeDAO::pushERC721() !ILocker_DAO(locker).canPushERC721()");
        emit PushedERC721(locker, asset, tokenId, data);
        IERC721(asset).approve(locker, tokenId);
        ILocker_DAO(locker).pushToLockerERC721(asset, tokenId, data);
        // ZivoeDAO MUST ensure "locker" has consumed its allowance during pushToLockerERC721().
        assert(IERC721(asset).getApproved(tokenId) == address(0));
    }

    /// @notice Pushes NFT(s) from ZivoeDAO to locker.
    /// @dev    Only the owner (TimelockController) can call this. MUST be marked onlyOwner and nonReentrant.
    /// @param  locker      The locker to push NFTs to.
    /// @param  assets      The NFT contract(s).
    /// @param  tokenIds    The NFT tokenId(s) to push.
    /// @param  data        Accompanying data for the transaction(s).
    function pushMultiERC721(
        address locker, address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data
    ) external onlyOwner nonReentrant {
        require(
            IZivoeGlobals_DAO(GBL).isLocker(locker), 
            "ZivoeDAO::pushMultiERC721() !IZivoeGlobals_DAO(GBL).isLocker(locker)"
        );
        require(assets.length == tokenIds.length, "ZivoeDAO::pushMultiERC721() assets.length != tokenIds.length");
        require(tokenIds.length == data.length, "ZivoeDAO::pushMultiERC721() tokenIds.length != data.length");
        require(
            ILocker_DAO(locker).canPushMultiERC721(), 
            "ZivoeDAO::pushMultiERC721() !ILocker_DAO(locker).canPushMultiERC721()"
        );
        for (uint256 i = 0; i < assets.length; i++) {
            IERC721(assets[i]).approve(locker, tokenIds[i]);
            emit PushedERC721(locker, assets[i], tokenIds[i], data[i]);
        }
        ILocker_DAO(locker).pushToLockerMultiERC721(assets, tokenIds, data);
        for (uint256 i = 0; i < assets.length; i++) {
            // ZivoeDAO MUST ensure "locker" has consumed its allowance during pushToLockerMultiERC721().
            assert(IERC721(assets[i]).getApproved(tokenIds[i]) == address(0));
        }
    }

    /// @notice Pulls an NFT from locker to ZivoeDAO.
    /// @dev    Only the owner (TimelockController) can call this. MUST be marked onlyOwner and nonReentrant.
    /// @param  locker  The locker to pull from.
    /// @param  asset   The NFT contract.
    /// @param  tokenId The NFT tokenId to pull.
    /// @param  data    Accompanying data for the transaction.
    function pullERC721(
        address locker, address asset, uint256 tokenId, bytes calldata data
    ) external onlyOwner nonReentrant {
        require(ILocker_DAO(locker).canPullERC721(), "ZivoeDAO::pullERC721() !ILocker_DAO(locker).canPullERC721()");
        emit PulledERC721(locker, asset, tokenId, data);
        ILocker_DAO(locker).pullFromLockerERC721(asset, tokenId, data);
    }

    /// @notice Pulls NFT(s) from locker to ZivoeDAO.
    /// @dev    Only the owner (TimelockController) can call this. MUST be marked onlyOwner and nonReentrant.
    /// @param  locker      The locker to pull from.
    /// @param  assets      The NFT contract(s).
    /// @param  tokenIds    The NFT tokenId(s) to pull.
    /// @param  data        Accompanying data for the transaction(s).
    function pullMultiERC721(
        address locker, address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data
    ) external onlyOwner nonReentrant {
        require(
            ILocker_DAO(locker).canPullMultiERC721(), 
            "ZivoeDAO::pullMultiERC721() !ILocker_DAO(locker).canPullMultiERC721()"
        );
        require(assets.length == tokenIds.length, "ZivoeDAO::pullMultiERC721() assets.length != tokenIds.length");
        require(tokenIds.length == data.length, "ZivoeDAO::pullMultiERC721() tokenIds.length != data.length");
        for (uint256 i = 0; i < assets.length; i++) { emit PulledERC721(locker, assets[i], tokenIds[i], data[i]); }
        ILocker_DAO(locker).pullFromLockerMultiERC721(assets, tokenIds, data);
    }

    /// @notice Pushes ERC1155 assets from ZivoeDAO to locker.
    /// @dev    Only the owner (TimelockController) can call this. MUST be marked onlyOwner and nonReentrant.
    /// @param  locker  The locker to push ERC1155 assets to.
    /// @param  asset   The ERC1155 asset to push to locker.
    /// @param  ids     The ids of "assets" to push.
    /// @param  amounts The amounts of "assets" to push.
    /// @param  data    Accompanying data for the transaction.
    function pushERC1155(
        address locker, address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data
    ) external onlyOwner nonReentrant {
        require(
            IZivoeGlobals_DAO(GBL).isLocker(locker), 
            "ZivoeDAO::pushERC1155() !IZivoeGlobals_DAO(GBL).isLocker(locker)"
        );
        require(
            ILocker_DAO(locker).canPushERC1155(), 
            "ZivoeDAO::pushERC1155() !ILocker_DAO(locker).canPushERC1155()"
        );
        require(ids.length == amounts.length, "ZivoeDAO::pushERC1155() ids.length != amounts.length");
        emit PushedERC1155(locker, asset, ids, amounts, data);
        IERC1155(asset).setApprovalForAll(locker, true);
        ILocker_DAO(locker).pushToLockerERC1155(asset, ids, amounts, data);
        // ZivoeDAO MUST ensure "locker" has 0 allowance for "asset" (ERC1155) before this function concludes.
        IERC1155(asset).setApprovalForAll(locker, false);
    }

    /// @notice Pulls ERC1155 assets from locker to ZivoeDAO.
    /// @dev    Only the owner (TimelockController) can call this. MUST be marked onlyOwner and nonReentrant.
    /// @param  locker  The locker to pull from.
    /// @param  asset   The ERC1155 asset to pull.
    /// @param  ids     The ids of "assets" to pull.
    /// @param  amounts The amounts of "assets" to pull.
    /// @param  data    Accompanying data for the transaction.
    function pullERC1155(
        address locker, address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data
    ) external onlyOwner nonReentrant {
        require(
            ILocker_DAO(locker).canPullERC1155(), 
            "ZivoeDAO::pullERC1155() !ILocker_DAO(locker).canPullERC1155()"
        );
        require(ids.length == amounts.length, "ZivoeDAO::pullERC1155() ids.length != amounts.length");
        emit PulledERC1155(locker, asset, ids, amounts, data);
        ILocker_DAO(locker).pullFromLockerERC1155(asset, ids, amounts, data);
    }

}
