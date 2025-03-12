// SPDX-License-Identifier: GPL-3.0
// solhint-disable reason-string
pragma solidity ^0.8.20;

import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import {XPowerNft} from "./XPowerNft.sol";
import {XPowerPpt} from "./XPowerPpt.sol";
import {MoeTreasury} from "./MoeTreasury.sol";

/**
 * NFT treasury to stake and unstake XPowerNft(s).
 */
contract NftTreasury is ERC1155Holder {
    /** normal NFTs */
    XPowerNft private _nft;
    /** staked NFTs */
    XPowerPpt private _ppt;
    /** MOE treasury */
    MoeTreasury private _mty;

    /** @param nftLink address of contract for normal NFTs */
    /** @param pptLink address of contract for staked NFTs */
    /** @param mtyLink address of contract for MOE treasury */
    constructor(address nftLink, address pptLink, address mtyLink) {
        _nft = XPowerNft(nftLink);
        _ppt = XPowerPpt(pptLink);
        _mty = MoeTreasury(mtyLink);
    }

    /** emitted on staking an NFT */
    event Stake(address account, uint256 nftId, uint256 amount);

    /** stake NFT */
    function stake(address account, uint256 nftId, uint256 amount) external {
        require(
            (account == msg.sender || approvedStake(account, msg.sender)) && !_nft.migratable(),
            "caller is not token owner or approved"
        );
        _nft.safeTransferFrom(account, address(this), nftId, amount, "");
        _ppt.mint(account, nftId, amount);
        emit Stake(account, nftId, amount);
        _mty.refreshRates(false);
    }

    /** emitted on staking NFTs */
    event StakeBatch(address account, uint256[] nftIds, uint256[] amounts);

    /** stake NFTs */
    function stakeBatch(
        address account,
        uint256[] memory nftIds,
        uint256[] memory amounts
    ) external {
        require(
            (account == msg.sender || approvedStake(account, msg.sender)) && !_nft.migratable(),
            "caller is not token owner or approved"
        );
        _nft.safeBatchTransferFrom(account, address(this), nftIds, amounts, "");
        _ppt.mintBatch(account, nftIds, amounts);
        emit StakeBatch(account, nftIds, amounts);
        _mty.refreshRates(false);
    }

    /** approve staking by `operator` */
    function approveStake(address operator, bool approved) external {
        require(msg.sender != operator, "approving staking for self");
        _stakingApprovals[msg.sender][operator] = approved;
        emit ApproveStaking(msg.sender, operator, approved);
    }

    /** @return true if `account` approved staking by `operator` */
    function approvedStake(
        address account,
        address operator
    ) public view returns (bool) {
        return _stakingApprovals[account][operator];
    }

    /** staking approvals: account => operator */
    mapping(address => mapping(address => bool)) private _stakingApprovals;

    /**
     * emitted when `account` grants or revokes permission to
     * `operator` to stake their tokens according to `approved`
     */
    event ApproveStaking(
        address indexed account,
        address indexed operator,
        bool approved
    );

    /** emitted on unstaking an NFT */
    event Unstake(address account, uint256 nftId, uint256 amount);

    /** unstake NFT */
    function unstake(address account, uint256 nftId, uint256 amount) external {
        require(
            (account == msg.sender || approvedUnstake(account, msg.sender)) || _nft.migratable(),
            "caller is not token owner or approved"
        );
        _ppt.burn(account, nftId, amount);
        _nft.safeTransferFrom(address(this), account, nftId, amount, "");
        emit Unstake(account, nftId, amount);
        _mty.refreshRates(false);
    }

    /** emitted on unstaking NFTs */
    event UnstakeBatch(address account, uint256[] nftIds, uint256[] amounts);

    /** unstake NFTs */
    function unstakeBatch(
        address account,
        uint256[] memory nftIds,
        uint256[] memory amounts
    ) external {
        require(
            (account == msg.sender || approvedUnstake(account, msg.sender)) || _nft.migratable(),
            "caller is not token owner or approved"
        );
        _ppt.burnBatch(account, nftIds, amounts);
        _nft.safeBatchTransferFrom(address(this), account, nftIds, amounts, "");
        emit UnstakeBatch(account, nftIds, amounts);
        _mty.refreshRates(false);
    }

    /** approve unstaking by `operator` */
    function approveUnstake(address operator, bool approved) external {
        require(msg.sender != operator, "approving unstaking for self");
        _unstakingApprovals[msg.sender][operator] = approved;
        emit ApproveUnstaking(msg.sender, operator, approved);
    }

    /** @return true if `account` approved unstaking by `operator` */
    function approvedUnstake(
        address account,
        address operator
    ) public view returns (bool) {
        return _unstakingApprovals[account][operator];
    }

    /** unstaking approvals: account => operator */
    mapping(address => mapping(address => bool)) private _unstakingApprovals;

    /**
     * emitted when `account` grants or revokes permission to
     * `operator` to unstake their tokens according to `approved`
     */
    event ApproveUnstaking(
        address indexed account,
        address indexed operator,
        bool approved
    );
}
