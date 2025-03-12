pragma solidity ^0.6.0;

import "./libraries/utils/Address.sol";
import "./libraries/math/SafeMath.sol";

contract Registry {
    using SafeMath for uint256;
    using Address for address;

    event CommitNewAdmin(uint256 deadline, address future_admin);
    event NewAdmin(address admin);
    event NewMarketRegistered(address market);
    event FactorySet(address factory);
    event CDSSet(address target, address cds);

    address public factory;
    address public owner;
    address public future_owner;
    uint256 public transfer_ownership_deadline;
    uint256 public constant ADMIN_ACTIONS_DELAY = 3 * 86400;

    mapping(address => address) cds; //index => cds
    mapping(address => bool) markets;
    address[] allMarkets;

    constructor() public {
        owner = msg.sender;
    }

    function setFactory(address _factory) external {
        require(msg.sender == owner);
        factory = _factory;
        emit FactorySet(_factory);
    }

    function supportMarket(address _market) external {
        require(!markets[_market]);
        require(msg.sender == factory || msg.sender == owner);
        allMarkets.push(_market);
        markets[_market] = true;
        emit NewMarketRegistered(_market);
    }

    function setCDS(address _address, address _cds) external {
        require(msg.sender == owner, "dev: only owner");
        cds[_address] = _cds;
        emit CDSSet(_address, _cds);
    }

    function getCDS(address _address) external view returns (address) {
        if (cds[_address] == address(0)) {
            return cds[address(0)];
        } else {
            return cds[_address];
        }
    }

    function isListed(address _market) external view returns (bool) {
        return markets[_market];
    }

    function getAllMarkets() external view returns (address[] memory) {
        return allMarkets;
    }

    //----- ownership -----//
    function commit_transfer_ownership(address _owner) external {
        require(msg.sender == owner, "dev: only owner");
        require(transfer_ownership_deadline == 0, "dev: active transfer");

        uint256 _deadline = block.timestamp.add(ADMIN_ACTIONS_DELAY);
        transfer_ownership_deadline = _deadline;
        future_owner = _owner;

        emit CommitNewAdmin(_deadline, _owner);
    }

    function apply_transfer_ownership() external {
        require(msg.sender == owner, "dev: only owner");
        require(
            block.timestamp >= transfer_ownership_deadline,
            "dev: insufficient time"
        );
        require(transfer_ownership_deadline != 0, "dev: no active transfer");

        transfer_ownership_deadline = 0;
        address _owner = future_owner;

        owner = _owner;

        emit NewAdmin(owner);
    }
}
