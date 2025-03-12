// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "./tokens/ERC1155/SuperfineNFT1155.sol";

contract SuperfineNFTStaking is
    ERC721Holder,
    ERC1155Holder,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    enum NFTType {
        ERC721,
        ERC1155
    }

    struct StakingInfo {
        uint256 numStakedNFTs;
        uint256 lastActionMoment;
        // Mapping from an NFT address to a list of staked tokenIds
        mapping(address => uint256[]) stakedTokenIds;
        // Mapping from an NFT (NFT address + token ID) to its staked quantity
        mapping(address => mapping(uint256 => uint256)) stakedQuantityOf;
        // Mapping from an NFT (NFT address + token ID) to a moment when that NFT is staked
        mapping(address => mapping(uint256 => uint256)) stakingMomentOf;
    }

    struct NFTInfo {
        NFTType nftType;
        address nftAddress;
        uint256 tokenId;
        uint256 quantity;
        uint256 stakingMoment;
    }

    struct WhitelistedNFT {
        NFTType nftType;
        address nftAddress;
    }

    uint256 public lockDuration;
    uint256 public rewardPerDay;
    address public rewardToken;
    uint256 private _totalStakedNFTs;
    mapping(address => NFTType) private _typeOf;
    mapping(address => StakingInfo) private _stakingInfoOf;
    mapping(address => bool) private _operators;
    mapping(address => uint256) private _savingOf;
    mapping(address => uint256) private _numStakedNFTs;

    // Whitelist
    address[] private _erc721Whitelist;
    address[] private _erc1155Whitelist;
    mapping(address => bool) private _isERC721Whitelisted;
    mapping(address => bool) private _isERC1155Whitelisted;

    event NFTStaked(
        address participant,
        address nftAddress,
        uint256 tokenId,
        uint256 quantity
    );
    event NFTUnstaked(
        address participant,
        address nftAddress,
        uint256 tokenId,
        uint256 quantity
    );
    event RewardClaimed(address participant, uint256 rewardAmount);
    event EmergencyWithdrawn(address recipient, uint256 amount);

    receive() external payable {}

    constructor(
        uint256 lockDuration_,
        uint256 rewardPerDay_,
        address rewardToken_
    ) {
        lockDuration = lockDuration_;
        rewardPerDay = rewardPerDay_;
        rewardToken = rewardToken_;
        _operators[msg.sender] = true;
    }

    modifier onlyOperator() {
        require(
            _operators[msg.sender],
            "SuperfineNFTStaking: caller is not operator"
        );
        _;
    }

    function getCurrentReward(
        address participant
    ) public view returns (uint256) {
        StakingInfo storage stakingInfo = _stakingInfoOf[participant];
        uint256 elapsedTime = block.timestamp - stakingInfo.lastActionMoment;
        if (_totalStakedNFTs == 0) return 0;
        return
            _savingOf[participant] +
            (elapsedTime * rewardPerDay * stakingInfo.numStakedNFTs) /
            _totalStakedNFTs /
            1 days;
    }

    function estimateDailyReward(
        address participant
    ) external view returns (uint256) {
        StakingInfo storage stakingInfo = _stakingInfoOf[participant];
        if (_totalStakedNFTs == 0) return 0;
        return (rewardPerDay * stakingInfo.numStakedNFTs) / _totalStakedNFTs;
    }

    function getNFTWhitelist() external view returns (WhitelistedNFT[] memory) {
        WhitelistedNFT[] memory whitelist = new WhitelistedNFT[](
            _erc721Whitelist.length + _erc1155Whitelist.length
        );
        for (uint256 i = 0; i < _erc721Whitelist.length; i++)
            whitelist[i] = WhitelistedNFT(NFTType.ERC721, _erc721Whitelist[i]);
        for (uint256 j = 0; j < _erc1155Whitelist.length; j++)
            whitelist[j + _erc721Whitelist.length] = WhitelistedNFT(
                NFTType.ERC1155,
                _erc1155Whitelist[j]
            );
        return whitelist;
    }

    function getStakedNFTs(
        address participant
    ) external view returns (NFTInfo[] memory) {
        uint256 numStakedNFTs = 0;

        // Get the number of staked ERC721 NFTs
        for (uint256 i = 0; i < _erc721Whitelist.length; i++)
            numStakedNFTs += _stakingInfoOf[participant]
                .stakedTokenIds[_erc721Whitelist[i]]
                .length;

        // Get the number of staked ERC1155 NFTs
        for (uint256 j = 0; j < _erc1155Whitelist.length; j++)
            numStakedNFTs += _stakingInfoOf[participant]
                .stakedTokenIds[_erc1155Whitelist[j]]
                .length;

        NFTInfo[] memory stakedNFTs = new NFTInfo[](numStakedNFTs);
        uint256 nftCount = 0;

        // Get staked ERC721 NFTs
        for (uint256 i = 0; i < _erc721Whitelist.length; i++) {
            address nftAddress = _erc721Whitelist[i];
            uint256[] memory stakedTokenIds = _stakingInfoOf[participant]
                .stakedTokenIds[nftAddress];
            for (uint256 j = 0; j < stakedTokenIds.length; j++) {
                uint256 tokenId = stakedTokenIds[j];
                uint256 stakingMoment = _stakingInfoOf[participant]
                    .stakingMomentOf[nftAddress][tokenId];
                stakedNFTs[nftCount] = NFTInfo(
                    NFTType.ERC721,
                    nftAddress,
                    tokenId,
                    1,
                    stakingMoment
                );
                nftCount++;
            }
        }

        // Get staked ERC1155 NFTs
        for (uint256 k = 0; k < _erc1155Whitelist.length; k++) {
            address nftAddress = _erc1155Whitelist[k];
            uint256[] memory stakedTokenIds = _stakingInfoOf[participant]
                .stakedTokenIds[nftAddress];
            for (uint256 l = 0; l < stakedTokenIds.length; l++) {
                uint256 tokenId = stakedTokenIds[l];
                uint256 quantity = _stakingInfoOf[participant].stakedQuantityOf[
                    nftAddress
                ][tokenId];
                uint256 stakingMoment = _stakingInfoOf[participant]
                    .stakingMomentOf[nftAddress][tokenId];
                stakedNFTs[nftCount] = NFTInfo(
                    NFTType.ERC1155,
                    nftAddress,
                    tokenId,
                    quantity,
                    stakingMoment
                );
                nftCount++;
            }
        }

        return stakedNFTs;
    }

    function getUnstakedNFTs(
        address participant
    ) external view returns (NFTInfo[] memory) {
        uint256 numUnstakedNFTs = 0;

        // Get the number of owned ERC721 NFTs
        for (uint256 i = 0; i < _erc721Whitelist.length; i++)
            numUnstakedNFTs += ERC721Enumerable(_erc721Whitelist[i]).balanceOf(
                participant
            );

        // Get the number of owned ERC1155 NFTs
        for (uint256 i = 0; i < _erc1155Whitelist.length; i++)
            numUnstakedNFTs += SuperfineNFT1155(_erc1155Whitelist[i])
                .getAllOwnedTokens(participant)
                .length;

        NFTInfo[] memory unstakedNFTs = new NFTInfo[](numUnstakedNFTs);
        uint256 nftCount = 0;

        // Get unstaked ERC721 NFTs
        for (uint256 i = 0; i < _erc721Whitelist.length; i++) {
            address nftAddress = _erc721Whitelist[i];
            ERC721Enumerable nftContract = ERC721Enumerable(nftAddress);
            uint256 numOwnedNFTs = nftContract.balanceOf(participant);
            for (uint256 index = 0; index < numOwnedNFTs; index++) {
                uint256 tokenId = nftContract.tokenOfOwnerByIndex(
                    participant,
                    index
                );
                unstakedNFTs[nftCount] = NFTInfo(
                    NFTType.ERC721,
                    nftAddress,
                    tokenId,
                    1,
                    0
                );
                nftCount++;
            }
        }

        // Get unstaked ERC1155 NFTs
        for (uint256 i = 0; i < _erc1155Whitelist.length; i++) {
            SuperfineNFT1155 nftContract = SuperfineNFT1155(
                _erc1155Whitelist[i]
            );
            SuperfineNFT1155.TokenInfo[] memory ownedNFT1155s = nftContract
                .getAllOwnedTokens(participant);
            for (uint256 j = 0; j < ownedNFT1155s.length; j++) {
                unstakedNFTs[nftCount] = NFTInfo(
                    NFTType.ERC1155,
                    address(nftContract),
                    ownedNFT1155s[j].tokenId,
                    ownedNFT1155s[j].quantity,
                    0
                );
                nftCount++;
            }
        }

        return unstakedNFTs;
    }

    function setOperators(
        address[] memory operators,
        bool[] memory isOperators
    ) external onlyOwner {
        require(
            operators.length == isOperators.length,
            "SuperfineNFTStaking: lengths mismatch"
        );
        for (uint256 i = 0; i < operators.length; i++)
            _operators[operators[i]] = isOperators[i];
    }

    function setLockDuration(uint256 lockDuration_) external onlyOperator {
        lockDuration = lockDuration_;
    }

    function setRewardPerDay(uint256 rewardPerDay_) external onlyOperator {
        rewardPerDay = rewardPerDay_;
    }

    function setRewardToken(address rewardToken_) external onlyOperator {
        rewardToken = rewardToken_;
    }

    function whitelistNFT(
        address[] calldata nftAddresses,
        NFTType[] calldata types
    ) external onlyOperator {
        require(
            nftAddresses.length == types.length,
            "SuperfineNFTStaking: lengths mismatch"
        );

        for (uint256 i = 0; i < nftAddresses.length; i++) {
            address nftAddress = nftAddresses[i];
            bool success = ERC165Checker.supportsERC165(nftAddress);
            if (success)
                if (types[i] == NFTType.ERC721)
                    success = IERC165(nftAddress).supportsInterface(
                        type(IERC721).interfaceId
                    );
                else if (types[i] == NFTType.ERC1155)
                    success = IERC165(nftAddress).supportsInterface(
                        type(IERC1155).interfaceId
                    );
            require(
                success,
                "SuperfineNFTStaking: cannot whitelist non-NFT address"
            );
            _typeOf[nftAddress] = types[i];
            if (types[i] == NFTType.ERC721) {
                _isERC721Whitelisted[nftAddress] = true;
                bool addedBefore = false;
                for (uint256 j = 0; j < _erc721Whitelist.length; j++)
                    if (_erc721Whitelist[j] == nftAddress) {
                        addedBefore = true;
                        break;
                    }
                if (!addedBefore) _erc721Whitelist.push(nftAddress);
            } else if (types[i] == NFTType.ERC1155) {
                _isERC1155Whitelisted[nftAddress] = true;
                bool addedBefore = false;
                for (uint256 k = 0; k < _erc1155Whitelist.length; k++)
                    if (_erc1155Whitelist[k] == nftAddress) {
                        addedBefore = true;
                        break;
                    }
                if (!addedBefore) _erc1155Whitelist.push(nftAddress);
            }
        }
    }

    function unwhitelistNFT(
        address[] calldata nftAddresses
    ) external onlyOperator {
        for (uint256 i = 0; i < nftAddresses.length; i++) {
            address nftAddress = nftAddresses[i];
            require(
                _numStakedNFTs[nftAddress] == 0,
                "SuperfineNFTStaking: NFTs still staked"
            );
            if (_isERC721Whitelisted[nftAddress]) {
                _isERC721Whitelisted[nftAddress] = false;
                for (uint256 j = 0; j < _erc721Whitelist.length; j++)
                    if (_erc721Whitelist[j] == nftAddress) {
                        _erc721Whitelist[j] = _erc721Whitelist[
                            _erc721Whitelist.length - 1
                        ];
                        _erc721Whitelist.pop();
                        break;
                    }
            }
            if (_isERC1155Whitelisted[nftAddress]) {
                _isERC1155Whitelisted[nftAddress] = false;
                for (uint256 k = 0; k < _erc1155Whitelist.length; k++)
                    if (_erc1155Whitelist[k] == nftAddress) {
                        _erc1155Whitelist[k] = _erc1155Whitelist[
                            _erc1155Whitelist.length - 1
                        ];
                        _erc1155Whitelist.pop();
                        break;
                    }
            }
        }
    }

    function stake(
        address[] memory nftAddresses,
        uint256[] memory tokenIds,
        uint256[] memory quantities
    ) external whenNotPaused nonReentrant {
        require(
            nftAddresses.length == tokenIds.length &&
                nftAddresses.length == quantities.length,
            "SuperfineNFTStaking: lengths mismatch"
        );
        for (uint256 i = 0; i < nftAddresses.length; i++)
            _stake(nftAddresses[i], tokenIds[i], quantities[i]);
    }

    function unstake(
        address[] memory nftAddresses,
        uint256[] memory tokenIds,
        uint256[] memory quantities
    ) external whenNotPaused nonReentrant {
        require(
            nftAddresses.length == tokenIds.length &&
                nftAddresses.length == quantities.length,
            "SuperfineNFTStaking: lengths mismatch"
        );
        for (uint256 i = 0; i < nftAddresses.length; i++)
            _unstake(nftAddresses[i], tokenIds[i], quantities[i]);
    }

    function _stake(
        address nftAddress,
        uint256 tokenId,
        uint256 quantity
    ) private {
        require(
            _isERC721Whitelisted[nftAddress] ||
                _isERC1155Whitelisted[nftAddress],
            "SuperfineNFTStaking: this NFT is not supported"
        );
        require(quantity > 0, "SuperfineNFTStaking: stake nothing");
        _savingOf[msg.sender] = getCurrentReward(msg.sender);
        StakingInfo storage stakingInfo = _stakingInfoOf[msg.sender];
        if (_typeOf[nftAddress] == NFTType.ERC721) {
            require(
                quantity == 1,
                "SuperfineNFTStaking: cannot stake more than 1 ERC721 NFT at a time"
            );
            ERC721Enumerable(nftAddress).safeTransferFrom(
                msg.sender,
                address(this),
                tokenId
            );
            stakingInfo.stakedTokenIds[nftAddress].push(tokenId);
            stakingInfo.stakedQuantityOf[nftAddress][tokenId] = 1;
            stakingInfo.stakingMomentOf[nftAddress][tokenId] = block.timestamp;
        } else if (_typeOf[nftAddress] == NFTType.ERC1155) {
            IERC1155(nftAddress).safeTransferFrom(
                msg.sender,
                address(this),
                tokenId,
                quantity,
                ""
            );
            if (stakingInfo.stakedQuantityOf[nftAddress][tokenId] == 0)
                stakingInfo.stakedTokenIds[nftAddress].push(tokenId);
            stakingInfo.stakedQuantityOf[nftAddress][tokenId] += quantity;
            stakingInfo.stakingMomentOf[nftAddress][tokenId] = block.timestamp;
        }
        stakingInfo.lastActionMoment = block.timestamp;
        stakingInfo.numStakedNFTs += quantity;
        _totalStakedNFTs += quantity;
        _numStakedNFTs[nftAddress] += quantity;
        emit NFTStaked(msg.sender, nftAddress, tokenId, quantity);
    }

    function _unstake(
        address nftAddress,
        uint256 tokenId,
        uint256 quantity
    ) private {
        require(
            _isERC721Whitelisted[nftAddress] ||
                _isERC1155Whitelisted[nftAddress],
            "SuperfineNFTStaking: this NFT is not supported"
        );
        require(quantity > 0, "SuperfineNFTStaking: unstake nothing");
        _savingOf[msg.sender] = getCurrentReward(msg.sender);
        StakingInfo storage stakingInfo = _stakingInfoOf[msg.sender];
        require(
            block.timestamp >=
                stakingInfo.stakingMomentOf[nftAddress][tokenId] + lockDuration,
            "SuperfineNFTStaking: NFT not unlocked yet"
        );
        if (_typeOf[nftAddress] == NFTType.ERC721) {
            require(
                quantity == 1,
                "SuperfineNFTStaking: cannot unstake more than 1 ERC721 NFT at a time"
            );
            require(
                stakingInfo.stakedQuantityOf[nftAddress][tokenId] == 1,
                "SuperfineNFTStaking: only owner can unstake"
            );
            ERC721Enumerable(nftAddress).safeTransferFrom(
                address(this),
                msg.sender,
                tokenId
            );
            for (
                uint256 i = 0;
                i < stakingInfo.stakedTokenIds[nftAddress].length;
                i++
            )
                if (stakingInfo.stakedTokenIds[nftAddress][i] == tokenId) {
                    stakingInfo.stakedTokenIds[nftAddress][i] = stakingInfo
                        .stakedTokenIds[nftAddress][
                            stakingInfo.stakedTokenIds[nftAddress].length - 1
                        ];
                    stakingInfo.stakedTokenIds[nftAddress].pop();
                    break;
                }
            stakingInfo.stakedQuantityOf[nftAddress][tokenId] = 0;
            stakingInfo.stakingMomentOf[nftAddress][tokenId] = 0;
        } else if (_typeOf[nftAddress] == NFTType.ERC1155) {
            require(
                stakingInfo.stakedQuantityOf[nftAddress][tokenId] >= quantity,
                "SuperfineNFTStaking: not enough NFTs to unstake"
            );
            IERC1155(nftAddress).safeTransferFrom(
                address(this),
                msg.sender,
                tokenId,
                quantity,
                ""
            );
            stakingInfo.stakedQuantityOf[nftAddress][tokenId] -= quantity;
            if (stakingInfo.stakedQuantityOf[nftAddress][tokenId] == 0) {
                stakingInfo.stakingMomentOf[nftAddress][tokenId] = 0;
                for (
                    uint256 i = 0;
                    i < stakingInfo.stakedTokenIds[nftAddress].length;
                    i++
                )
                    if (stakingInfo.stakedTokenIds[nftAddress][i] == tokenId) {
                        stakingInfo.stakedTokenIds[nftAddress][i] = stakingInfo
                            .stakedTokenIds[nftAddress][
                                stakingInfo.stakedTokenIds[nftAddress].length -
                                    1
                            ];
                        stakingInfo.stakedTokenIds[nftAddress].pop();
                        break;
                    }
            }
        }
        stakingInfo.lastActionMoment = block.timestamp;
        stakingInfo.numStakedNFTs -= quantity;
        _totalStakedNFTs -= quantity;
        _numStakedNFTs[nftAddress] -= quantity;
        emit NFTUnstaked(msg.sender, nftAddress, tokenId, quantity);
    }

    function claimReward() external whenNotPaused {
        uint256 reward = getCurrentReward(msg.sender);
        if (reward == 0) return;
        _stakingInfoOf[msg.sender].lastActionMoment = block.timestamp;
        delete _savingOf[msg.sender];
        if (rewardToken == address(0)) {
            (bool success, ) = payable(msg.sender).call{value: reward}("");
            require(success, "SuperfineNFTStaking: native token settle failed");
        } else {
            bool success = IERC20(rewardToken).transfer(msg.sender, reward);
            require(success, "SuperfineNFTStaking: ERC20 token settle failed");
        }
        emit RewardClaimed(msg.sender, reward);
    }

    function pause() external onlyOperator {
        _pause();
    }

    function unpause() external onlyOperator {
        _unpause();
    }

    function emergencyWithdraw(
        address payable recipient,
        address currency
    ) external onlyOwner whenPaused {
        if (currency == address(0)) {
            uint256 amount = address(this).balance;
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "SuperfineNFTStaking: emergency withdraw failed");
            emit EmergencyWithdrawn(recipient, amount);
        } else {
            IERC20 currencyContract = IERC20(currency);
            uint256 amount = currencyContract.balanceOf(address(this));
            bool success = currencyContract.transfer(recipient, amount);
            require(success, "SuperfineNFTStaking: emergency withdraw failed");
            emit EmergencyWithdrawn(recipient, amount);
        }
    }
}
