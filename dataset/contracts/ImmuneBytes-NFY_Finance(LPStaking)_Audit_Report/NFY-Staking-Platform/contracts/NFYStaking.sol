// SPDX-License-Identifier: MIT

pragma solidity ^0.6.10;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Ownable.sol";

interface INFYStakingNFT {
    function nftTokenId(address _stakeholder) external view returns(uint256 id);
    function revertNftTokenId(address _stakeholder, uint256 _tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function balanceOf(address owner) external view returns (uint256 balance);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

contract NFYStaking is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    struct NFT {
        address _addressOfMinter;
        uint256 _NFYDeposited;
        bool _inCirculation;
        uint256 _rewardDebt;
    }

    event StakeCompleted(address _staker, uint256 _amount, uint256 _tokenId, uint256 _totalStaked, uint256 _time);
    event WithdrawCompleted(address _staker, uint256 _amount, uint256 _tokenId, uint256 _time);
    event PoolUpdated(uint256 _blocksRewarded, uint256 _amountRewarded, uint256 _time);
    event RewardsClaimed(address _staker, uint256 _rewardsClaimed, uint256 _tokenId, uint256 _time);
    event RewardsCompounded(address _staker, uint256 _rewardsCompounded, uint256 _tokenId, uint256 _totalStaked, uint256 _time);
    event MintedToken(address _staker, uint256 _tokenId, uint256 _time);

    event TotalUnstaked(uint256 _total);

    IERC20 public NFYToken;
    INFYStakingNFT public StakingNFT;
    address public rewardPool;
    address public staking;
    uint256 public dailyReward;
    uint256 public accNfyPerShare;
    uint256 public lastRewardBlock;
    uint256 public totalStaked;

    mapping(uint256 => NFT) public NFTDetails;

    // Constructor will set the address of NFY token and address of NFY staking NFT
    constructor(address _NFYToken, address _StakingNFT, address _staking, address _rewardPool, uint256 _dailyReward) Ownable() public {
        NFYToken = IERC20(_NFYToken);
        StakingNFT = INFYStakingNFT(_StakingNFT);
        staking = _staking;
        rewardPool = _rewardPool;

        // 10:30 EST October 29th
        lastRewardBlock = 11152600;
        setDailyReward(_dailyReward);
        accNfyPerShare = 0;
    }

    // 6500 blocks in average day --- decimals * NFY balance of rewardPool / blocks / 10000 * dailyReward (in hundredths of %) = rewardPerBlock
    function getRewardPerBlock() public view returns(uint256) {
        return NFYToken.balanceOf(rewardPool).div(6500).div(10000).mul(dailyReward);
    }

    // % of reward pool to be distributed each day --- in hundredths of % 30 == 0.3%
    function setDailyReward(uint256 _dailyReward) public onlyOwner {
        dailyReward = _dailyReward;
    }

    // Function that will get balance of a NFY balance of a certain stake
    function getNFTBalance(uint256 _tokenId) public view returns(uint256 _amountStaked) {
        return NFTDetails[_tokenId]._NFYDeposited;
    }

    // Function that will check if a NFY stake NFT is in circulation
    function checkIfNFTInCirculation(uint256 _tokenId) public view returns(bool _inCirculation) {
        return NFTDetails[_tokenId]._inCirculation;
    }

    // Function that returns NFT's pending rewards
    function pendingRewards(uint256 _NFT) public view returns(uint256) {
        NFT storage nft = NFTDetails[_NFT];

        uint256 _accNfyPerShare = accNfyPerShare;

        if (block.number > lastRewardBlock && totalStaked != 0) {
            uint256 blocksToReward = block.number.sub(lastRewardBlock);
            uint256 nfyReward = blocksToReward.mul(getRewardPerBlock());
            _accNfyPerShare = _accNfyPerShare.add(nfyReward.mul(1e18).div(totalStaked));
        }

        return nft._NFYDeposited.mul(_accNfyPerShare).div(1e18).sub(nft._rewardDebt);
    }

    // Get total rewards for all of user's NFY nfts
    function getTotalRewards(address _address) public view returns(uint256) {
        uint256 totalRewards;

        for(uint256 i = 0; i < StakingNFT.balanceOf(_address); i++) {
            uint256 _rewardPerNFT = pendingRewards(StakingNFT.tokenOfOwnerByIndex(_address, i));
            totalRewards = totalRewards.add(_rewardPerNFT);
        }

        return totalRewards;
    }

    // Get total stake for all user's NFY nfts
    function getTotalBalance(address _address) public view returns(uint256) {
        uint256 totalBalance;

        for(uint256 i = 0; i < StakingNFT.balanceOf(_address); i++) {
            uint256 _balancePerNFT = getNFTBalance(StakingNFT.tokenOfOwnerByIndex(_address, i));
            totalBalance = totalBalance.add(_balancePerNFT);
        }

        return totalBalance;
    }

    // Function that updates NFY pool
    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }

        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 blocksToReward = block.number.sub(lastRewardBlock);

