// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

interface IVoterV3 {
    event Abstained(uint256 tokenId, uint256 weight);
    event AddFactories(
        address indexed pairfactory,
        address indexed gaugefactory
    );
    event Blacklisted(address indexed blacklister, address indexed token);
    event DistributeReward(
        address indexed sender,
        address indexed gauge,
        uint256 amount
    );
    event GaugeCreated(
        address indexed gauge,
        address creator,
        address internal_bribe,
        address indexed external_bribe,
        address indexed pool
    );
    event GaugeKilled(address indexed gauge);
    event GaugeRevived(address indexed gauge);
    event Initialized(uint8 version);
    event NotifyReward(
        address indexed sender,
        address indexed reward,
        uint256 amount
    );
    event SetBribeFactory(address indexed old, address indexed latest);
    event SetBribeFor(
        bool isInternal,
        address indexed old,
        address indexed latest,
        address indexed gauge
    );
    event SetGaugeFactory(address indexed old, address indexed latest);
    event SetMinter(address indexed old, address indexed latest);
    event SetPairFactory(address indexed old, address indexed latest);
    event SetVoteDelay(uint256 old, uint256 latest);
    event Voted(address indexed voter, uint256 tokenId, uint256 weight);
    event Whitelisted(address indexed whitelister, address indexed token);

    function MAX_VOTE_DELAY() external view returns (uint256);

    function VOTE_DELAY() external view returns (uint256);

    function _epochTimestamp() external view returns (uint256);

    function _init(address[] memory _tokens, address _minter) external;

    function _ve() external view returns (address);

    function addFactory(address _pairFactory, address _gaugeFactory) external;

    function admin() external view returns (address);

    function blacklist(address[] memory _token) external;

    function bribefactory() external view returns (address);

    function claimBribes(
        address[] memory _bribes,
        address[][] memory _tokens,
        uint256 _tokenId
    ) external;

    function claimBribes(address[] memory _bribes, address[][] memory _tokens)
        external;

    function claimFees(
        address[] memory _fees,
        address[][] memory _tokens,
        uint256 _tokenId
    ) external;

    function claimFees(address[] memory _bribes, address[][] memory _tokens)
        external;

    function claimRewards(address[] memory _gauges) external;

    function claimable(address) external view returns (uint256);

    function weightsPerEpoch(uint,address) external view returns(uint);

    function createGauge(address _pool, uint256 _gaugeType)
        external
        returns (
            address _gauge,
            address _internal_bribe,
            address _external_bribe
        );

    function createGauges(address[] memory _pool, uint256[] memory _gaugeTypes)
        external
        returns (
            address[] memory,
            address[] memory,
            address[] memory
        );

    function distribute(address[] memory _gauges) external;

    function distribute(uint256 start, uint256 finish) external;

    function distributeAll() external;

    function distributeFees(address[] memory _gauges) external;

    function external_bribes(address) external view returns (address);

    function factories() external view returns (address[] memory);

    function factoryLength() external view returns (uint256);

    function gaugeFactories() external view returns (address[] memory);

    function gaugeFactoriesLength() external view returns (uint256);

    function gauges(address) external view returns (address);

    function gaugesDistributionTimestmap(address)
        external
        view
        returns (uint256);

    function governance() external view returns (address);

    function initialize(
        address __ve,
        address _pairFactory,
        address _gaugeFactory,
        address _bribes
    ) external;

    function internal_bribes(address) external view returns (address);

    function isAlive(address) external view returns (bool);

    function isFactory(address) external view returns (bool);

    function isGauge(address) external view returns (bool);

    function isGaugeFactory(address) external view returns (bool);

    function isWhitelisted(address) external view returns (bool);

    function killGauge(address _gauge) external;

    function lastVoted(uint256) external view returns (uint256);

    function length() external view returns (uint256);
    function clLength() external view returns (uint256);

    function minter() external view returns (address);

    function notifyRewardAmount(uint256 amount) external;

    function poke(uint256 _tokenId) external;

    function poolForGauge(address) external view returns (address);

    function poolVote(uint256, uint256) external view returns (address);

    function poolVoteLength(uint256 tokenId) external view returns (uint256);

    function pools(uint256) external view returns (address);

    function poolsList() external view returns (address[] memory);

    function clPools(uint256) external view returns (address);

    function clPoolsList() external view returns (address[] memory);

    function removeFactory(uint256 _pos) external;

    function replaceFactory(
        address _pairFactory,
        address _gaugeFactory,
        uint256 _pos
    ) external;

    function reset(uint256 _tokenId) external;

    function reviveGauge(address _gauge) external;

    function setBribeFactory(address _bribeFactory) external;

    function setExternalBribeFor(address _gauge, address _external) external;

    function setInternalBribeFor(address _gauge, address _internal) external;

    function setMinter(address _minter) external;

    function setNewBribes(
        address _gauge,
        address _internal,
        address _external
    ) external;

    function setVoteDelay(uint256 _delay) external;

    function totalWeight() external view returns (uint256);

    function totalWeightAt(uint256 _time) external view returns (uint256);

    function vote(
        uint256 _tokenId,
        address[] memory _poolVote,
        uint256[] memory _weights
    ) external;

    function votes(uint256, address) external view returns (uint256);

    function weights(address _pool) external view returns (uint256);

    function weightsAt(address _pool, uint256 _time)
        external
        view
        returns (uint256);

    function whitelist(address[] memory _token) external;
}
