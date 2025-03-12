// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/AggregatorV2V3Interface.sol";

/** solhint-disable var-name-mixedcase */
/**
 * @notice Simple data posting on chain of a scalar value, compatible with Chainlink V2 and V3 aggregator interface
 */
contract FluxPriceFeed is AccessControl, AggregatorV2V3Interface {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    uint32 public latestAggregatorRoundId;

    // Transmission records the answer from the transmit transaction at
    // time timestamp
    struct Transmission {
        int192 answer; // 192 bits ought to be enough for anyone
        uint64 timestamp;
        bool marketOpen;
    }
    mapping(uint32 => Transmission) internal s_transmissions; /* aggregator round ID */
       

    /**
     * @param _validator the initial validator that can post data to this contract
     * @param _decimals answers are stored in fixed-point format, with this many digits of precision
     * @param _description short human-readable description of observable this contract's answers pertain to
     */
    constructor(
        address _validator,
        uint8 _decimals,
        string memory _description
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(VALIDATOR_ROLE, _validator);
        decimals = _decimals;
        s_description = _description;
    }

    /*
     * Versioning
     */
    function typeAndVersion() external pure virtual returns (string memory) {
        return "FluxPriceFeed 1.0.0";
    }

    /*
     * Transmission logic
     */

    /**
     * @notice indicates that a new report was transmitted
     * @param aggregatorRoundId the round to which this report was assigned
     * @param answer value posted by validator
     * @param marketOpen bool indicating if the market is open
     * @param transmitter address from which the report was transmitted
     */
    event NewTransmission(uint32 indexed aggregatorRoundId, int192 answer, bool marketOpen, address transmitter);
        
    /**
     * @notice details about the most recent report
     * @return _latestAnswer value from latest report
     * @return _latestTimestamp when the latest report was transmitted
     * @return _marketOpen value from latest report
     */
    function latestTransmissionDetails() external view returns (int192 _latestAnswer, uint64 _latestTimestamp, bool _marketOpen) {
        // solhint-disable-next-line avoid-tx-origin
        require(msg.sender == tx.origin, "Only callable by EOA");
        return (
            s_transmissions[latestAggregatorRoundId].answer,
            s_transmissions[latestAggregatorRoundId].timestamp,
            s_transmissions[latestAggregatorRoundId].marketOpen
        );
    }

    /**
     * @notice transmit is called to post a new report to the contract
     * @param _answer latest answer
     */
    function transmit(int192 _answer, bool _marketOpen) external {
        require(hasRole(VALIDATOR_ROLE, msg.sender), "Caller is not a validator");

        // Check the report contents, and record the result
        latestAggregatorRoundId++;
        // solhint-disable-next-line not-rely-on-time
        s_transmissions[latestAggregatorRoundId] = Transmission(_answer, uint64(block.timestamp), _marketOpen);

        emit NewTransmission(latestAggregatorRoundId, _answer, _marketOpen, msg.sender);
    }

    /*
     * v2 Aggregator interface
     */

    /**
     * @notice answer from the most recent report
     */
    function latestAnswer() public view virtual override returns (int256) {
        return s_transmissions[latestAggregatorRoundId].answer;
    }

    /**
     * @notice timestamp of block in which last report was transmitted
     */
    function latestTimestamp() public view virtual override returns (uint256) {
        return s_transmissions[latestAggregatorRoundId].timestamp;
    }

     /**
     * @notice market open indicator from the most recent report
     */
    function latestMarketOpen() public view virtual override returns (bool) {
        return s_transmissions[latestAggregatorRoundId].marketOpen;
    }

    /**
     * @notice Aggregator round in which last report was transmitted
     */
    function latestRound() public view virtual override returns (uint256) {
        return latestAggregatorRoundId;
    }

    /**
     * @notice answer of report from given aggregator round
     * @param _roundId the aggregator round of the target report
     */
    function getAnswer(uint256 _roundId) public view virtual override returns (int256) {
        if (_roundId > 0xFFFFFFFF) {
            return 0;
        }
        return s_transmissions[uint32(_roundId)].answer;
    }

    /**
     * @notice timestamp of block in which report from given aggregator round was transmitted
     * @param _roundId aggregator round of target report
     */
    function getTimestamp(uint256 _roundId) public view virtual override returns (uint256) {
        if (_roundId > 0xFFFFFFFF) {
            return 0;
        }
        return s_transmissions[uint32(_roundId)].timestamp;
    }

    /**
     * @notice market open of report from given aggregator round
     * @param _roundId the aggregator round of the target report
     */
    function getMarketOpen(uint256 _roundId) public view virtual override returns (bool) {
        require(_roundId <= 0xFFFFFFFF, "FluxPriceFeed: round ID");
        return s_transmissions[uint32(_roundId)].marketOpen;
    }

    /*
     * v3 Aggregator interface
     */

    string private constant V3_NO_DATA_ERROR = "No data present";

    /**
     * @return answers are stored in fixed-point format, with this many digits of precision
     */
    uint8 public immutable override decimals;

    /**
     * @notice aggregator contract version
     */
    uint256 public constant override version = 1;

    string internal s_description;

    /**
     * @notice human-readable description of observable this contract is reporting on
     */
    function description() public view virtual override returns (string memory) {
        return s_description;
    }

    /**
     * @notice details for the given aggregator round
     * @param _roundId target aggregator round. Must fit in uint32
     * @return roundId _roundId
     * @return answer answer of report from given _roundId
     * @return marketOpen of report from given _roundId
     * @return startedAt timestamp of block in which report from given _roundId was transmitted
     * @return updatedAt timestamp of block in which report from given _roundId was transmitted
     * @return answeredInRound _roundId
     */
    function getRoundData(uint80 _roundId)
        public
        view
        virtual
        override
        returns (
            uint80 roundId,
            int256 answer,
            bool marketOpen,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        require(_roundId <= 0xFFFFFFFF, V3_NO_DATA_ERROR);
        Transmission memory transmission = s_transmissions[uint32(_roundId)];
        return (_roundId, transmission.answer, transmission.marketOpen, transmission.timestamp, transmission.timestamp, _roundId);
    }

    /**
     * @notice aggregator details for the most recently transmitted report
     * @return roundId aggregator round of latest report
     * @return answer answer of latest report
     * @return marketOpen of latest report
     * @return startedAt timestamp of block containing latest report
     * @return updatedAt timestamp of block containing latest report
     * @return answeredInRound aggregator round of latest report
     */
    function latestRoundData()
        public
        view
        virtual
        override
        returns (
            uint80 roundId,
            int256 answer,
            bool marketOpen,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = latestAggregatorRoundId;

        // Skipped for compatability with existing FluxAggregator in which latestRoundData never reverts.
        // require(roundId != 0, V3_NO_DATA_ERROR);

        Transmission memory transmission = s_transmissions[uint32(roundId)];
        return (roundId, transmission.answer, transmission.marketOpen, transmission.timestamp, transmission.timestamp, roundId);
    }
}
