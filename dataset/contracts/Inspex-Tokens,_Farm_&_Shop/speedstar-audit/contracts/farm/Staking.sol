//SPDX-License-Identifier: Unlicense
/*
░██████╗██████╗░███████╗███████╗██████╗░░░░░░░░██████╗████████╗░█████╗░██████╗░
██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗░░░░░░██╔════╝╚══██╔══╝██╔══██╗██╔══██╗
╚█████╗░██████╔╝█████╗░░█████╗░░██║░░██║█████╗╚█████╗░░░░██║░░░███████║██████╔╝
░╚═══██╗██╔═══╝░██╔══╝░░██╔══╝░░██║░░██║╚════╝░╚═══██╗░░░██║░░░██╔══██║██╔══██╗
██████╔╝██║░░░░░███████╗███████╗██████╔╝░░░░░░██████╔╝░░░██║░░░██║░░██║██║░░██║
╚═════╝░╚═╝░░░░░╚══════╝╚══════╝╚═════╝░░░░░░░╚═════╝░░░░╚═╝░░░╚═╝░░╚═╝╚═╝░░╚═╝
*/
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IHorse {
    function getPopularity(uint256 _tokenId) external view returns (uint256);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function isApprovedForAll(address owner, address operator)
        external
        returns (bool);

    function getRemainAge(uint256 _tokenId) external view returns (uint256);
}

interface IFacility {
    function popularity(uint256 _tokenId) external view returns (uint256);

    function multipliers(uint256 _tokenId) external view returns (uint256);

    function isApprovedForAll(address owner, address operator)
        external
        returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

interface ISpeed {
    function mint(address _receiver, uint256 _amount) external;