        uint256 nfyReward = blocksToReward.mul(getRewardPerBlock());

        //Approve nfyReward here
        NFYToken.transferFrom(rewardPool, address(this), nfyReward);

        accNfyPerShare = accNfyPerShare.add(nfyReward.mul(1e18).div(totalStaked));
        lastRewardBlock = block.number;

        emit PoolUpdated(blocksToReward, nfyReward, now);
    }

    // Function that lets user stake NFY
    function stakeNFY(uint256 _amount) public {
        require(_amount > 0, "Can not stake 0 NFY");
        require(NFYToken.balanceOf(_msgSender()) >= _amount, "Do not have enough NFY to stake");

        updatePool();

        if(StakingNFT.nftTokenId(_msgSender()) == 0){
             addStakeholder(_msgSender());
        }

        NFT storage nft = NFTDetails[StakingNFT.nftTokenId(_msgSender())];

        if(nft._NFYDeposited > 0) {
            uint256 _pendingRewards = nft._NFYDeposited.mul(accNfyPerShare).div(1e18).sub(nft._rewardDebt);

            if(_pendingRewards > 0) {
                NFYToken.transfer(_msgSender(), _pendingRewards);
                emit RewardsClaimed(_msgSender(), _pendingRewards, StakingNFT.nftTokenId(_msgSender()), now);
            }
        }

        NFYToken.transferFrom(_msgSender(), address(this), _amount);
        nft._NFYDeposited = nft._NFYDeposited.add(_amount);
        totalStaked = totalStaked.add(_amount);

        nft._rewardDebt = nft._NFYDeposited.mul(accNfyPerShare).div(1e18);

        emit StakeCompleted(_msgSender(), _amount, StakingNFT.nftTokenId(_msgSender()), nft._NFYDeposited, now);

    }

    function addStakeholder(address _stakeholder) private {
        (bool success, bytes memory data) = staking.call(abi.encodeWithSignature("mint(address)", _stakeholder));
        require(success == true, "Mint call failed");
        NFTDetails[StakingNFT.nftTokenId(_msgSender())]._addressOfMinter = _stakeholder;
        NFTDetails[StakingNFT.nftTokenId(_msgSender())]._inCirculation = true;
    }

    function addStakeholderExternal(address _stakeholder) external onlyPlatform() {
        (bool success, bytes memory data) = staking.call(abi.encodeWithSignature("mint(address)", _stakeholder));
        require(success == true, "Mint call failed");
        NFTDetails[StakingNFT.nftTokenId(_msgSender())]._addressOfMinter = _stakeholder;
        NFTDetails[StakingNFT.nftTokenId(_msgSender())]._inCirculation = true;
    }

    // Function that will allow user to claim rewards
    function claimRewards(uint256 _tokenId) public {
        require(StakingNFT.ownerOf(_tokenId) == _msgSender(), "User is not owner of token");
        require(NFTDetails[_tokenId]._inCirculation == true, "Stake has already been withdrawn");

        updatePool();

        NFT storage nft = NFTDetails[_tokenId];

        uint256 _pendingRewards = nft._NFYDeposited.mul(accNfyPerShare).div(1e18).sub(nft._rewardDebt);
        require(_pendingRewards > 0, "No rewards to claim!");

        NFYToken.transfer(_msgSender(), _pendingRewards);

        nft._rewardDebt = nft._NFYDeposited.mul(accNfyPerShare).div(1e18);

        emit RewardsClaimed(_msgSender(), _pendingRewards, _tokenId, now);
    }

    // Function that will add NFY rewards to NFY staking NFT
    function compoundRewards(uint256 _tokenId) public {
        require(StakingNFT.ownerOf(_tokenId) == _msgSender(), "User is not owner of token");
        require(NFTDetails[_tokenId]._inCirculation == true, "Stake has already been withdrawn");

        updatePool();

        NFT storage nft = NFTDetails[_tokenId];

        uint256 _pendingRewards = nft._NFYDeposited.mul(accNfyPerShare).div(1e18).sub(nft._rewardDebt);
        require(_pendingRewards > 0, "No rewards to compound!");

        nft._NFYDeposited = nft._NFYDeposited.add(_pendingRewards);
        totalStaked = totalStaked.add(_pendingRewards);

        nft._rewardDebt = nft._NFYDeposited.mul(accNfyPerShare).div(1e18);

        emit RewardsCompounded(_msgSender(), _pendingRewards, _tokenId, nft._NFYDeposited, now);
    }

    // Function that lets user claim all rewards from all their nfts
    function claimAllRewards() public {
        require(StakingNFT.balanceOf(_msgSender()) > 0, "User has no stake");
        for(uint256 i = 0; i < StakingNFT.balanceOf(_msgSender()); i++) {
            uint256 _currentNFT = StakingNFT.tokenOfOwnerByIndex(_msgSender(), i);
            claimRewards(_currentNFT);
        }
    }

    // Function that lets user compound all rewards from all their nfts
    function compoundAllRewards() public {
        require(StakingNFT.balanceOf(_msgSender()) > 0, "User has no stake");
        for(uint256 i = 0; i < StakingNFT.balanceOf(_msgSender()); i++) {
            uint256 _currentNFT = StakingNFT.tokenOfOwnerByIndex(_msgSender(), i);
            compoundRewards(_currentNFT);
        }
    }

    // Function that lets user unstake NFY in system. 5% fee that gets redistributed back to reward pool
    function unstakeNFY(uint256 _tokenId) public {
        // Require that user is owner of token id
        require(StakingNFT.ownerOf(_tokenId) == _msgSender(), "User is not owner of token");
        require(NFTDetails[_tokenId]._inCirculation == true, "Stake has already been withdrawn");

        updatePool();

        NFT storage nft = NFTDetails[_tokenId];

        uint256 _pendingRewards = nft._NFYDeposited.mul(accNfyPerShare).div(1e18).sub(nft._rewardDebt);

        uint256 amountStaked = getNFTBalance(_tokenId);
        uint256 stakeAfterFees = amountStaked.div(100).mul(95);
        uint256 userReceives = amountStaked.div(100).mul(95).add(_pendingRewards);

        uint256 fee = amountStaked.div(100).mul(5);

        uint256 beingWithdrawn = nft._NFYDeposited;
        nft._NFYDeposited = 0;
        nft._inCirculation = false;
        totalStaked = totalStaked.sub(beingWithdrawn);
        StakingNFT.revertNftTokenId(_msgSender(), _tokenId);

        (bool success, bytes memory data) = staking.call(abi.encodeWithSignature("burn(uint256)", _tokenId));
        require(success == true, "mint call failed");

        NFYToken.transfer(_msgSender(), userReceives);
        NFYToken.transfer(rewardPool, fee);

        emit WithdrawCompleted(_msgSender(), stakeAfterFees, _tokenId, now);
        emit RewardsClaimed(_msgSender(), _pendingRewards, _tokenId, now);
    }

    // Function that will unstake every user's NFY stake NFT for user
    function unstakeAll() public {
        require(StakingNFT.balanceOf(_msgSender()) > 0, "User has no stake");

        while(StakingNFT.balanceOf(_msgSender()) > 0) {
            uint256 _currentNFT = StakingNFT.tokenOfOwnerByIndex(_msgSender(), 0);
            unstakeNFY(_currentNFT);
        }

    }

    // Will increment value of staking NFT when trade occurs
    function incrementNFTValue (uint256 _tokenId, uint256 _amount) external onlyPlatform() {
        require(checkIfNFTInCirculation(_tokenId) == true, "Token not in circulation");
        updatePool();

        NFT storage nft = NFTDetails[_tokenId];

        if(nft._NFYDeposited > 0) {
            uint256 _pendingRewards = nft._NFYDeposited.mul(accNfyPerShare).div(1e18).sub(nft._rewardDebt);

            if(_pendingRewards > 0) {
                NFYToken.transfer(StakingNFT.ownerOf(_tokenId), _pendingRewards);
                emit RewardsClaimed(StakingNFT.ownerOf(_tokenId), _pendingRewards, _tokenId, now);
            }
        }

        NFTDetails[_tokenId]._NFYDeposited =  NFTDetails[_tokenId]._NFYDeposited.add(_amount);

        nft._rewardDebt = nft._NFYDeposited.mul(accNfyPerShare).div(1e18);
    }

    // Will decrement value of staking NFT when trade occurs
    function decrementNFTValue (uint256 _tokenId, uint256 _amount) external onlyPlatform() {
        require(checkIfNFTInCirculation(_tokenId) == true, "Token not in circulation");
        require(getNFTBalance(_tokenId) >= _amount, "Not enough stake in NFT");

        updatePool();

        NFT storage nft = NFTDetails[_tokenId];

        if(nft._NFYDeposited > 0) {
            uint256 _pendingRewards = nft._NFYDeposited.mul(accNfyPerShare).div(1e18).sub(nft._rewardDebt);

            if(_pendingRewards > 0) {
                NFYToken.transfer(StakingNFT.ownerOf(_tokenId), _pendingRewards);
                emit RewardsClaimed(StakingNFT.ownerOf(_tokenId), _pendingRewards, _tokenId, now);
            }
        }

        NFTDetails[_tokenId]._NFYDeposited =  NFTDetails[_tokenId]._NFYDeposited.sub(_amount);

        nft._rewardDebt = nft._NFYDeposited.mul(accNfyPerShare).div(1e18);
    }

}