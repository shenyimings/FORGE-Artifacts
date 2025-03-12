pragma solidity ^0.6.0;

import "./libraries/math/SafeMath.sol";
import "./libraries/utils/Address.sol";

contract FeeModel {
    using SafeMath for uint256;
    using Address for address;

    event CommitNewAdmin(uint256 deadline, address future_admin);
    event NewAdmin(address admin);

    uint256 public _feeRate;

    address public owner;
    address public future_owner;
    uint256 public transfer_ownership_deadline;
    uint256 public constant ADMIN_ACTIONS_DELAY = 3 * 86400;

    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function getFee(uint256 _premium) external view returns (uint256) {
        return _premium.mul(_feeRate).div(100000);
    }

    function setFee(uint256 _target) external onlyOwner {
        _feeRate = _target;
    }

    function get_owner() public view returns (address) {
        return owner;
    }

    function isOwner() public view returns (bool) {
        return msg.sender == owner;
    }

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
