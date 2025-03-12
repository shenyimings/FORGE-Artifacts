// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/Ownable.sol";
import "./utils/ReentrancyGuard.sol";
import "./utils/SafeERC20.sol";
import "./ERC20.sol";
import "./interfaces/IYFIAGNftMarketplace.sol";
import "./utils/Address.sol";

contract YFIAGLaunchPad is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;
    using Address for address;

    // CONSTANTS

    // number of decimals of rollover factors
    uint64 constant ROLLOVER_FACTOR_DECIMALS = 10**18;

    // STRUCTS

    // A checkpoint for marking stake info at a given block
    struct UserCheckpoint {
        // block number of checkpoint
        uint80 blockNumber;
        // amount staked at checkpoint
        uint104 staked;
        // amount of stake weight at checkpoint
        uint192 stakeWeight;
        // number of finished sales at time of checkpoint
        uint24 numFinishedSales;
    }

    // A checkpoint for marking stake info at a given block
    struct LaunchpadCheckpoint {
        // block number of checkpoint
        uint80 blockNumber;
        // amount staked at checkpoint
        uint104 totalStaked;
        // amount of stake weight at checkpoint
        uint192 totalStakeWeight;
        // number of finished sales at time of checkpoint
        uint24 numFinishedSales;
    }

    // Info of each launchpad. These parameters cannot be changed.
    struct LaunchpadInfo {
        // name of launchpad
        string name;
        // token to stake (e.g., YFIAG)
        ERC20 stakeToken;
        // weight accrual rate for this launchpad (stake weight increase per block per stake token)
        uint24 weightAccrualRate;
        //the root id that the stake participant will receive
        uint256 rootIdToken;
        // start time of launchpad
        uint256 startTime;
        // end time of launchpad
        uint256 endTime;
        // maximum total stake for a user in this launchpad
        uint104 minTotalStake;
    }

    // INFO FOR FACTORING IN ROLLOVERS

    // the number of checkpoints of a launchpad -- (launchpad, finished sale count) => block number
    mapping(uint24 => mapping(uint24 => uint80)) public launchpadFinishedSaleBlocks;

    // Launchpad INFO

    // array of launchpad information
    LaunchpadInfo[] public launchpads;

    // whether launchpad is disabled -- (launchpad) => disabled status
    mapping(uint24 => bool) public launchpadDisabled;

    // emergency launchpad flag -- (launchpad) => emergency status
    mapping(uint24 => bool) public launchpadEmergency;

    // number of unique stakers on launchpad -- (launchpad) => staker count
    mapping(uint24 => uint256) public numLaunchPadStakers;

    // array of unique stakers on launchpad -- (launchpad) => address array
    // users are only added on first checkpoint to maintain unique
    mapping(uint24 => address[]) public launchpadStakers;

    // the number of checkpoints of a launchpad -- (launchpad) => checkpoint count
    mapping(uint24 => uint32) public launchpadCheckpointCount;

    // launchpad checkpoint mapping -- (launchpad, checkpoint number) => LaunchpadCheckpoint
    mapping(uint24 => mapping(uint32 => LaunchpadCheckpoint))
        public launchpadCheckpoints;

    // USER INFO

    // the number of checkpoints of a user for a launchpad -- (launchpad, user address) => checkpoint count
    mapping(uint24 => mapping(address => uint32)) public userCheckpointCounts;

    // user checkpoint mapping -- (launchpad, user address, checkpoint number) => UserCheckpoint
    mapping(uint24 => mapping(address => mapping(uint32 => UserCheckpoint)))
        public userCheckpoints;
    // winner mapping -- (launchpad, user address) => is winner of launchpad?
    mapping(uint24 => mapping(address => bool)) public winners;

    //YFIAGNftMarketplace
    address public YFIAGNftMarketplace;

    // balance of Fee launchpad--(launchpad) => balances
    mapping (uint24 => uint256) balanceOfLaunchpad;

    // check already claim --(launchpad, sender) => bool (is claimed)
    mapping (uint24 => mapping(address => bool)) isClaimed;

    // check is stakers --(launchpad, sender) => bool(is staked)
    mapping(uint24 => mapping(address => bool)) isStakers;

    // EVENTS

    event AddLaunchpad(uint24 indexed launchpadId,string indexed name, address indexed token, uint256 rootIdToken);
    event DisableLaunchpad(uint24 indexed launchpadId);
    event AddUserCheckpoint(uint24 indexed launchpadId, uint80 blockNumber);
    event AddLaunchpadCheckpoint(uint24 indexed launchpadId, uint80 blockNumber);
    event Stake(uint24 indexed launchpadId, address indexed user, uint104 amount);
    event Unstake(uint24 indexed launchpadId, address indexed user, uint104 amount);
    event Claim(uint24 indexed launchpadId, address indexed user, uint256 indexed rootIdToken);

    // MODIFIER

    modifier launchpadNotFound(uint24 launchpadId){
        require(launchpadId <= launchpads.length, "LP isn't exist");
        _;
    }

    // CONSTRUCTOR

    constructor(address _YFIAGNftMarketplace) {
        YFIAGNftMarketplace = _YFIAGNftMarketplace;
    }

    // FUNCTIONS

    // number of Launchpads
    function launchpadCount() external view returns (uint24) {
        return uint24(launchpads.length);
    }

    function getBalancesOfLaunchpad(uint24 launchpadId) public view returns(uint256){
        return balanceOfLaunchpad[launchpadId];
    }

    // get closest PRECEDING user checkpoint
    function getClosestUserCheckpoint(
        uint24 launchpadId,
        address user,
        uint80 blockNumber
    ) private view returns (UserCheckpoint memory cp) {
        // get total checkpoint count for user
        uint32 nCheckpoints = userCheckpointCounts[launchpadId][user];

        if (
            userCheckpoints[launchpadId][user][nCheckpoints - 1].blockNumber <=
            blockNumber
        ) {
            // First check most recent checkpoint

            // return closest checkpoint
            return userCheckpoints[launchpadId][user][nCheckpoints - 1];
        } else if (
            userCheckpoints[launchpadId][user][0].blockNumber > blockNumber
        ) {
            // Next check earliest checkpoint

            // If specified block number is earlier than user"s first checkpoint,
            // return null checkpoint
            return
                UserCheckpoint({
                    blockNumber: 0,
                    staked: 0,
                    stakeWeight: 0,
                    numFinishedSales: 0
                });
        } else {
            // binary search on checkpoints
            uint32 lower = 0;
            uint32 upper = nCheckpoints - 1;
            while (upper > lower) {
                uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
                UserCheckpoint memory tempCp = userCheckpoints[launchpadId][user][
                    center
                ];
                if (tempCp.blockNumber == blockNumber) {
                    return tempCp;
                } else if (tempCp.blockNumber < blockNumber) {
                    lower = center;
                } else {
                    upper = center - 1;
                }
            }

            // return closest checkpoint
            return userCheckpoints[launchpadId][user][lower];
        }
    }

    // gets a user"s stake weight within a launchpad at a particular block number
    // logic extended from Compound COMP token `getPriorVotes` function
    function getUserStakeWeight(
        uint24 launchpadId,
        address user,
        uint80 blockNumber
    ) public view returns (uint192) {
        require(blockNumber <= block.number, "block # too high");

        // if launchpad is disabled, stake weight is 0
        if (launchpadDisabled[launchpadId]) return 0;

        // check number of user checkpoints
        uint32 nUserCheckpoints = userCheckpointCounts[launchpadId][user];
        if (nUserCheckpoints == 0) {
            return 0;
        }

        // get closest preceding user checkpoint
        UserCheckpoint memory closestUserCheckpoint = getClosestUserCheckpoint(
            launchpadId,
            user,
            blockNumber
        );

        // check if closest preceding checkpoint was null checkpoint
        if (closestUserCheckpoint.blockNumber == 0) {
            return 0;
        }

        // get closest preceding launchpad checkpoint

        LaunchpadCheckpoint memory closestLaunchpadCp = getClosestLaunchpadCheckpoint(
            launchpadId,
            blockNumber
        );

        // get number of finished sales between user"s last checkpoint blockNumber and provided blockNumber
        uint24 numFinishedSalesDelta = closestLaunchpadCp.numFinishedSales -
            closestUserCheckpoint.numFinishedSales;

        // get launchpad info
        LaunchpadInfo memory launchpad = launchpads[launchpadId];

        // calculate stake weight given above delta
        uint192 stakeWeight;
        if (numFinishedSalesDelta == 0) {
            // calculate normally without rollover decay

            uint80 elapsedBlocks = blockNumber -
                closestUserCheckpoint.blockNumber;

            stakeWeight =
                closestUserCheckpoint.stakeWeight +
                (uint192(elapsedBlocks) *
                    launchpad.weightAccrualRate *
                    closestUserCheckpoint.staked) /
                10**18;

            return stakeWeight;
        } else {
            // calculate with rollover decay

            // starting stakeweight
            stakeWeight = closestUserCheckpoint.stakeWeight;
            // current block for iteration
            uint80 currBlock = closestUserCheckpoint.blockNumber;

            // for each finished sale in between, get stake weight of that period
            // and perform weighted sum
            for (uint24 i = 0; i < numFinishedSalesDelta; i++) {
                // get number of blocks passed at the current sale number
                uint80 elapsedBlocks = launchpadFinishedSaleBlocks[launchpadId][
                    closestUserCheckpoint.numFinishedSales + i
                ] - currBlock;

                // update stake weight
                stakeWeight =
                    stakeWeight +
                    (uint192(elapsedBlocks) *
                        launchpad.weightAccrualRate *
                        closestUserCheckpoint.staked) /
                    10**18;


                // factor in passive and active rollover decay
                stakeWeight =
                    // decay passive weight
                    ((stakeWeight)) /
                    ROLLOVER_FACTOR_DECIMALS;

                // update currBlock for next round
                currBlock = launchpadFinishedSaleBlocks[launchpadId][
                    closestUserCheckpoint.numFinishedSales + i
                ];
            }

            // add any remaining accrued stake weight at current finished sale count
            uint80 remainingElapsed = blockNumber -
                launchpadFinishedSaleBlocks[launchpadId][
                    closestLaunchpadCp.numFinishedSales - 1
                ];
            stakeWeight +=
                (uint192(remainingElapsed) *
                    launchpad.weightAccrualRate *
                    closestUserCheckpoint.staked) /
                10**18;
        }

        // return
        return stakeWeight;
    }

    // get closest PRECEDING launchpad checkpoint
    function getClosestLaunchpadCheckpoint(uint24 launchpadId, uint80 blockNumber)
        private
        view
        returns (LaunchpadCheckpoint memory cp)
    {
        // get total checkpoint count for launchpad
        uint32 nCheckpoints = launchpadCheckpointCount[launchpadId];

        if (
            launchpadCheckpoints[launchpadId][nCheckpoints - 1].blockNumber <=
            blockNumber
        ) {
            // First check most recent checkpoint

            // return closest checkpoint
            return launchpadCheckpoints[launchpadId][nCheckpoints - 1];
        } else if (launchpadCheckpoints[launchpadId][0].blockNumber > blockNumber) {
            // Next check earliest checkpoint

            // If specified block number is earlier than launchpad"s first checkpoint,
            // return null checkpoint
            return
                LaunchpadCheckpoint({
                    blockNumber: 0,
                    totalStaked: 0,
                    totalStakeWeight: 0,
                    numFinishedSales: 0
                });
        } else {
            // binary search on checkpoints
            uint32 lower = 0;
            uint32 upper = nCheckpoints - 1;
            while (upper > lower) {
                uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
                LaunchpadCheckpoint memory tempCp = launchpadCheckpoints[launchpadId][
                    center
                ];
                if (tempCp.blockNumber == blockNumber) {
                    return tempCp;
                } else if (tempCp.blockNumber < blockNumber) {
                    lower = center;
                } else {
                    upper = center - 1;
                }
            }

            // return closest checkpoint
            return launchpadCheckpoints[launchpadId][lower];
        }
    }

    // gets total stake weight within a launchpad at a particular block number
    // logic extended from Compound COMP token `getPriorVotes` function
    function getTotalStakeWeight(uint24 launchpadId, uint80 blockNumber)
        external
        view
        returns (uint192)
    {
        require(blockNumber <= block.number, "block # too high");

        // if launchpad is disabled, stake weight is 0
        if (launchpadDisabled[launchpadId]) return 0;

        // get closest launchpad checkpoint
        LaunchpadCheckpoint memory closestCheckpoint = getClosestLaunchpadCheckpoint(
            launchpadId,
            blockNumber
        );

        // check if closest preceding checkpoint was null checkpoint
        if (closestCheckpoint.blockNumber == 0) {
            return 0;
        }

        // calculate blocks elapsed since checkpoint
        uint80 additionalBlocks = (blockNumber - closestCheckpoint.blockNumber);

        // get launchpad info
        LaunchpadInfo storage launchpadInfo = launchpads[launchpadId];

        // calculate marginal accrued stake weight
        uint192 marginalAccruedStakeWeight = (uint192(additionalBlocks) *
            launchpadInfo.weightAccrualRate *
            closestCheckpoint.totalStaked) / 10**18;

        // return
        return closestCheckpoint.totalStakeWeight + marginalAccruedStakeWeight;
    }

    function getTotalStakedLaunchpad(uint24 launchpadId) public view returns(uint104) {
        // get launchpad checkpoint count
        uint32 nCheckpointsLaunchpad = launchpadCheckpointCount[launchpadId];

        // get latest launchpad checkpoint
        LaunchpadCheckpoint memory launchpadCp = launchpadCheckpoints[launchpadId][
            nCheckpointsLaunchpad - 1
        ];

        return launchpadCp.totalStaked;
    }

    function getTotalStakedUser(uint24 launchpadId, address user) public view returns(uint104) {
         // get number of user"s checkpoints within this launchpad
        uint32 userCheckpointCount = userCheckpointCounts[launchpadId][
            user
        ];

        if(userCheckpointCount == 0){
            return 0;
        }

        // get user"s latest checkpoint
        UserCheckpoint storage checkpoint = userCheckpoints[launchpadId][
            user
        ][userCheckpointCount - 1];

        return checkpoint.staked;
    }

    function amountRefundToken(uint24 launchpadId, address user) public view returns(uint104) {
        // get launchpad info
        LaunchpadInfo storage launchpad = launchpads[launchpadId];

        // get number of user"s checkpoints within this launchpad
        uint32 userCheckpointCount = userCheckpointCounts[launchpadId][
            user
        ];

        if(userCheckpointCount == 0){
            return 0;
        }

        // get user"s latest checkpoint
        UserCheckpoint storage checkpoint = userCheckpoints[launchpadId][
            user
        ][userCheckpointCount - 1];

        if(launchpadDisabled[launchpadId]){
            if(winners[launchpadId][user]){
                return uint104(checkpoint.staked - launchpad.minTotalStake);
            }else{
                return uint104(checkpoint.staked);
            }
        }

        if(!launchpadDisabled[launchpadId]){
            return uint104(checkpoint.staked - launchpad.minTotalStake);
        }
        return 0;
    }

    function getAllStakers(uint24 launchpadId) public view returns(address[] memory){
        return launchpadStakers[launchpadId];
    }

    function addUserCheckpoint(
        uint24 launchpadId,
        uint104 amount,
        bool addElseSub
    ) internal {
        // get launchpad info
        LaunchpadInfo storage launchpad = launchpads[launchpadId];

        // get user checkpoint count
        uint32 nCheckpointsUser = userCheckpointCounts[launchpadId][_msgSender()];

        // get launchpad checkpoint count
        uint32 nCheckpointsLaunchpad = launchpadCheckpointCount[launchpadId];

        // get latest launchpad checkpoint
        LaunchpadCheckpoint memory LaunchpadCp = launchpadCheckpoints[launchpadId][
            nCheckpointsLaunchpad - 1
        ];

        // if this is first checkpoint
        if (nCheckpointsUser == 0) {
            // check if amount exceeds maximum
            require(amount >= launchpad.minTotalStake, "exceeds staking cap");

            // add user to stakers list of launchpad
            launchpadStakers[launchpadId].push(_msgSender());

            // increment stakers count on launchpad
            numLaunchPadStakers[launchpadId]++;

            // add a first checkpoint for this user on this launchpad
            userCheckpoints[launchpadId][_msgSender()][0] = UserCheckpoint({
                blockNumber: uint80(block.number),
                staked: amount,
                stakeWeight: 0,
                numFinishedSales: LaunchpadCp.numFinishedSales
            });

            // increment user"s checkpoint count
            userCheckpointCounts[launchpadId][_msgSender()] = nCheckpointsUser + 1;
        } else {
            // get previous checkpoint
            UserCheckpoint storage prev = userCheckpoints[launchpadId][
                _msgSender()
            ][nCheckpointsUser - 1];


            // ensure block number downcast to uint80 is monotonically increasing (prevent overflow)
            // this should never happen within the lifetime of the universe, but if it does, this prevents a catastrophe
            require(
                prev.blockNumber <= uint80(block.number),
                "block # overflow"
            );

            // add a new checkpoint for user within this launchpad
            // if no blocks elapsed, just update prev checkpoint (so checkpoints can be uniquely identified by block number)
            if (prev.blockNumber == uint80(block.number)) {
                prev.staked = addElseSub
                    ? prev.staked + amount
                    : prev.staked - amount;
                prev.numFinishedSales = LaunchpadCp.numFinishedSales;
            } else {
                userCheckpoints[launchpadId][_msgSender()][
                    nCheckpointsUser
                ] = UserCheckpoint({
                    blockNumber: uint80(block.number),
                    staked: addElseSub
                        ? prev.staked + amount
                        : prev.staked - amount,
                    stakeWeight: getUserStakeWeight(
                        launchpadId,
                        _msgSender(),
                        uint80(block.number)
                    ),
                    numFinishedSales: LaunchpadCp.numFinishedSales
                });

                // increment user"s checkpoint count
                userCheckpointCounts[launchpadId][_msgSender()] =
                    nCheckpointsUser +
                    1;
            }
        }

        // emit
        emit AddUserCheckpoint(launchpadId, uint80(block.number));
    }

    function addLaunchpadCheckpoint(
        uint24 launchpadId, // launchpad number
        uint104 amount, // delta on staked amount
        bool addElseSub, // true = adding; false = subtracting
        bool _bumpSaleCounter // whether to increase sale counter by 1
    ) internal {
        // get launchpad info
        LaunchpadInfo storage launchpad = launchpads[launchpadId];

        // get launchpad checkpoint count
        uint32 nCheckpoints = launchpadCheckpointCount[launchpadId];

        // if this is first checkpoint
        if (nCheckpoints == 0) {
            // add a first checkpoint for this launchpad
            launchpadCheckpoints[launchpadId][0] = LaunchpadCheckpoint({
                blockNumber: uint80(block.number),
                totalStaked: amount,
                totalStakeWeight: 0,
                numFinishedSales: _bumpSaleCounter ? 1 : 0
            });

            // increase new launchpad"s checkpoint count by 1
            launchpadCheckpointCount[launchpadId]++;
        } else {
            // get previous checkpoint
            LaunchpadCheckpoint storage prev = launchpadCheckpoints[launchpadId][
                nCheckpoints - 1
            ];

            // get whether launchpad is disabled
            bool isDisabled = launchpadDisabled[launchpadId];

            if (isDisabled) {
                // if previous checkpoint was disabled, then cannot increase stake going forward
                require(!addElseSub, "disabled: cannot add stake");
            }

            // ensure block number downcast to uint80 is monotonically increasing (prevent overflow)
            // this should never happen within the lifetime of the universe, but if it does, this prevents a catastrophe
            require(
                prev.blockNumber <= uint80(block.number),
                "block # overflow"
            );

            // calculate blocks elapsed since checkpoint
            uint80 additionalBlocks = (uint80(block.number) - prev.blockNumber);

            // calculate marginal accrued stake weight
            uint192 marginalAccruedStakeWeight = (uint192(additionalBlocks) *
                launchpad.weightAccrualRate *
                prev.totalStaked) / 10**18;

            // calculate new stake weight
            uint192 newStakeWeight = prev.totalStakeWeight +
                marginalAccruedStakeWeight;

            // add a new checkpoint for this launchpad
            // if no blocks elapsed, just update prev checkpoint (so checkpoints can be uniquely identified by block number)
            if (additionalBlocks == 0) {
                prev.totalStaked = addElseSub
                    ? prev.totalStaked + amount
                    : prev.totalStaked - amount;
                prev.totalStakeWeight = isDisabled
                    ? (
                        prev.totalStakeWeight < newStakeWeight
                            ? prev.totalStakeWeight
                            : newStakeWeight
                    )
                    : newStakeWeight;
                prev.numFinishedSales = _bumpSaleCounter
                    ? prev.numFinishedSales + 1
                    : prev.numFinishedSales;
            } else {
                launchpadCheckpoints[launchpadId][nCheckpoints] = LaunchpadCheckpoint({
                    blockNumber: uint80(block.number),
                    totalStaked: addElseSub
                        ? prev.totalStaked + amount
                        : prev.totalStaked - amount,
                    totalStakeWeight: isDisabled
                        ? (
                            prev.totalStakeWeight < newStakeWeight
                                ? prev.totalStakeWeight
                                : newStakeWeight
                        )
                        : newStakeWeight,
                    numFinishedSales: _bumpSaleCounter
                        ? prev.numFinishedSales + 1
                        : prev.numFinishedSales
                });

                // increase new launchpad"s checkpoint count by 1
                launchpadCheckpointCount[launchpadId]++;
            }
        }

        // emit
        emit AddLaunchpadCheckpoint(launchpadId, uint80(block.number));
    }

    // adds a new launchpad
    function addLaunchPad(
        string calldata name,
        ERC20 stakeToken,
        uint24 _weightAccrualRate,
        uint256 _rootId,
        uint256 _startTime,
        uint256 _endTime,
        uint104 _minTotalStake
    ) external onlyOwner {
        require(_weightAccrualRate != 0, "accrual rate = 0");
        require(_endTime > _startTime, "Invalid time");
        require(_endTime > block.timestamp, "Invalid time");

        // add launchpad
        launchpads.push(
            LaunchpadInfo({
                name: name, // name of launchpad
                stakeToken: stakeToken, // token to stake (e.g., YFIAG)
                weightAccrualRate: _weightAccrualRate, // rate of stake weight accrual
                rootIdToken: _rootId, // root id token
                startTime: _startTime, // time start launchpad
                endTime: _endTime, // time end launchpad
                minTotalStake: _minTotalStake // max total stake
            })
        );

        // add first launchpad checkpoint
        addLaunchpadCheckpoint(
            uint24(launchpads.length - 1), // latest launchpad
            0, // initialize with 0 stake
            false, // add or sub does not matter
            false // do not bump finished sale counter
        );

        // emit
        emit AddLaunchpad(uint24(launchpads.length - 1),name, address(stakeToken), _rootId);
    }

    // disables a launchpad
    function disableLaunchpad(uint24 launchpadId) external onlyOwner launchpadNotFound(launchpadId){
        // set disabled
        launchpadDisabled[launchpadId] = true;

         // get launchpad info
        LaunchpadInfo storage launchpad = launchpads[launchpadId];

        // set Emegency
        if(launchpad.startTime < block.timestamp && block.timestamp < launchpad.endTime){
            launchpadEmergency[launchpadId] = true;
        }        

        // emit
        emit DisableLaunchpad(launchpadId);
    }

    // stake
    function stake(uint24 launchpadId, uint104 amount) external nonReentrant {
        // stake amount must be greater than 0
        require(amount > 0, "amount is 0");

        // require msg.sender is wallet
        require(!_msgSender().isContract(), "Sender == contr address");

        // get launchpad info
        LaunchpadInfo storage launchpad = launchpads[launchpadId];

        //check expired startTime
        require(launchpad.startTime < block.timestamp,"staking time has !started");

        //check expried endTime
        require(block.timestamp < launchpad.endTime, "staking time has expired");

        // get whether launchpad is disabled
        bool isDisabled = launchpadDisabled[launchpadId];

        // cannot stake into disabled launchpad
        require(!isDisabled, "launchpad is disabled");

        // transfer the specified amount of stake token from user to this contract
        launchpad.stakeToken.safeTransferFrom(_msgSender(), address(this), amount);

        // add user checkpoint
        addUserCheckpoint(launchpadId, amount, true);

        // add launchpad checkpoint
        addLaunchpadCheckpoint(launchpadId, amount, true, false);

        isStakers[launchpadId][_msgSender()] = true;

        // emit
        emit Stake(launchpadId, _msgSender(), amount);
    }

    // unstake
    function unstake(uint24 launchpadId) external nonReentrant {
        // require msg.sender is wallet
        require(!_msgSender().isContract(), "Sender == contr address");

        // require launchpad is disabled
        require(launchpadDisabled[launchpadId], "launchpad !disabled");

        // get launchpad info
        LaunchpadInfo storage launchpad = launchpads[launchpadId];

        if(!launchpadEmergency[launchpadId]){
            // require not winners
            require(!winners[launchpadId][_msgSender()], "!winners");
        }

        // get number of user"s checkpoints within this launchpad
        uint32 userCheckpointCount = userCheckpointCounts[launchpadId][
            _msgSender()
        ];

        //check staked
        require(userCheckpointCount > 0, "not staked");

        // get user"s latest checkpoint
        UserCheckpoint storage checkpoint = userCheckpoints[launchpadId][
            _msgSender()
        ][userCheckpointCount - 1];


        // check staked
        require(checkpoint.staked > 0, "staked < 0");

        // add user checkpoint
        addUserCheckpoint(launchpadId, checkpoint.staked, false);

        // add launchpad checkpoint
        addLaunchpadCheckpoint(launchpadId, checkpoint.staked, false, false);

        // transfer the specified amount of stake token from this contract to user
        launchpad.stakeToken.safeTransfer(_msgSender(), checkpoint.staked);

        // emit
        emit Unstake(launchpadId, _msgSender(), checkpoint.staked);
    }

    //set Winers
    function setWinners(uint24 launchpadId, address[] memory _winners) public onlyOwner() launchpadNotFound(launchpadId) nonReentrant{
        // require launchpad is disabled
        require(!launchpadDisabled[launchpadId], "launchpad disabled");

        //set launchpad disable
        launchpadDisabled[launchpadId] = true;

        for(uint256 i=0; i< _winners.length; ++i){
            require(isStakers[launchpadId][_winners[i]], "!stakers");

            winners[launchpadId][_winners[i]] = true;
        }

    }

    function claim(uint24 launchpadId) external nonReentrant{
        // require msg.sender is wallet
        require(!_msgSender().isContract(), "Sender == contr address");

        // require launchpad is disabled
        require(launchpadDisabled[launchpadId], "launchpad !disabled");

        // get launchpad info
        LaunchpadInfo storage launchpad = launchpads[launchpadId];

        //check is winners
        require(winners[launchpadId][_msgSender()], "!losser");

        //check claimed
        require(!isClaimed[launchpadId][_msgSender()], "already claimed");

        // get number of user"s checkpoints within this launchpad
        uint32 userCheckpointCount = userCheckpointCounts[launchpadId][
            _msgSender()
        ];

        //check staked
        require(userCheckpointCount > 0, "not staked");

        // get user"s latest checkpoint
        UserCheckpoint storage checkpoint = userCheckpoints[launchpadId][
            _msgSender()
        ][userCheckpointCount - 1];

        //get amount refund
        uint104 amountRefund = checkpoint.staked - launchpad.minTotalStake;

        // check staked
        require(amountRefund >= 0, "staked < minTotalStake");

        // set balance launchpad
        balanceOfLaunchpad[launchpadId] += launchpad.minTotalStake;

        // transfer amountRefund for sender
        if(amountRefund > 0){
            launchpad.stakeToken.safeTransfer(_msgSender(), amountRefund);
        }

        // mintFragment for sender
        IYFIAGNftMarketplace(YFIAGNftMarketplace).mintFragment(_msgSender(), launchpad.rootIdToken);

        // sender only claim once
        isClaimed[launchpadId][_msgSender()] = true;

        // emit
        emit Claim(launchpadId, _msgSender(), launchpad.rootIdToken);
        emit Unstake(launchpadId, _msgSender(), amountRefund);

    }

    function withdraw(uint24[] memory launchpadIds) external onlyOwner() nonReentrant{
        for(uint256 i = 0; i< launchpadIds.length; ++i){
            // check balances of launchpad
            require(balanceOfLaunchpad[launchpadIds[i]] > 0, "total 0");

            LaunchpadInfo storage launchpad = launchpads[launchpadIds[i]];

            address _self = address(this);
            uint256 _balance = launchpad.stakeToken.balanceOf(_self);

            // check balances this >= balances launchpad
            require(_balance >= balanceOfLaunchpad[launchpadIds[i]], "balance !enought");

            launchpad.stakeToken.safeTransfer(_msgSender(), balanceOfLaunchpad[launchpadIds[i]]);
            balanceOfLaunchpad[launchpadIds[i]] = 0; 
        }
    }

    function setAddressMarketplace(address _YFIAGNftMarketplace) public onlyOwner(){
        YFIAGNftMarketplace = _YFIAGNftMarketplace;
    }

    function editTimeLaunchpad(uint24 launchpadId,uint256 _newStartTime, uint256 _newEndTime) public onlyOwner() launchpadNotFound(launchpadId){
        require(_newEndTime > _newStartTime, "Invalid time");
        require(_newEndTime > block.timestamp, "Invalid time");

        // get whether launchpad is disabled
        bool isDisabled = launchpadDisabled[launchpadId];
        // disabled launchpad
        require(!isDisabled, "launchpad is disabled");


        // get launchpad info
        LaunchpadInfo storage launchpad = launchpads[launchpadId];

        if(block.timestamp > launchpad.startTime){
            // set new end time
            launchpad.endTime = _newEndTime;
        }else{
            // set new start time
            launchpad.startTime = _newStartTime;

            // set new end time
            launchpad.endTime = _newEndTime; 
        }
  
    }

    function deleteLaunchpad(uint24 launchpadId) external onlyOwner() launchpadNotFound(launchpadId){
        // get whether launchpad is disabled
        bool isDisabled = launchpadDisabled[launchpadId];
        // disabled launchpad
        require(!isDisabled, "launchpad is disabled");
        // get launchpad info
        LaunchpadInfo storage launchpad = launchpads[launchpadId];
        //burn root token of this launchpad
        IYFIAGNftMarketplace(YFIAGNftMarketplace).burnByLaunchpad(owner(),launchpad.rootIdToken);
        //set disable
        launchpadDisabled[launchpadId] = true;
        // set Emegency
        if(launchpad.startTime < block.timestamp && block.timestamp < launchpad.endTime){
            launchpadEmergency[launchpadId] = true;
        }  
    }

}
