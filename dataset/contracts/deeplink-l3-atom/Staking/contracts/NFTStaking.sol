pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "./Interface/IDeepToken.sol";
import "./Interface/IDKeeper.sol";
import "./Interface/IDKeeperEscrow.sol";

contract DKeeperStake is Ownable, IERC721Receiver {
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 lastClaimTime; // Timestamp of last reward claim
        uint256 lastStakeTime; // Timestamp of last stake
    }

    // DeepToken contract
    IDeepToken public deepToken;

    // DKeeper NFT contract
    IDKeeper public dKeeper;

    // DKeeper Escrow contract
    IDKeeperEscrow public dKeeperEscrow;

    // Timestamp of last reward
    uint256 public lastRewardTime;

    // Accumulated token per share
    uint256 public accTokenPerShare;

    // Staked users' NFT Id existing check
    mapping(address => mapping(uint256 => uint256)) public userNFTs;

    // Staked users' NFT Ids
    mapping(address => uint256[]) public stakedNFTs;

    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    // The block timestamp when Deep distribution starts.
    uint256 public startTime;

    // The block timestamp when Deep distribution ends.
    uint256 public endTime;

    uint256 public constant WEEK = 3600 * 24 * 7;

    event Deposited(address indexed user, uint256 indexed tokenId, uint256 amount);

    event Withdrawn(address indexed user, uint256 indexed tokenId, uint256 amount);

    event Claimed(address indexed user, uint256 amount);

    constructor(
        IDeepToken _deep,
        IDKeeper _dKeeper,
        uint256 _startTime,
        uint256 _endTime
    ) public {
        require(_endTime >= _startTime && block.timestamp <= _startTime, "Invalid timestamp");
        deepToken = _deep;
        dKeeper = _dKeeper;
        startTime = _startTime;
        endTime = _endTime;

        totalAllocPoint = 0;
        lastRewardTime = _startTime;
    }

    // View function to see pending Deeps on frontend.
    function pendingDeep(address _user) external view returns (uint256) {
        UserInfo memory user = userInfo[_user];

        uint256 updatedAccTokenPerShare = accTokenPerShare;
        if (block.timestamp > lastRewardTime && totalAllocPoint != 0) {
            uint256 rewards = getRewards(lastRewardTime, block.timestamp);
            updatedAccTokenPerShare += ((rewards * 1e12) / totalAllocPoint);
        }

        return (user.amount * updatedAccTokenPerShare) / 1e12 - user.rewardDebt;
    }

    // Update reward variables to be up-to-date.
    function updatePool() public {
        if (block.timestamp <= lastRewardTime || lastRewardTime >= endTime) {
            return;
        }
        if (totalAllocPoint == 0) {
            lastRewardTime = block.timestamp;
            return;
        }

        uint256 rewards = getRewards(lastRewardTime, block.timestamp);

        accTokenPerShare = accTokenPerShare + ((rewards * 1e12) / totalAllocPoint);
        lastRewardTime = block.timestamp;
    }

    // Deposit NFT to NFTStaking for DEEP allocation.
    function deposit(uint256 _tokenId) public {
        require(dKeeper.ownerOf(_tokenId) == msg.sender, "Invalid NFT owner");
        UserInfo storage user = userInfo[msg.sender];
        updatePool();

        if (user.amount != 0) {
            uint256 pending = (user.amount * accTokenPerShare) / 1e12 - user.rewardDebt;
            if (pending > 0) {
                safeDeepTransfer(msg.sender, pending);
                user.lastClaimTime = block.timestamp;
                emit Claimed(msg.sender, pending);
            }
        }

        dKeeper.safeTransferFrom(address(msg.sender), address(this), _tokenId);
        user.amount = user.amount + dKeeper.mintedPrice(_tokenId);
        user.lastStakeTime = block.timestamp;
        totalAllocPoint += dKeeper.mintedPrice(_tokenId);
        userNFTs[msg.sender][_tokenId] = stakedNFTs[msg.sender].length + 1;
        stakedNFTs[msg.sender].push(_tokenId);

        user.rewardDebt = (user.amount * accTokenPerShare) / 1e12;
        emit Deposited(msg.sender, _tokenId, dKeeper.mintedPrice(_tokenId));
    }

    // Withdraw NFT token.
    function withdraw(uint256 _tokenId) public {
        require(userNFTs[msg.sender][_tokenId] != 0, "Invalid NFT owner");
        UserInfo storage user = userInfo[msg.sender];

        updatePool();
        uint256 pending = (user.amount * accTokenPerShare) / 1e12 - user.rewardDebt;
        if (pending > 0) {
            safeDeepTransfer(msg.sender, pending);
            user.lastClaimTime = block.timestamp;
            emit Claimed(msg.sender, pending);
        }

        user.amount = user.amount - dKeeper.mintedPrice(_tokenId);
        dKeeper.safeTransferFrom(address(this), address(msg.sender), _tokenId);
        totalAllocPoint -= dKeeper.mintedPrice(_tokenId);

        // remove tokens from userInfo tokens array
        stakedNFTs[msg.sender][userNFTs[msg.sender][_tokenId] - 1] = stakedNFTs[msg.sender][
            stakedNFTs[msg.sender].length - 1
        ];
        stakedNFTs[msg.sender].pop();

        userNFTs[msg.sender][_tokenId] = 0;

        user.rewardDebt = (user.amount * accTokenPerShare) / 1e12;
        emit Withdrawn(msg.sender, _tokenId, dKeeper.mintedPrice(_tokenId));
    }

    // Claim rewards.
    function claim() public {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount != 0, "Not deposited NFTs.");
        updatePool();

        uint256 pending = (user.amount * accTokenPerShare) / 1e12 - user.rewardDebt;
        if (pending > 0) {
            safeDeepTransfer(msg.sender, pending);
            user.lastClaimTime = block.timestamp;
            emit Claimed(msg.sender, pending);
        }

        user.rewardDebt = (user.amount * accTokenPerShare) / 1e12;
    }

    // Safe DEEP transfer function, just in case if rounding error causes pool to not have enough DEEP
    function safeDeepTransfer(address _to, uint256 _amount) internal {
        dKeeperEscrow.mint(_to, _amount);
    }

    // Get rewards between block timestamps
    function getRewards(uint256 _from, uint256 _to) internal view returns (uint256 rewards) {
        while (_from + WEEK <= _to) {
            rewards += getRewardRatio(_from) * WEEK;
            _from = _from + WEEK;
        }

        if (_from + WEEK > _to) {
            rewards += getRewardRatio(_from) * (_to - _from);
        }
    }

    // Get rewardRatio from timestamp
    function getRewardRatio(uint256 _time) internal view returns (uint256) {
        if (52 < (_time - startTime) / WEEK) return 0;

        return (((1e25 * (52 - (_time - startTime) / WEEK)) / 52 / 265) * 10) / WEEK;
    }

    // Set escrow contract address
    function setEscrow(address _escrow) public onlyOwner {
        require(_escrow != address(0), "Invalid address");
        dKeeperEscrow = IDKeeperEscrow(_escrow);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