    function transfer(address _receiver, uint256 _amount) external;
}

contract Staking is Ownable, ERC721Holder {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    // Info of each user.
    struct UserInfo {
        mapping(uint256 => bool) ownedTokenId;
        mapping(uint256 => bool) ownedStable;
        mapping(uint256 => bool) ownedFacility;
        mapping(uint256 => uint256) horseIndex;
        mapping(uint256 => uint256) stableIndex;
        mapping(uint256 => uint256) facilityIndex;
        Horse[] horses;
        Stable[] stables;
        uint256[] facility;
        uint256 totalHorse;
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    struct Stable {
        mapping(uint256 => uint256) horseIndex;
        uint256 tokenId;
        Horse[] horses;
        uint256 multiplier;
        uint256 popularity;
    }

    struct Horse {
        uint256 tokenId;
        uint256 enterBlock;
        uint256 remainBlock;
        uint256 popularity;
    }

    // Info of each pool.
    struct PoolInfo {
        uint256 totalStake;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accSpeedPerShare;
    }

    // The Speed TOKEN!
    ISpeed public speed;
    ERC20 private star;
    IFacility private facility;
    IHorse private horse;
    // Dev address.
    address public devaddr;
    // WAG tokens created per block.
    uint256 public speedPerBlock;
    // Bonus muliplier for early cake makers.
    uint256 public BONUS_MULTIPLIER;
    // Info of each pool.
    PoolInfo public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;
    mapping(address => uint256) public starBalance;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The block number when Speed mining starts.
    uint256 public startBlock;

    event DepositHorse(
        address indexed user,
        uint256 popularity,
        uint256 tokenId
    );
    event DepositStable(
        address indexed user,
        uint256 popularity,
        uint256 tokenId
    );
    event DepositFacility(
        address indexed user,
        uint256 popularity,
        uint256 tokenId
    );
    event DepositHorseInStable(
        address indexed user,
        uint256 stableTokenId,
        uint256 popularity,
        uint256 horseTokenId
    );
    event WithdrawHorseInStable(
        address indexed user,
        uint256 stableTokenId,
        uint256 popularity,
        uint256 horseTokenId
    );
    event WithdrawStable(address indexed user, uint256 stableTokenId);
    event WithdrawFacility(
        address indexed user,
        uint256 tokenId,
        uint256 popularity
    );
    event WithdrawHorse(
        address indexed user,
        uint256 tokenId,
        uint256 popularity
    );
    event ClaimToken(address indexed user, address token);
    event DepositStar(address user, uint256 amount);
    event WithdrawStar(address user, uint256 amount);
    event SetSpeedPerBlock(address user, uint256 amount);

    modifier horseLimitStaking() {
        // start 2 slots to free stake. after that increase follower Star staking
        require(
            starBalance[msg.sender].add(2) > userInfo[msg.sender].totalHorse,
            "Slot not enough."
        );
        _;
    }

    constructor(
        address _speed,
        address _star,
        address _horse,
        address _facility,
        address _devaddr,
        uint256 _speedPerBlock,
        uint256 _startBlock
    )  {
     
        BONUS_MULTIPLIER = 1;
        star = ERC20(_star);
        speed = ISpeed(_speed);
        facility = IFacility(_facility);
        horse = IHorse(_horse);
        devaddr = _devaddr;
        speedPerBlock = _speedPerBlock;
        startBlock = _startBlock;

        // staking pool
        poolInfo = PoolInfo({
            totalStake: 0,
            allocPoint: 1000,
            lastRewardBlock: startBlock,
            accSpeedPerShare: 0
        });

        totalAllocPoint = 1000;
    }

    function setSpeedPerBlock(uint256 _amount) external onlyOwner {
        updatePool();
        emit SetSpeedPerBlock(msg.sender, _amount);
        speedPerBlock = _amount;
    }

    function depositStar(uint256 _amount) external {
        require(
            star.allowance(msg.sender, address(this)) >= _amount,
            "credit not enougth"
        );

        star.safeTransferFrom(msg.sender, address(this), _amount);
        starBalance[msg.sender] = starBalance[msg.sender].add(_amount);

        emit DepositStar(msg.sender, _amount);
    }

    function withdrawStar(uint256 _amount) external {
        require(starBalance[msg.sender] >= _amount, "withdraw over balance.");
        starBalance[msg.sender] = starBalance[msg.sender].sub(_amount);
        star.safeTransfer(msg.sender, _amount);

        emit WithdrawStar(msg.sender, _amount);
    }

    // For user claim token from offchain
    // Reserve gas for offchain call to deposit token to user.
    function claimToken(address _token) external payable {
        require(msg.value == 50000000 gwei, ""); //reserve 0.05 one for backend fee.
        emit ClaimToken(msg.sender, _token);
    }

    function updateMultiplier(uint256 multiplierNumber) external onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        PoolInfo storage pool = poolInfo;
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.totalStake;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 speedReward = multiplier
            .mul(speedPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
        speed.mint(address(this), speedReward);
        pool.accSpeedPerShare = pool.accSpeedPerShare.add(
            speedReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // View function to see pending Speed on frontend.
    function pendingSpeed(address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[_user];
        uint256 accSpeedPerShare = pool.accSpeedPerShare;
        uint256 lpSupply = pool.totalStake;

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            uint256 wagReward = multiplier
                .mul(speedPerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accSpeedPerShare = accSpeedPerShare.add(
                wagReward.mul(1e12).div(lpSupply)
            );
        }

        uint256 pending = user.amount.mul(accSpeedPerShare).div(1e12).sub(
            user.rewardDebt
        );

        if (pending > 0) {
            uint256 rewardPerAmount = pending.div(user.amount);
            uint256 normalizeReward;

            // calculate horse reward and popularlity
            (uint256 reward, ) = calculateReward(user.horses, rewardPerAmount);

            normalizeReward = normalizeReward.add(reward);

            for (uint256 index = 0; index < user.facility.length; index++) {
                normalizeReward = normalizeReward.add(
                    IFacility(facility).popularity(user.facility[index]).mul(
                        rewardPerAmount
                    )
                );
            }
            // calculate reward and update populality;
            for (uint256 index = 0; index < user.stables.length; index++) {
                Stable storage stable = user.stables[index];
                (uint256 horseReward, ) = calculateReward(
                    stable.horses,
                    rewardPerAmount
                );
                normalizeReward = normalizeReward.add(horseReward);
            }

            return normalizeReward;
        } else {
            return 0;
        }
    }

    function payReward(UserInfo storage _user) internal {
        uint256 pending = _user
            .amount
            .mul(poolInfo.accSpeedPerShare)
            .div(1e12)
            .sub(_user.rewardDebt);

        if (pending > 0) {
            uint256 rewardPerAmount = pending.div(_user.amount);
            uint256 normalizeReward;
            uint256 newPopularity;
            // calculate horse reward and popularlity
            (
                uint256 reward,
                uint256 popularlity
            ) = calculateRewardAndUpdateRemainHorse(
                    _user.horses,
                    rewardPerAmount
                );

            normalizeReward = normalizeReward.add(reward);
            newPopularity = popularlity;

            for (uint256 index = 0; index < _user.facility.length; index++) {
                uint256 facilityPopularlity = IFacility(facility).popularity(
                    _user.facility[index]
                );
                normalizeReward = normalizeReward.add(
                    facilityPopularlity.mul(rewardPerAmount)
                );
                newPopularity = newPopularity.add(facilityPopularlity);
            }
            // calculate reward and update populality;
            for (uint256 index = 0; index < _user.stables.length; index++) {
                Stable storage stable = _user.stables[index];
                (
                    uint256 horseReward,
                    uint256 totalPopularlity
                ) = calculateRewardAndUpdateRemainHorse(
                        stable.horses,
                        rewardPerAmount
                    );
                normalizeReward = normalizeReward.add(horseReward);
                stable.popularity = totalPopularlity.mul(stable.multiplier);
                newPopularity = newPopularity.add(stable.popularity);
            }

            require(
                newPopularity <= pending,
                "normalizeReward is not over pending reward."
            );
            _user.amount = newPopularity;
            safeSpeedTransfer(msg.sender, normalizeReward);
        }
    }

    function calculateReward(Horse[] memory _horses, uint256 _rewardPerAmount)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 normalizeReward;
        uint256 totalPopularlity;

        for (uint256 index = 0; index < _horses.length; index++) {
            Horse memory _horse = _horses[index];

            uint256 runningBlock = block.number - _horse.enterBlock;
            uint256 rewardPerBlock = _rewardPerAmount.div(runningBlock);
            uint256 retriedReward = rewardPerBlock.div(5);

            if (runningBlock > _horse.remainBlock) {
                uint256 retriedBlock = runningBlock - _horse.remainBlock;
                normalizeReward = normalizeReward.add(
                    _horse.remainBlock.mul(rewardPerBlock).mul(
                        _horse.popularity
                    )
                );
                normalizeReward = normalizeReward.add(
                    retriedBlock.mul(retriedReward).mul(_horse.popularity)
                );
            } else {
                normalizeReward = normalizeReward.add(
                    runningBlock.mul(rewardPerBlock).mul(_horse.popularity)
                );
            }
            totalPopularlity = totalPopularlity.add(_horse.popularity);
        }
        return (normalizeReward, totalPopularlity);
    }

    function calculateRewardAndUpdateRemainHorse(
        Horse[] storage _horses,
        uint256 _rewardPerAmount
    ) internal returns (uint256, uint256) {
        uint256 normalizeReward;
        uint256 totalPopularlity;

        for (uint256 index = 0; index < _horses.length; index++) {
            Horse storage _horse = _horses[index];

            uint256 runningBlock = block.number - _horse.enterBlock;
            uint256 rewardPerBlock = _rewardPerAmount.div(runningBlock);
            uint256 retriedReward = rewardPerBlock.div(5);

            if (runningBlock > _horse.remainBlock) {
                uint256 retriedBlock = runningBlock - _horse.remainBlock;
                normalizeReward = normalizeReward.add(
                    _horse.remainBlock.mul(rewardPerBlock).mul(
                        _horse.popularity
                    )
                );
                normalizeReward = normalizeReward.add(
                    retriedBlock.mul(retriedReward).mul(_horse.popularity)
                );
                _horse.popularity = _horse.popularity.div(5);

                _horse.remainBlock = 0;
            } else {
                normalizeReward = normalizeReward.add(
                    runningBlock.mul(rewardPerBlock).mul(_horse.popularity) // 2x
                );
                _horse.remainBlock = _horse.remainBlock.sub(runningBlock);
            }

            totalPopularlity = totalPopularlity.add(_horse.popularity);
        }

        return (normalizeReward, totalPopularlity);
    }

    function getPopularityInStable(uint256 _stableId)
        public
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[msg.sender];
        uint256 popularity;
        for (uint256 index = 0; index < user.stables.length; index++) {
            if (user.stables[index].tokenId == _stableId) {
                for (
                    uint256 j = 0;
                    j < user.stables[index].horses.length;
                    j++
                ) {
                    popularity = popularity.add(
                        user.stables[index].horses[j].popularity
                    );
                }
                popularity = popularity.mul(user.stables[index].multiplier);

                break;
            }
        }

        return popularity;
    }

    function depositFacility(uint256 _tokenId) external {
        UserInfo storage user = userInfo[msg.sender];
        require(!user.ownedFacility[_tokenId], "Already staking");

        updatePool();
        if (user.amount > 0) {
            payReward(user);
        }

        facility.safeTransferFrom(address(msg.sender), address(this), _tokenId);

        // update amount
        uint256 popularity = facility.popularity(_tokenId);
        user.amount = user.amount.add(popularity);
        user.ownedFacility[_tokenId] = true;

        user.facilityIndex[_tokenId] = user.facility.length;
        user.facility.push(_tokenId);

        emit DepositFacility(msg.sender, 0, _tokenId);
    }

    function withdrawFacility(uint256 _tokenId) external {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        require(user.ownedFacility[_tokenId], "No facility staking");
        user.ownedFacility[_tokenId] = false;
        updatePool();
        uint256 pending = user.amount.mul(pool.accSpeedPerShare).div(1e12).sub(
            user.rewardDebt
        );
        if (pending > 0) {
            payReward(user);
        }

        facility.safeTransferFrom(address(this), address(msg.sender), _tokenId);

        // swapIndex
        user.facility[user.facilityIndex[_tokenId]] = user.facility[
            user.facility.length.sub(1)
        ];
        // update index
        user.facilityIndex[user.facility[user.facilityIndex[_tokenId]]] = user
            .facilityIndex[_tokenId];

        user.facility.pop();
        // update amount
        uint256 popularity = facility.popularity(_tokenId);

        user.amount = user.amount.sub(popularity);
        user.rewardDebt = user.amount.mul(pool.accSpeedPerShare).div(1e12);

        emit WithdrawFacility(msg.sender, _tokenId, popularity);
    }

    function depositStable(uint256 _tokenId) external {
        UserInfo storage user = userInfo[msg.sender];
        require(!user.ownedStable[_tokenId], "Already staking");

        updatePool();
        if (user.amount > 0) {
            payReward(user);
        }
        uint256 multiplier = facility.multipliers(_tokenId);
        facility.safeTransferFrom(address(msg.sender), address(this), _tokenId);

        Stable[] storage userStable = user.stables;
        user.stableIndex[_tokenId] = userStable.length;
        user.ownedStable[_tokenId] = true;
        userStable.push();

        Stable storage newStable = userStable[user.stableIndex[_tokenId]];
        newStable.tokenId = _tokenId;
        newStable.multiplier = multiplier;

        emit DepositStable(msg.sender, 0, _tokenId);
    }

    function withdrawStable(uint256 _stableTokenId) external {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        require(user.ownedStable[_stableTokenId], "No stable staking");

        updatePool();
        uint256 pending = user.amount.mul(pool.accSpeedPerShare).div(1e12).sub(
            user.rewardDebt
        );
        if (pending > 0) {
            payReward(user);
        }

        Stable[] storage userStable = user.stables;
        Stable storage stable = userStable[user.stableIndex[_stableTokenId]];
        // unstake all horse in stable
        Horse[] memory horses = stable.horses;
        for (uint256 index = 0; index < horses.length; index++) {
            withdrawHorseInStable(_stableTokenId, horses[index].tokenId);
        }
        // transfer stable to user
        facility.safeTransferFrom(
            address(this),
            address(msg.sender),
            _stableTokenId
        );
        // update stable data instead.
        stable = user.stables[userStable.length - 1];
        user.stableIndex[stable.tokenId] = user.stableIndex[_stableTokenId];
        user.stables.pop();
        user.ownedStable[_stableTokenId] = false;
        user.rewardDebt = user.amount.mul(pool.accSpeedPerShare).div(1e12);

        emit WithdrawStable(msg.sender, _stableTokenId);
    }

    function depositHorseInStable(uint256 _stableTokenId, uint256 _horseTokenId)
        external horseLimitStaking
    {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];

        require(user.ownedStable[_stableTokenId], "No stable staking");

        updatePool();
        if (user.amount > 0) {
            payReward(user);
        }

        uint256 popularity = horse.getPopularity(_horseTokenId);

        Stable storage stable = user.stables[user.stableIndex[_stableTokenId]];
        //always stable has capacity 2 slot .
        require(stable.horses.length < 2, "over capacity");
        // trasfer horse from owner to contract
        horse.safeTransferFrom(
            address(msg.sender),
            address(this),
            _horseTokenId
        );
        // update info owner
        user.ownedTokenId[_horseTokenId] = true;
        stable.horseIndex[_horseTokenId] = stable.horses.length;
        stable.horses.push(
            Horse(
                _horseTokenId,
                block.number,
                horse.getRemainAge(_horseTokenId),
                popularity
            )
        );
        // update amount
        user.amount = user.amount.add(popularity.mul(stable.multiplier));

        user.rewardDebt = user.amount.mul(pool.accSpeedPerShare).div(1e12);
        emit DepositHorseInStable(
            msg.sender,
            _stableTokenId,
            popularity,
            _horseTokenId
        );
    }

    function withdrawHorseInStable(
        uint256 _stableTokenId,
        uint256 _horseTokenId
    ) public {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        require(user.ownedStable[_stableTokenId], "No stable staking");

        updatePool();
        uint256 pending = user.amount.mul(pool.accSpeedPerShare).div(1e12).sub(
            user.rewardDebt
        );

        if (pending > 0) {
            payReward(user);
        }
        Stable storage stable = user.stables[user.stableIndex[_stableTokenId]];

        horse.safeTransferFrom(
            address(this),
            address(msg.sender),
            _horseTokenId
        );
        // decrease amount from this stable
        user.amount = user.amount.sub(getPopularityInStable(_stableTokenId));
        // remove horse instable
        user.ownedTokenId[_horseTokenId] = false;
        removeHorseFromList(stable.horses, stable.horseIndex[_horseTokenId]);
        delete stable.horseIndex[_horseTokenId];
        // update amount
        user.amount = user.amount.add(getPopularityInStable(_stableTokenId));
        user.rewardDebt = user.amount.mul(pool.accSpeedPerShare).div(1e12);

        emit WithdrawHorseInStable(
            msg.sender,
            _stableTokenId,
            horse.getPopularity(_horseTokenId),
            _horseTokenId
        );
    }

    function depositHorse(uint256 _tokenId) external horseLimitStaking{
        require(
            horse.isApprovedForAll(msg.sender, address(this)),
            "Please set approval"
        );
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        require(!user.ownedTokenId[_tokenId], "Already staking");

        updatePool();
        if (user.amount > 0) {
            payReward(user);
        }

        uint256 popularity = horse.getPopularity(_tokenId);

        horse.safeTransferFrom(address(msg.sender), address(this), _tokenId);
        user.ownedTokenId[_tokenId] = true;
        user.horseIndex[_tokenId] = user.horses.length;
        user.amount = user.amount.add(popularity);
        user.horses.push(
            Horse(
                _tokenId,
                block.number,
                horse.getRemainAge(_tokenId),
                popularity
            )
        );

        pool.totalStake = pool.totalStake.add(popularity);

        user.rewardDebt = user.amount.mul(pool.accSpeedPerShare).div(1e12);
        emit DepositHorse(msg.sender, popularity, _tokenId);
    }

    function withdrawHorse(uint256 _tokenId) external {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        require(user.ownedTokenId[_tokenId], "withdraw: not good");

        updatePool();
        uint256 pending = user.amount.mul(pool.accSpeedPerShare).div(1e12).sub(
            user.rewardDebt
        );

        if (pending > 0) {
            payReward(user);
        }

        uint256 popularity = horse.getPopularity(_tokenId);

        uint256 lastTokenId = user.horses[user.horses.length - 1].tokenId;
        // delete horse from list.
        removeHorseFromList(user.horses, user.horseIndex[_tokenId]);
        // update index.
        user.horseIndex[lastTokenId] = user.horseIndex[_tokenId];

        delete user.horseIndex[_tokenId];
        user.amount = user.amount.sub(popularity);
        user.ownedTokenId[_tokenId] = false;
        horse.safeTransferFrom(address(this), address(msg.sender), _tokenId);

        pool.totalStake = pool.totalStake.sub(popularity);

        user.rewardDebt = user.amount.mul(pool.accSpeedPerShare).div(1e12);
        emit WithdrawHorse(msg.sender, _tokenId, popularity);
    }

    function removeHorseFromList(Horse[] storage _horses, uint256 _index)
        internal
    {
        if (_horses.length != 1) {
            // swap
            _horses[_index] = _horses[_horses.length - 1];
        }

        _horses.pop();
    }

    function claim() external {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = user.amount.mul(pool.accSpeedPerShare).div(1e12).sub(
            user.rewardDebt
        );
        if (pending > 0) {
            user.rewardDebt = user.amount.mul(pool.accSpeedPerShare).div(1e12);
            payReward(user);
        }
    }

    // Safe wag transfer function, just in case if rounding error causes pool to not have enough Wags.
    function safeSpeedTransfer(address _to, uint256 _amount) internal {
        speed.transfer(_to, _amount);
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) external {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}
