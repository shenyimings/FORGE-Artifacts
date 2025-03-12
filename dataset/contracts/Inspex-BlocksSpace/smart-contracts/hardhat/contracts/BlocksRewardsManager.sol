pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BlocksStaking.sol";


contract BlocksRewardsManager is Ownable {
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many blocks user owns currently.
        uint256 pendingRewards; // Rewards assigned, but not yet claimed
        uint256 lastRewardCalculatedBlock; // When pending rewards were last calculated for user
    }

    // Info of each blocks.space
    struct SpaceInfo {
        uint256 spaceId;
        uint256 amountOfBlocksBought; // Number of all blocks bought on this space
        address contractAddress; // Address of space contract.
        uint256 blsPerBlockAreaPerBlock; // Start with 830000000000000 wei (approx 24 BLS/block.area/day)
    }

    // Management of splitting rewards
    uint256 constant MAX_TREASURY_FEE = 5;
    uint256 constant MAX_LIQUIDITY_FEE = 10;
    uint256 constant MAX_PREVIOUS_OWNER_FEE = 50;
    uint256 public treasuryFee = 5;
    uint256 public liquidityFee = 10;
    uint256 public previousOwnerFee = 25;

    address payable public treasury;
    IERC20 public blsToken;
    BlocksStaking public blocksStaking;
    SpaceInfo[] public spaceInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(address => bool) public spacesByAddress;
    // Variables that support calculation of proper bls rewards distributions
    uint256 public allAllocationBlocks; // Amount of all blocks from all spaces that are getting BLS rewards
    uint256 public allBlsPerBlockAreaPerBlock;
    uint256 public blsRewardsFinishedBlock;
    uint256 public blsRewardsAcc; // bls rewards accumulated
    uint256 public blsRewardsAccLastUpdatedBlock;
    uint256 public blsRewardsClaimed;

    event SpaceAdded(uint256 indexed spaceId, address indexed space, address indexed addedBy);
    event Claim(address indexed user, uint256 amount);

    modifier onlySpace() {
        require(spacesByAddress[msg.sender] == true, "Not a space.");
        _;
    }

    constructor(
        IERC20 blsAddress_,
        address blocksStakingAddress_,
        address treasury_
    ) {
        blsToken = IERC20(blsAddress_);
        blocksStaking = BlocksStaking(blocksStakingAddress_);
        treasury = payable(treasury_);
    }

    function spacesLength() external view returns (uint256) {
        return spaceInfo.length;
    }

    function addSpace(address spaceContract_, uint256 blsPerBlockAreaPerBlock_) external onlyOwner {
        spacesByAddress[spaceContract_] = true;
        uint256 spaceId = spaceInfo.length;
        SpaceInfo storage newSpace = spaceInfo.push();
        newSpace.contractAddress = spaceContract_;
        newSpace.spaceId = spaceId;
        newSpace.blsPerBlockAreaPerBlock = blsPerBlockAreaPerBlock_;
        allBlsPerBlockAreaPerBlock = allBlsPerBlockAreaPerBlock + blsPerBlockAreaPerBlock_;
        emit SpaceAdded(spaceId, spaceContract_, msg.sender);
    }

    function updateBlsPerBlockAreaPerBlock(uint256 spaceId_, uint256 newAmount_) external onlyOwner {
        SpaceInfo storage space = spaceInfo[spaceId_];
        require(space.contractAddress != address(0), "SpaceInfo does not exist");
        allBlsPerBlockAreaPerBlock = allBlsPerBlockAreaPerBlock - space.blsPerBlockAreaPerBlock + newAmount_; // Remove old amount and Add new amount
        space.blsPerBlockAreaPerBlock = newAmount_;
    }

    function pendingBlsTokens(uint256 spaceId_, address user_) public view returns (uint256) {
        SpaceInfo storage space = spaceInfo[spaceId_];
        UserInfo storage user = userInfo[spaceId_][user_];
        uint256 rewards;
        if (user.amount > 0 && user.lastRewardCalculatedBlock < block.number) {
            uint256 multiplier = getMultiplier(user.lastRewardCalculatedBlock);
            uint256 blsRewards = multiplier * space.blsPerBlockAreaPerBlock;
            rewards = user.amount * blsRewards;
        }
        return user.pendingRewards + rewards;
    }

    function getMultiplier(uint256 usersLastRewardsCalculatedBlock) internal view returns (uint256) {
        if (block.number > blsRewardsFinishedBlock) {
            return blsRewardsFinishedBlock - usersLastRewardsCalculatedBlock;
        } else {
            return block.number - usersLastRewardsCalculatedBlock;
        }
    }

    function blocksAreaBoughtOnSpace(
        uint256 spaceId_,
        address buyer_,
        address[] calldata previousBlockOwners_,
        uint256[] calldata previousOwnersPrices_
    ) public payable onlySpace {
        SpaceInfo storage space = spaceInfo[spaceId_];
        UserInfo storage user = userInfo[spaceId_][buyer_];
        uint256 blsPerBlockAreaPerBlock = space.blsPerBlockAreaPerBlock;

        // If user already had some block.areas then calculate all rewards pending
        if (user.lastRewardCalculatedBlock > 0) {
            uint256 multiplier = getMultiplier(user.lastRewardCalculatedBlock);
            uint256 blsRewards = multiplier * blsPerBlockAreaPerBlock;
            user.pendingRewards = user.pendingRewards + user.amount * blsRewards;
        }
        uint256 numberOfBlocksBought = previousBlockOwners_.length;
        // Set user data
        user.amount = user.amount + numberOfBlocksBought;
        user.lastRewardCalculatedBlock = block.number;

        //remove blocks from previous owners that this guy took over. Max 42 loops
        uint256 allPreviousOwnersPaid;
        uint256 numberOfBlocksToRemove;
        for (uint256 i = 0; i < numberOfBlocksBought; ++i) {
            // If previous owners of block are non zero address, means we need to take block from them
            if (previousBlockOwners_[i] != address(0)) {
                allPreviousOwnersPaid = allPreviousOwnersPaid + previousOwnersPrices_[i];
                // Calculate previous users pending BLS rewards
                UserInfo storage prevUser = userInfo[spaceId_][previousBlockOwners_[i]];
                uint256 multiplier = getMultiplier(prevUser.lastRewardCalculatedBlock);
                uint256 blsRewards = multiplier * blsPerBlockAreaPerBlock;
                prevUser.pendingRewards = prevUser.pendingRewards + prevUser.amount * blsRewards;
                prevUser.lastRewardCalculatedBlock = block.number;
                // Remove his ownership of block
                --prevUser.amount;
                ++numberOfBlocksToRemove;
            }
        }
        uint256 numberOfBlocksAdded = numberOfBlocksBought - numberOfBlocksToRemove;
        // If amount of blocks on space changed, we need to update space and global state
        if (numberOfBlocksAdded > 0) {
            blsRewardsAcc =
                blsRewardsAcc +
                (block.number - blsRewardsAccLastUpdatedBlock) *
                allAllocationBlocks *
                allBlsPerBlockAreaPerBlock;
            blsRewardsAccLastUpdatedBlock = block.number;
            allAllocationBlocks = allAllocationBlocks + numberOfBlocksAdded;
            space.amountOfBlocksBought = space.amountOfBlocksBought + numberOfBlocksAdded;
            // Recalculate what is last block eligible for BLS rewards
            uint256 blsBalance = blsToken.balanceOf(address(this));
            // If this is true, we are still in state of distribution of rewards
            if (blsBalance > blsRewardsAcc) {
                uint256 blocksTillBlsRunOut = (blsBalance + blsRewardsClaimed - blsRewardsAcc) /
                    (allBlsPerBlockAreaPerBlock * allAllocationBlocks);
                blsRewardsFinishedBlock = block.number + blocksTillBlsRunOut;
            }
        }

        // Calculate and subtract fees in first part
        // In second part, calculate how much rewards are being rewarded to previous block owners
        (uint256 rewardToForward, uint256[] memory prevOwnersRewards) = calculateAndDistributeFees(
            msg.value,
            previousOwnersPrices_,
            allPreviousOwnersPaid
        );

        // Send to distribution part
        blocksStaking.distributeRewards{value: rewardToForward}(previousBlockOwners_, prevOwnersRewards);
    }

    function calculateAndDistributeFees(
        uint256 rewardReceived_,
        uint256[] calldata previousOwnersPrices_,
        uint256 previousOwnersPaid_
    ) internal returns (uint256, uint256[] memory) {
        uint256 numberOfBlocks = previousOwnersPrices_.length;
        uint256 feesTaken;
        uint256 previousOwnersFeeValue;
        uint256[] memory previousOwnersRewardWei = new uint256[](numberOfBlocks);
        if (previousOwnerFee > 0 && previousOwnersPaid_ != 0) {
            previousOwnersFeeValue = (rewardReceived_ * previousOwnerFee) / 100; // Calculate how much is for example 25% of whole rewards gathered
            uint256 onePartForPreviousOwners = (previousOwnersFeeValue * 1e9) / previousOwnersPaid_; // Then calculate one part for previous owners sum
            for (uint256 i = 0; i < numberOfBlocks; ++i) {
                // Now we calculate exactly how much one user gets depending on his investment (it needs to be proportionally)
                previousOwnersRewardWei[i] = (onePartForPreviousOwners * previousOwnersPrices_[i]) / 1e9;
            }
        }
        // Can be max 5%
        if (treasuryFee > 0) {
            uint256 treasuryFeeValue = (rewardReceived_ * treasuryFee) / 100;
            if (treasuryFeeValue > 0) {
                feesTaken = feesTaken + treasuryFeeValue;
            }
        }
        // Can be max 10%
        if (liquidityFee > 0) {
            uint256 liquidityFeeValue = (rewardReceived_ * liquidityFee) / 100;
            if (liquidityFeeValue > 0) {
                feesTaken = feesTaken + liquidityFeeValue;
            }
        }
        // Send fees to treasury. Max together 15%. We use call, because it enables auto liqudity provisioning on DEX in future when token is trading
        if (feesTaken > 0) {
            (bool sent,) = treasury.call{value: feesTaken}("");
            require(sent, "Failed to send Ether");
        }

        return (rewardReceived_ - feesTaken, previousOwnersRewardWei);
    }

    function claim(uint256 spaceId_) public {
        UserInfo storage user = userInfo[spaceId_][msg.sender];
        uint256 amount = user.amount;
        uint256 lastRewardCalculatedBlock = user.lastRewardCalculatedBlock;
        if (amount > 0 && lastRewardCalculatedBlock < block.number) {
            user.pendingRewards =
                user.pendingRewards +
                amount *
                getMultiplier(lastRewardCalculatedBlock) *
                spaceInfo[spaceId_].blsPerBlockAreaPerBlock;
            user.lastRewardCalculatedBlock = block.number;
        }
        uint256 toClaimAmount = user.pendingRewards;
        if (toClaimAmount > 0) {
            uint256 claimedAmount = safeBlsTransfer(msg.sender, toClaimAmount);
            emit Claim(msg.sender, claimedAmount);
            // This is also kinda check, since if user claims more than eligible, this will revert
            user.pendingRewards = toClaimAmount - claimedAmount;
            blsRewardsClaimed = blsRewardsClaimed + claimedAmount; // Globally claimed rewards, for proper end distribution calc
        }
    }

    // Safe BLS transfer function, just in case if rounding error causes pool to not have enough BLSs.
    function safeBlsTransfer(address to_, uint256 amount_) internal returns (uint256) {
        uint256 blsBalance = blsToken.balanceOf(address(this));
        if (amount_ > blsBalance) {
            blsToken.transfer(to_, blsBalance);
            return blsBalance;
        } else {
            blsToken.transfer(to_, amount_);
            return amount_;
        }
    }

    function setTreasuryFee(uint256 newFee_) external onlyOwner {
        require(newFee_ <= MAX_TREASURY_FEE);
        treasuryFee = newFee_;
    }

    function setLiquidityFee(uint256 newFee_) external onlyOwner {
        require(newFee_ <= MAX_LIQUIDITY_FEE);
        liquidityFee = newFee_;
    }

    function setPreviousOwnerFee(uint256 newFee_) external onlyOwner {
        require(newFee_ <= MAX_PREVIOUS_OWNER_FEE);
        previousOwnerFee = newFee_;
    }

    function updateBlocksStatingContract(address address_) external onlyOwner {
        blocksStaking = BlocksStaking(address_);
    }

    function updateTreasuryWallet(address newWallet_) external onlyOwner {
        treasury = payable(newWallet_);
    }

    function depositBlsRewardsForDistribution(uint256 amount_) external onlyOwner {
        blsToken.transferFrom(address(msg.sender), address(this), amount_);

        blsRewardsAcc = blsRewardsAcc + (block.number - blsRewardsAccLastUpdatedBlock) * allAllocationBlocks * allBlsPerBlockAreaPerBlock;
        blsRewardsAccLastUpdatedBlock = block.number;
        uint256 blsBalance = blsToken.balanceOf(address(this));
        if (blsBalance > blsRewardsAcc && allAllocationBlocks > 0) {
            uint256 blocksTillBlsRunOut = (blsBalance + blsRewardsClaimed - blsRewardsAcc) /
                (allBlsPerBlockAreaPerBlock * allAllocationBlocks);
            blsRewardsFinishedBlock = block.number + blocksTillBlsRunOut;
        }
    }

}
