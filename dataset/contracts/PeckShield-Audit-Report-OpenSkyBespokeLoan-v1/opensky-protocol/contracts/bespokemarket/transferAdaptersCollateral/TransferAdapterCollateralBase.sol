// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/utils/Context.sol';
//import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';
import '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import '../libraries/BespokeTypes.sol';
import '../../interfaces/IOpenSkySettings.sol';
import '../../interfaces/IACLManager.sol';
import '../../interfaces/IOpenSkyFlashClaimReceiver.sol';

import '../interfaces/IOpenSkyBespokeSettings.sol';
import '../interfaces/IOpenSkyBespokeMarket.sol';

import '../interfaces/ITransferAdapterCollateralBase.sol';
import '../interfaces/ITransferAdapterNFT.sol';

abstract contract TransferAdapterCollateralBase is
    Context,
    ReentrancyGuard,
    ERC721Holder,
    ERC1155Holder,
    ITransferAdapterCollateralBase,
    ITransferAdapterNFT
{
    using SafeERC20 for IERC20;

    IOpenSkySettings public immutable SETTINGS;
    IOpenSkyBespokeSettings public immutable BESPOKE_SETTINGS;

    // Add a protective layer to prevent collateral be claimed as airdrop
    // nftAddress=>amount
    mapping(address => uint256) public nftBorrowStat;

    constructor(address SETTINGS_, address BESPOKE_SETTINGS_) ReentrancyGuard() {
        SETTINGS = IOpenSkySettings(SETTINGS_);
        BESPOKE_SETTINGS = IOpenSkyBespokeSettings(BESPOKE_SETTINGS_);
    }

    modifier onlyMarket() {
        require(_msgSender() == BESPOKE_SETTINGS.marketAddress(), 'BM_ACL_ONLY_BESPOKR_MARKET_CAN_CALL');
        _;
    }

    /// @dev Only emergency admin can call functions marked by this modifier.
    modifier onlyEmergencyAdmin() {
        IACLManager ACLManager = IACLManager(SETTINGS.ACLManagerAddress());
        require(ACLManager.isEmergencyAdmin(_msgSender()), 'BM_ACL_ONLY_EMERGENCY_ADMIN_CAN_CALL');
        _;
    }

    modifier onlyAirdropOperator() {
        IACLManager ACLManager = IACLManager(SETTINGS.ACLManagerAddress());
        require(ACLManager.isAirdropOperator(_msgSender()), 'BM_ACL_ONLY_AIRDROP_OPERATOR_CAN_CALL');
        _;
    }
    
    /// @dev transfer ERC20 from the utility contract, for ERC20 recovery in case of stuck tokens due
    /// direct transfers to the contract address.
    /// @param token token to transfer
    /// @param to recipient of the transfer
    /// @param amount amount to send
    function emergencyTokenTransfer(
        address token,
        address to,
        uint256 amount
    ) external onlyEmergencyAdmin {
        IERC20(token).safeTransfer(to, amount);
    }

    function flashClaim(
        address receiverAddress,
        uint256[] calldata loanIds,
        bytes calldata params
    ) external override {
        uint256 i;
        IOpenSkyFlashClaimReceiver receiver = IOpenSkyFlashClaimReceiver(receiverAddress);
        // !!!CAUTION: receiver contract may reentry mint, burn, flashClaim again

        // only loan owner can do flashClaim
        address[] memory nftAddresses = new address[](loanIds.length);
        uint256[] memory tokenIds = new uint256[](loanIds.length);
        for (i = 0; i < loanIds.length; i++) {
            require(
                IERC721(BESPOKE_SETTINGS.borrowLoanAddress()).ownerOf(loanIds[i]) == _msgSender(),
                'BM_FLASHCLAIM_CALLER_IS_NOT_OWNER'
            );
            BespokeTypes.LoanData memory loanData = IOpenSkyBespokeMarket(BESPOKE_SETTINGS.marketAddress()).getLoanData(
                loanIds[i]
            );
            require(loanData.status != BespokeTypes.LoanStatus.LIQUIDATABLE, 'BM_FLASHCLAIM_STATUS_ERROR');
            nftAddresses[i] = loanData.tokenAddress;
            tokenIds[i] = loanData.tokenId;
        }

        // step 1: moving underlying asset forward to receiver contract
        for (i = 0; i < loanIds.length; i++) {
            IERC721(nftAddresses[i]).safeTransferFrom(address(this), receiverAddress, tokenIds[i]);
        }

        // setup 2: execute receiver contract, doing something like aidrop
        require(
            receiver.executeOperation(nftAddresses, tokenIds, _msgSender(), address(this), params),
            'BM_FLASHCLAIM_EXECUTOR_ERROR'
        );

        // setup 3: moving underlying asset backword from receiver contract
        for (i = 0; i < loanIds.length; i++) {
            IERC721(nftAddresses[i]).safeTransferFrom(receiverAddress, address(this), tokenIds[i]);
            emit FlashClaim(receiverAddress, _msgSender(), nftAddresses[i], tokenIds[i]);
        }
    }

    function claimERC20Airdrop(
        address token,
        address to,
        uint256 amount
    ) external override nonReentrant onlyAirdropOperator {
        IERC20(token).safeTransfer(to, amount);
        emit ClaimERC20Airdrop(token, to, amount);
    }

    function claimERC721Airdrop(
        address token,
        address to,
        uint256[] calldata ids
    ) external override nonReentrant onlyAirdropOperator {
        require(nftBorrowStat[token] == 0, 'BM_CLAIM_ERC721_AIRDROP_NOT_SUPPORTED');
        for (uint256 i = 0; i < ids.length; i++) {
            IERC721(token).safeTransferFrom(address(this), to, ids[i]);
        }
        emit ClaimERC721Airdrop(token, to, ids);
    }

    function claimERC1155Airdrop(
        address token,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external override nonReentrant onlyAirdropOperator {
        require(nftBorrowStat[token] == 0, 'BM_CLAIM_ERC1155_AIRDROP_NOT_SUPPORTED');
        IERC1155(token).safeBatchTransferFrom(address(this), to, ids, amounts, data);
        emit ClaimERC1155Airdrop(token, to, ids, amounts, data);
    }

    function transferCollateralIn(
        address collection,
        address from,
        uint256 tokenId,
        uint256 amount
    ) external override nonReentrant onlyMarket {
        nftBorrowStat[collection] += 1;
        _transferCollateralIn(collection, from, tokenId, amount);
    }

    function transferCollateralOut(
        address collection,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external override nonReentrant onlyMarket {
        nftBorrowStat[collection] -= 1;
        _transferCollateralOut(collection, to, tokenId, amount);
    }

    function transferCollateralOutOnForeclose(
        address collection,
        address to,
        uint256 tokenId,
        uint256 amount
    ) public override nonReentrant onlyMarket {
        nftBorrowStat[collection] -= 1;
        _transferCollateralOutOnForeclose(collection, to, tokenId, amount);
    }

    function _transferCollateralIn(
        address collection,
        address from,
        uint256 tokenId,
        uint256 amount
    ) internal virtual;

    function _transferCollateralOut(
        address collection,
        address from,
        uint256 tokenId,
        uint256 amount
    ) internal virtual;

    function _transferCollateralOutOnForeclose(
        address collection,
        address from,
        uint256 tokenId,
        uint256 amount
    ) internal virtual;
}
