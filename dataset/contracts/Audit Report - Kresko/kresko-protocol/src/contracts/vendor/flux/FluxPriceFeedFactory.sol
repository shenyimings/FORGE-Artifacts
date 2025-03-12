// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./FluxPriceFeed.sol";

/**
 * @title Flux first-party price feed factory
 * @author fluxprotocol.org
 */
contract FluxPriceFeedFactory {
    address public owner;
    // roles
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    // mapping of id to FluxPriceFeed
    mapping(bytes32 => FluxPriceFeed) public fluxPriceFeeds;

    /**
     * @notice indicates that a new oracle was created
     * @param id hash of the price pair of the deployed oracle
     * @param oracle address of the deployed oracle
     */
    event FluxPriceFeedCreated(bytes32 indexed id, address indexed oracle);

    /**
     * @notice to log error messages
     * @param message the logged message
     */
    event Log(string message);

    constructor () {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "!owner");
        owner = newOwner;
    }

    /**
     * @notice transmit submits an answer to a price feed or creates a new one if it does not exist
     * @param _pricePairs array of price pairs strings (e.g. ETH/USD)
     * @param _decimals array of decimals for associated price pairs (e.g. 3)
     * @param _answers array of prices for associated price pairs
     * @param _marketStatusAnswers array of market open/closed statuses
     * @param _provider optional address of the provider, if different from msg.sender
     */
    function transmit(
        string[] calldata _pricePairs,
        uint8[] calldata _decimals,
        int192[] calldata _answers,
        bool[] calldata _marketStatusAnswers,
        address _provider
    ) external {
        require(
            (_pricePairs.length == _decimals.length) && (_pricePairs.length == _answers.length) && (_pricePairs.length == _marketStatusAnswers.length),
            "Transmitted arrays must be equal"
        );
        // if no provider is provided, use the msg.sender
        address provider = (_provider == address(0)) ? msg.sender : _provider;

        // Iterate through each transmitted price pair
        for (uint256 i = 0; i < _pricePairs.length; i++) {
            string memory str = string(
                abi.encodePacked("Price-", _pricePairs[i], "-", Strings.toString(_decimals[i]), "-", provider)
            );
            bytes32 id = keccak256(bytes(str));

            // deploy a new oracle if there's none previously deployed and this is the original provider
            if (address(fluxPriceFeeds[id]) == address(0x0)) { 
                _deployOracle(id, _pricePairs[i], _decimals[i], _provider);
            }

            require(address(fluxPriceFeeds[id]) != address(0x0), "Provider doesn't exist");

            require(fluxPriceFeeds[id].hasRole(VALIDATOR_ROLE, msg.sender), "Only validators can transmit");

            // try transmitting values to the oracle
            /* solhint-disable-next-line no-empty-blocks */
            try fluxPriceFeeds[id].transmit(_answers[i], _marketStatusAnswers[i]) {
                // transmission is successful, nothing to do
            } catch Error(string memory reason) {
                // catch failing revert() and require()
                emit Log(reason);
            }
        }
    }

    /**
     * @notice internal function to create a new FluxPriceFeed
     * @dev only a validator should be able to call this function
     */
    function _deployOracle(
        bytes32 _id,
        string calldata _pricePair,
        uint8 _decimals,
        address _provider
    ) internal {
        require(msg.sender == owner, "!owner");
        // deploy the new contract and store it in the mapping
        FluxPriceFeed newPriceFeed = new FluxPriceFeed(address(this), _decimals, _pricePair);

        fluxPriceFeeds[_id] = newPriceFeed;

        // grant the provider DEFAULT_ADMIN_ROLE and VALIDATOR_ROLE on the new FluxPriceFeed
        newPriceFeed.grantRole(0x00, msg.sender);
        newPriceFeed.grantRole(VALIDATOR_ROLE, msg.sender);
        newPriceFeed.grantRole(VALIDATOR_ROLE, _provider);

        emit FluxPriceFeedCreated(_id, address(newPriceFeed));
    }

    /**
     * @notice answer from the most recent report of a certain price pair from factory
     * @param _id hash of the price pair string to query
     */
    function valueFor(bytes32 _id)
        external
        view
        returns (
            int256,
            bool,
            uint256,
            uint256
        )
    {
        // if oracle exists then fetch values
        if (address(fluxPriceFeeds[_id]) != address(0x0)) {
            // fetch the price feed contract and read its latest answer and timestamp
            try fluxPriceFeeds[_id].latestRoundData() returns (
                uint80,
                int256 answer,
                bool marketOpen,
                uint256,
                uint256 updatedAt,
                uint80
            ) {
                return (answer,marketOpen, updatedAt, 200);
            } catch {
                // catch failing revert() and require()
                return (0, false, 0, 404);
            }

            // else return not found
        } else {
            return (0, false, 0, 404);
        }
    }

    /**
     * @notice returns address of a price feed id
     * @param _id hash of the price pair string to query
     */
    function addressOfPricePairId(bytes32 _id) external view returns (address) {
        return address(fluxPriceFeeds[_id]);
    }

    /**
     * @notice returns the hash of a price pair
     * @param _pricePair ETH/USD
     * @param _decimals decimal of the price pair
     * @param _provider original provider of the price pair
     */
    function getId(
        string calldata _pricePair,
        uint8 _decimals,
        address _provider
    ) external pure returns (bytes32) {
        string memory str = string(
            abi.encodePacked("Price-", _pricePair, "-", Strings.toString(_decimals), "-", _provider)
        );
        bytes32 id = keccak256(bytes(str));
        return id;
    }

    /**
     * @notice returns address of a price feed id
     * @param _pricePair ETH/USD
     * @param _decimals decimal of the price pair
     * @param _provider original provider of the price pair
     */
    function addressOfPricePair(
        string calldata _pricePair,
        uint8 _decimals,
        address _provider
    ) external view returns (address) {
        bytes32 id = this.getId(_pricePair, _decimals, _provider);
        return address(fluxPriceFeeds[id]);
    }

    /**
     * @notice returns factory's type and version
     */
    function typeAndVersion() external pure virtual returns (string memory) {
        return "FluxPriceFeedFactory 2.0.0";
    }
}