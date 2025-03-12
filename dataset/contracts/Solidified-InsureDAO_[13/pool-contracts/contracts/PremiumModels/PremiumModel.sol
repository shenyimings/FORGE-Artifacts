pragma solidity ^0.6.0;

import "../libraries/math/SafeMath.sol";
import "../libraries/utils/Address.sol";

contract PremiumModel {
    using SafeMath for uint256;
    using Address for address;

    event CommitNewAdmin(uint256 deadline, address future_admin);
    event NewAdmin(address admin);

    uint256 public _multiplier;
    uint256 public _baseRate;

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

    function getPremium(
        uint256 _amount,
        uint256 _term,
        uint256 _totalLiquidity,
        uint256 _lockedAmount
    ) external view returns (uint256) {
        if (_amount == 0) {
            return 0;
        }
        // 1) Calculate premium multiplier
        uint256 _util = _lockedAmount
        .add(_amount)
        .add(_lockedAmount)
        .mul(1e5)
        .div(_totalLiquidity)
        .div(2);
        uint256 _premium = _amount.mul(_multiplier).mul(_util).div(1e10);
        // 2) add base premium
        _premium = _amount.mul(_baseRate).div(1e5).add(_premium);
        // 3) adjust premium for daily basis
        _premium = _premium.mul(_term).div(365 days);
        // 4) Return premium
        return _premium;
    }

    function getPremiumRate(uint256 _totalLiquidity, uint256 _lockedAmount)
        external
        view
        returns (uint256)
    {
        // utilization rate (0~1000000)
        uint256 _util = _lockedAmount.mul(1e6).div(_totalLiquidity);

        // yearly premium rate
        uint256 _premiumRate;
        // Calculate multiplier
        _premiumRate = _util.mul(_multiplier).div(1e6);
        // Add base rate
        _premiumRate = _premiumRate.add(_baseRate);
        // Return premium
        return _premiumRate;
    }

    /**
     * @notice Set a premium model
     * @param _baseRatePerYear The approximate target base premium (scaled by 1e5)
     * @param _multiplierPerYear The rate of mixmum premium(scaled by 1e5)
     */
    function setPremium(uint256 _baseRatePerYear, uint256 _multiplierPerYear)
        external
        onlyOwner
    {
        _baseRate = _baseRatePerYear;
        _multiplier = _multiplierPerYear;
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
