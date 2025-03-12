// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";
import "hardhat/console.sol";

contract MyntfloStaking is ReentrancyGuard, ERC2771Context {
    using SafeERC20 for IERC20;

    // Interface for the ERC20 Rewards Token
    IERC20 public rewardsToken;

    address public owner;

    modifier onlyOwner() {
        require(_msgSender() == owner, "Ownable: caller is not the owner");
        _;
    }

    // Staked token info
    struct StakedToken {
        address staker;
        uint256 tokenId;
        uint256 timeStaked;
        uint256 timeOfLastUpdate;
        address contractAddress;
    }

    // Staker info
    struct Staker {
        // Amount of staked tokens by the user
        uint256 amountStaked;
        // Staked tokens for user
        StakedToken[] stakedTokens;
    }

    // Mapping of User Address to Staker info
    mapping(address => Staker) public stakers;
    
    // If a collection is elegible for staking
    mapping(address => bool) public elegibleCollections;

    mapping(address => mapping(uint256 => uint256)) private timeOfLastUpdate;
    mapping(address => bool) private collectionStaked;

    // Events for frontend
    event Staked(address caller, uint256 tokenId);
    event Unstaked(address caller, uint256 tokenId);
    event RewardsClaimed(address caller);

    // Constructor, sets the owner and rewards token address
    constructor(MinimalForwarder forwarder, IERC20 _rewardsToken) ERC2771Context(address(forwarder)) {
        rewardsToken = _rewardsToken;
        owner = _msgSender();
    }
   
    
    // Stake new NFT
    function stake(uint256 _tokenId, address _tokenContract) external nonReentrant {
        
        // instantiate the NFT contract
        IERC721 nftCollection = IERC721(_tokenContract);

        // Wallet must own the token they are trying to stake
        require(nftCollection.ownerOf(_tokenId) == _msgSender(), "You don't own this token!");
        require(elegibleCollections[_tokenContract], "This collection is not elegible for staking");

        // Transfer the token from the wallet to this contract, we assume the user already granted approval
        nftCollection.transferFrom(_msgSender(), address(this), _tokenId);

        uint256 lastUpdate = block.timestamp;
        if(!collectionStaked[_tokenContract] || timeOfLastUpdate[_tokenContract][_tokenId] == 0){
            collectionStaked[_tokenContract] = true;
            timeOfLastUpdate[_tokenContract][_tokenId] = block.timestamp;
        } else {
            lastUpdate = timeOfLastUpdate[_tokenContract][_tokenId];
        }
        
        // Create StakedToken
        StakedToken memory stakedToken = StakedToken(_msgSender(), _tokenId, block.timestamp, lastUpdate, _tokenContract);
    
        // Add the token to the users stakedTokens array
        stakers[_msgSender()].stakedTokens.push(stakedToken);

        // Increment the amount staked for this wallet
        stakers[_msgSender()].amountStaked++;

        // Emit event
        emit Staked(_msgSender(), _tokenId);

    }
    

    // Unstake the NFT
    function unstake(uint256 _tokenId, address _tokenContract) external nonReentrant {

        // Make sure the user has at least one token staked before withdrawing
        require(stakers[_msgSender()].amountStaked > 0, "You have no NFTs staked");
        
        // Find the index of this token id in the users stakedTokens array
        uint256 index = 0;
        bool nftFound = false;
        for (uint256 i = 0; i < stakers[_msgSender()].stakedTokens.length; i++) {

            if (stakers[_msgSender()].stakedTokens[i].tokenId == _tokenId &&
            stakers[_msgSender()].stakedTokens[i].contractAddress == _tokenContract &&
            stakers[_msgSender()].stakedTokens[i].staker == _msgSender()) {
                index = i;
                nftFound = true;
                break;
            }

        }

        // Make sure the token is staked
        require(nftFound, "This NFT is not staked");

        // Calculate rewards for this token and transfer it to the user
        uint256 secondsPassed = block.timestamp - stakers[_msgSender()].stakedTokens[index].timeOfLastUpdate;
        uint256 rewards = decay(secondsPassed);
        rewardsToken.safeTransfer(_msgSender(), rewards);

        // Set this token's .staker to be address 0 to mark it as no longer staked
        stakers[_msgSender()].stakedTokens[index].staker = address(0);

        // mark the time of last update for this token
        timeOfLastUpdate[_tokenContract][_tokenId] = block.timestamp;

        // Decrement the amount staked for this wallet
        stakers[_msgSender()].amountStaked--;

        // Transfer the token back to the withdrawer
        IERC721(_tokenContract).transferFrom(address(this), _msgSender(), _tokenId);

        // Emit event
        emit Unstaked(_msgSender(), _tokenId);
    }

    // Update the rewards token address
    function setRewardsToken(IERC20 _rewardsToken) external onlyOwner {
        rewardsToken = _rewardsToken;
    }

    function setElegibleCollection(address _collection, bool _elegible) external onlyOwner {
        elegibleCollections[_collection] = _elegible;
    }

    function setElegibleCollections(address[] memory _collections, bool[] memory _elegible) external onlyOwner {
        for(uint256 i = 0; i < _collections.length; i++) {
            elegibleCollections[_collections[i]] = _elegible[i];
        }
    }

    // Calculate current pending rewards, transfer them to user
    // and set timeOfLastUpdate to current time for every staked token
    function claimRewards() external {
        uint256 rewards = calculateRewards(_msgSender());
        require(rewards > 0, "You have no rewards to claim");

        // Update the timeOfLastUpdate for every nft staked
        // so next rewards will start counting from current time
        for(uint256 i = 0; i < stakers[_msgSender()].stakedTokens.length; i++) {
            if(stakers[_msgSender()].stakedTokens[i].staker != address(0)) {
                stakers[_msgSender()].stakedTokens[i].timeOfLastUpdate = block.timestamp;
            }
        }

        // Transfer the rewards to the user
        rewardsToken.safeTransfer(_msgSender(), rewards);

        // Emit event
        emit RewardsClaimed(_msgSender());
    }

    function setTimeOfLastUpdate(address staker, uint256 index, uint256 _timeStaked, uint256 _timeUpdated) external onlyOwner {
        stakers[staker].stakedTokens[index].timeStaked = _timeStaked;
        stakers[staker].stakedTokens[index].timeOfLastUpdate = _timeUpdated;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function withdrawRewardsToken() external onlyOwner {
        rewardsToken.transfer(owner, rewardsToken.balanceOf(address(this)));
    }

    ////////////////////
    // View functions //
    ////////////////////

    // Return available rewards for a staker
    function availableRewards(address _staker) public view returns (uint256) {
        uint256 rewards = calculateRewards(_staker);
        return rewards;
    }

    // Return all staked tokens for a user
    function getStakedTokens(address _user) public view returns (StakedToken[] memory) {
        // User needs tokens staked
        if(stakers[_user].amountStaked == 0) return new StakedToken[](0);
        
        // Return all the tokens in the stakedToken Array for this user that are not -1
        StakedToken[] memory _stakedTokens = new StakedToken[](stakers[_user].amountStaked);
        
        uint256 _index = 0;
        for (uint256 j = 0; j < stakers[_user].stakedTokens.length; j++) {
            if (stakers[_user].stakedTokens[j].staker == _user) {
                _stakedTokens[_index] = stakers[_user].stakedTokens[j];
                _index++;
            }
        }

        return _stakedTokens;
    
    }

    ////////////////////////
    // Internal functions //
    ////////////////////////

    // Receives the amount of time passed in seconds and returns the amount of rewards
    // for a single token using a decay function,
    // it calculates each day's rewards since the token was staked and adds them up
    function decay(uint256 secondsPassed) internal view returns (uint256) {
        uint hoursPassed = secondsPassed / 3600;
        uint daysPassed = hoursPassed / 24;
        
        console.log('daysPassed: %s', daysPassed);
        
        uint A = 24615571013467300;
        uint B = 70;
        uint X = 8;

        uint256 cumulativeRewards = 0;
        for(uint i = 1; i <= daysPassed; i++) {
            cumulativeRewards += (A / ((B + i) ** X)) * 10 ** 18;
        }

        return cumulativeRewards;

    }


    // Calculate rewards for _staker using each staked token's timeOfLastUpdate
    function calculateRewards(address _staker) internal view returns (uint256 _rewards){
        
        // calculate rewards for every token staked
        // and add them up to totalRewards
        uint256 totalRewards = 0;
        for(uint256 i = 0; i < stakers[_staker].stakedTokens.length; i++) {
            if (stakers[_staker].stakedTokens[i].staker != address(0)) {

                uint256 secondsPassed = block.timestamp - stakers[_staker].stakedTokens[i].timeOfLastUpdate;

                // debug info
                console.log("\n\n----- Calculating rewards -----");
                console.log('user: %s', _staker);
                console.log('nft contract: %s', stakers[_staker].stakedTokens[i].contractAddress);
                console.log('nft id: %s', stakers[_staker].stakedTokens[i].tokenId);
                console.log('time now: %s', block.timestamp);
                console.log('amount of tokens staked: %s', stakers[_staker].amountStaked);
                console.log('timeOfLastUpdate for token: %s', stakers[_staker].stakedTokens[i].timeOfLastUpdate);
                console.log('time difference: %s', secondsPassed);
                console.log('rewards: %s', decay(secondsPassed));

                totalRewards += decay(secondsPassed);
                
            }
        }

        return totalRewards;

    }

    

}
